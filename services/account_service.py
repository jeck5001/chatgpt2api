from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Condition, Lock
from typing import Any
from datetime import datetime

from services.config import config
from services.log_service import (
    LOG_TYPE_ACCOUNT,
    log_service,
)
from services.storage.base import StorageBackend
from utils.helper import anonymize_token


class AccountService:
    """账号池服务，使用 token -> account 的 dict 保存账号。"""

    _ACCOUNT_TYPE_ALIASES = {
        "free": "free",
        "plus": "plus",
        "pro": "pro",
        "prolite": "ProLite",
    }

    def __init__(self, storage_backend: StorageBackend):
        self.storage = storage_backend
        self._lock = Lock()
        self._image_slot_condition = Condition(self._lock)
        self._index = 0
        self._accounts = self._load_accounts()
        self._image_inflight: dict[str, int] = {}

    def _load_accounts(self) -> dict[str, dict]:
        accounts = self.storage.load_accounts()
        return {
            normalized["access_token"]: normalized
            for item in accounts
            if (normalized := self._normalize_account(item)) is not None
        }

    def _save_accounts(self) -> None:
        self.storage.save_accounts(list(self._accounts.values()))

    @staticmethod
    def _is_image_account_available(account: dict) -> bool:
        if not isinstance(account, dict):
            return False
        if account.get("status") in {"禁用", "限流", "异常"}:
            return False
        if bool(account.get("image_quota_unknown")):
            return True
        return int(account.get("quota") or 0) > 0

    def _normalize_account(self, item: dict) -> dict | None:
        if not isinstance(item, dict):
            return None
        access_token = item.get("access_token") or ""
        if not access_token:
            return None
        normalized = dict(item)
        normalized["access_token"] = access_token
        normalized["type"] = normalized.get("type") or "free"
        normalized["status"] = normalized.get("status") or "正常"
        normalized["quota"] = max(0, int(normalized.get("quota") if normalized.get("quota") is not None else 0))
        normalized["image_quota_unknown"] = bool(normalized.get("image_quota_unknown"))
        normalized["email"] = normalized.get("email") or None
        normalized["user_id"] = normalized.get("user_id") or None
        limits_progress = normalized.get("limits_progress")
        normalized["limits_progress"] = limits_progress if isinstance(limits_progress, list) else []
        normalized["default_model_slug"] = normalized.get("default_model_slug") or None
        normalized["restore_at"] = normalized.get("restore_at") or None
        normalized["success"] = int(normalized.get("success") or 0)
        normalized["fail"] = int(normalized.get("fail") or 0)
        normalized["image_avg_latency_ms"] = max(0, int(normalized.get("image_avg_latency_ms") or 0))
        normalized["image_last_result_at"] = normalized.get("image_last_result_at") or None
        normalized["last_used_at"] = normalized.get("last_used_at")
        return normalized

    @classmethod
    def _normalize_account_type(cls, value: object) -> str | None:
        text = str(value or "").strip()
        if not text:
            return None
        key = "".join(char for char in text.lower() if char.isalnum())
        return cls._ACCOUNT_TYPE_ALIASES.get(key)

    @classmethod
    def _search_account_type(cls, payload: object) -> str | None:
        if isinstance(payload, list):
            for item in payload:
                matched = cls._search_account_type(item)
                if matched:
                    return matched
            return None
        if not isinstance(payload, dict):
            return None
        for key, value in payload.items():
            key_text = str(key or "").lower()
            if isinstance(value, (dict, list)):
                matched = cls._search_account_type(value)
                if matched:
                    return matched
                continue
            if any(marker in key_text for marker in ("plan", "account_type", "subscription", "sku", "product")):
                matched = cls._normalize_account_type(value)
                if matched:
                    return matched
        return None

    def list_tokens(self) -> list[str]:
        with self._lock:
            return list(self._accounts)

    def _list_ready_candidate_tokens(self, excluded_tokens: set[str] | None = None) -> list[str]:
        excluded = set(excluded_tokens or set())
        return [
            token
            for item in self._accounts.values()
            if self._is_image_account_available(item)
               and (token := item.get("access_token") or "")
               and token not in excluded
        ]

    def _list_available_candidate_tokens(self, excluded_tokens: set[str] | None = None) -> list[str]:
        max_concurrency = max(1, int(config.image_account_concurrency or 1))
        tokens = [
            token
            for token in self._list_ready_candidate_tokens(excluded_tokens)
            if int(self._image_inflight.get(token, 0)) < max_concurrency
        ]
        return self._sort_image_candidate_tokens(tokens)

    @classmethod
    def _image_health_score(cls, account: dict, inflight: int = 0) -> float:
        success = max(0, int(account.get("success") or 0))
        fail = max(0, int(account.get("fail") or 0))
        total = success + fail
        success_score = 55.0 * (success / total) if total else 38.0
        failure_penalty = min(35.0, fail * 4.0)

        latency_ms = max(0, int(account.get("image_avg_latency_ms") or 0))
        if latency_ms <= 0:
            latency_score = 15.0
        elif latency_ms <= 1000:
            latency_score = 20.0
        elif latency_ms >= 15000:
            latency_score = 0.0
        else:
            latency_score = 20.0 - ((latency_ms - 1000) / 14000) * 20.0

        if bool(account.get("image_quota_unknown")) or account.get("type") in cls._UNLIMITED_IMAGE_QUOTA_TYPES:
            quota_score = 15.0
        else:
            quota_score = min(15.0, max(0, int(account.get("quota") or 0)) * 0.6)

        return success_score + latency_score + quota_score - failure_penalty - max(0, inflight) * 12.0

    def _sort_image_candidate_tokens(self, tokens: list[str]) -> list[str]:
        def sort_key(token: str) -> tuple[float, str, str]:
            account = self._accounts.get(token) or {}
            score = self._image_health_score(account, int(self._image_inflight.get(token, 0)))
            return (-score, str(account.get("last_used_at") or ""), token)

        return sorted(tokens, key=sort_key)

    def _acquire_next_candidate_token(self, excluded_tokens: set[str] | None = None) -> str:
        with self._image_slot_condition:
            while True:
                if not self._list_ready_candidate_tokens(excluded_tokens):
                    raise RuntimeError("no available image quota")
                tokens = self._list_available_candidate_tokens(excluded_tokens)
                if tokens:
                    access_token = tokens[0]
                    self._image_inflight[access_token] = int(self._image_inflight.get(access_token, 0)) + 1
                    return access_token
                self._image_slot_condition.wait(timeout=1.0)

    def release_image_slot(self, access_token: str) -> None:
        if not access_token:
            return
        with self._image_slot_condition:
            current_inflight = int(self._image_inflight.get(access_token, 0))
            if current_inflight <= 1:
                self._image_inflight.pop(access_token, None)
            else:
                self._image_inflight[access_token] = current_inflight - 1
            self._image_slot_condition.notify_all()

    def get_available_access_token(self) -> str:
        attempted_tokens: set[str] = set()
        while True:
            access_token = self._acquire_next_candidate_token(excluded_tokens=attempted_tokens)
            attempted_tokens.add(access_token)
            try:
                account = self.fetch_remote_info(access_token, "get_available_access_token")
            except Exception:
                self.release_image_slot(access_token)
                continue
            if self._is_image_account_available(account or {}):
                return access_token
            self.release_image_slot(access_token)

    def get_text_access_token(self, excluded_tokens: set[str] | None = None) -> str:
        excluded = set(excluded_tokens or set())
        with self._lock:
            candidates = [
                token
                for account in self._accounts.values()
                if account.get("status") not in {"禁用", "异常"}
                   and (token := account.get("access_token") or "")
                   and token not in excluded
            ]
            if not candidates:
                return ""
            access_token = candidates[self._index % len(candidates)]
            self._index += 1
            return access_token

    def mark_text_used(self, access_token: str) -> None:
        if not access_token:
            return
        with self._lock:
            current = self._accounts.get(access_token)
            if current is None:
                return
            next_item = dict(current)
            next_item["last_used_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            account = self._normalize_account(next_item)
            if account is None:
                return
            self._accounts[access_token] = account
            self._save_accounts()

    def remove_invalid_token(self, access_token: str, event: str) -> bool:
        if not config.auto_remove_invalid_accounts:
            self.update_account(access_token, {"status": "异常", "quota": 0})
            return False
        removed = bool(self.delete_accounts([access_token])["removed"])
        if removed:
            log_service.add(LOG_TYPE_ACCOUNT, "自动移除异常账号",
                            {"source": event, "token": anonymize_token(access_token)})
        elif access_token:
            self.update_account(access_token, {"status": "异常", "quota": 0})
        return removed

    def get_account(self, access_token: str) -> dict | None:
        if not access_token:
            return None
        with self._lock:
            account = self._accounts.get(access_token)
            return dict(account) if account else None

    def list_accounts(self) -> list[dict]:
        with self._lock:
            return [dict(item) for item in self._accounts.values()]

    _UNLIMITED_IMAGE_QUOTA_TYPES = {"pro", "prolite"}

    @classmethod
    def _matches_account_filters(
        cls,
        account: dict,
        *,
        q: str = "",
        status: str = "",
        type: str = "",
    ) -> bool:
        if status and account.get("status") != status:
            return False
        if type and account.get("type") != type:
            return False
        if q:
            needle = q.lower()
            email = (account.get("email") or "").lower()
            token = (account.get("access_token") or "").lower()
            if needle not in email and needle not in token:
                return False
        return True

    @classmethod
    def _compute_summary(cls, accounts: list[dict]) -> dict:
        summary = {
            "total": len(accounts),
            "active": 0,
            "limited": 0,
            "abnormal": 0,
            "disabled": 0,
        }
        quota_value = 0
        has_unlimited = False
        has_unknown = False
        for item in accounts:
            status = item.get("status") or ""
            if status == "正常":
                summary["active"] += 1
                if item.get("type") in cls._UNLIMITED_IMAGE_QUOTA_TYPES:
                    has_unlimited = True
                elif bool(item.get("image_quota_unknown")):
                    has_unknown = True
                else:
                    quota_value += max(0, int(item.get("quota") or 0))
            elif status == "限流":
                summary["limited"] += 1
            elif status == "异常":
                summary["abnormal"] += 1
            elif status == "禁用":
                summary["disabled"] += 1
        summary["quota"] = {
            "value": quota_value,
            "has_unlimited": has_unlimited,
            "has_unknown": has_unknown,
        }
        return summary

    def list_accounts_page(
        self,
        page: int = 1,
        page_size: int = 50,
        q: str = "",
        status: str = "",
        type: str = "",
    ) -> dict:
        page = max(1, int(page or 1))
        page_size = max(1, min(200, int(page_size or 50)))
        with self._lock:
            all_accounts = [dict(item) for item in self._accounts.values()]
        summary = self._compute_summary(all_accounts)
        filtered = [
            item
            for item in all_accounts
            if self._matches_account_filters(item, q=q, status=status, type=type)
        ]
        # Stable sort: newest last_used_at first, then by access_token ascending.
        # Empty last_used_at goes to the end (reverse=True puts smallest last).
        filtered.sort(key=lambda a: a.get("access_token") or "")
        filtered.sort(key=lambda a: a.get("last_used_at") or "", reverse=True)
        total = len(filtered)
        start = (page - 1) * page_size
        end = start + page_size
        return {
            "items": filtered[start:end],
            "total": total,
            "page": page,
            "page_size": page_size,
            "has_more": end < total,
            "summary": summary,
        }

    def list_limited_tokens(self) -> list[str]:
        with self._lock:
            return [
                token
                for item in self._accounts.values()
                if item.get("status") == "限流"
                   and (token := item.get("access_token") or "")
            ]

    def add_accounts(self, tokens: list[str]) -> dict:
        tokens = list(dict.fromkeys(token for token in tokens if token))
        if not tokens:
            return {"added": 0, "skipped": 0}

        with self._lock:
            added = 0
            skipped = 0
            for access_token in tokens:
                current = self._accounts.get(access_token)
                if current is None:
                    added += 1
                    current = {}
                else:
                    skipped += 1
                account = self._normalize_account(
                    {
                        **current,
                        "access_token": access_token,
                        "type": str(current.get("type") or "free"),
                    }
                )
                if account is not None:
                    self._accounts[access_token] = account
            self._save_accounts()
            log_service.add(LOG_TYPE_ACCOUNT, f"新增 {added} 个账号，跳过 {skipped} 个",
                            {"added": added, "skipped": skipped})
        return {"added": added, "skipped": skipped}

    def delete_accounts(self, tokens: list[str]) -> dict:
        target_set = set(token for token in tokens if token)
        if not target_set:
            return {"removed": 0}
        with self._lock:
            removed = sum(self._accounts.pop(token, None) is not None for token in target_set)
            for token in target_set:
                self._image_inflight.pop(token, None)
            if removed:
                if self._accounts:
                    self._index %= len(self._accounts)
                else:
                    self._index = 0
                self._save_accounts()
                log_service.add(LOG_TYPE_ACCOUNT, f"删除 {removed} 个账号", {"removed": removed})
        return {"removed": removed}

    def update_account(self, access_token: str, updates: dict) -> dict | None:
        if not access_token:
            return None
        with self._lock:
            current = self._accounts.get(access_token)
            if current is None:
                return None
            account = self._normalize_account({**current, **updates, "access_token": access_token})
            if account is None:
                return None
            if account.get("status") == "限流" and config.auto_remove_rate_limited_accounts:
                self._accounts.pop(access_token, None)
                self._save_accounts()
                log_service.add(LOG_TYPE_ACCOUNT, "自动移除限流账号", {"token": anonymize_token(access_token)})
                return None
            self._accounts[access_token] = account
            self._save_accounts()
            log_service.add(LOG_TYPE_ACCOUNT, "更新账号",
                            {"token": anonymize_token(access_token), "status": account.get("status")})
            return dict(account)
        return None

    def mark_image_result(self, access_token: str, success: bool, latency_ms: int | None = None) -> dict | None:
        if not access_token:
            return None
        self.release_image_slot(access_token)
        with self._lock:
            current = self._accounts.get(access_token)
            if current is None:
                return None
            next_item = dict(current)
            finished_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            next_item["last_used_at"] = finished_at
            next_item["image_last_result_at"] = finished_at
            if latency_ms is not None:
                sample_latency = max(0, int(latency_ms))
                current_avg = max(0, int(next_item.get("image_avg_latency_ms") or 0))
                next_item["image_avg_latency_ms"] = (
                    sample_latency if current_avg <= 0 else int(current_avg * 0.7 + sample_latency * 0.3)
                )
            image_quota_unknown = bool(next_item.get("image_quota_unknown"))
            if success:
                next_item["success"] = int(next_item.get("success") or 0) + 1
                if not image_quota_unknown:
                    next_item["quota"] = max(0, int(next_item.get("quota") or 0) - 1)
                if not image_quota_unknown and next_item["quota"] == 0:
                    next_item["status"] = "限流"
                    next_item["restore_at"] = next_item.get("restore_at") or None
                elif next_item.get("status") == "限流":
                    next_item["status"] = "正常"
            else:
                next_item["fail"] = int(next_item.get("fail") or 0) + 1
            account = self._normalize_account(next_item)
            if account is None:
                return None
            if account.get("status") == "限流" and config.auto_remove_rate_limited_accounts:
                self._accounts.pop(access_token, None)
                self._save_accounts()
                log_service.add(LOG_TYPE_ACCOUNT, "自动移除限流账号", {"token": anonymize_token(access_token)})
                return None
            self._accounts[access_token] = account
            self._save_accounts()
            return dict(account)
        return None

    def fetch_remote_info(self, access_token: str, event: str = "fetch_remote_info") -> dict[str, Any] | None:
        if not access_token:
            raise ValueError("access_token is required")

        try:
            from services.openai_backend_api import InvalidAccessTokenError, OpenAIBackendAPI
            result = OpenAIBackendAPI(access_token).get_user_info()
        except InvalidAccessTokenError:
            self.remove_invalid_token(access_token, event)
            raise
        return self.update_account(access_token, result)

    def refresh_accounts(self, access_tokens: list[str]) -> dict[str, Any]:
        access_tokens = list(dict.fromkeys(token for token in access_tokens if token))
        if not access_tokens:
            return {"refreshed": 0, "errors": []}

        refreshed = 0
        errors = []
        max_workers = min(10, len(access_tokens))

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(self.fetch_remote_info, token, "refresh_accounts"): token
                for token in access_tokens
            }
            for future in as_completed(futures):
                try:
                    account = future.result()
                except Exception as exc:
                    errors.append({"token": anonymize_token(futures[future]), "error": str(exc)})
                    continue
                if account is not None:
                    refreshed += 1

        return {
            "refreshed": refreshed,
            "errors": errors,
        }


account_service = AccountService(config.get_storage_backend())
