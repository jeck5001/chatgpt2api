from __future__ import annotations

import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from threading import Lock, Thread
from typing import Any

from services.account_service import AccountService, account_service
from utils.helper import anonymize_token


class AccountRefreshJobService:
    def __init__(
        self,
        service: AccountService,
        *,
        batch_size: int = 100,
        max_workers: int = 10,
        max_jobs: int = 20,
    ) -> None:
        self.service = service
        self.batch_size = max(1, int(batch_size or 100))
        self.max_workers = max(1, int(max_workers or 10))
        self.max_jobs = max(1, int(max_jobs or 20))
        self._lock = Lock()
        self._jobs: dict[str, dict[str, Any]] = {}

    @staticmethod
    def _now() -> str:
        return datetime.now(timezone.utc).isoformat()

    def start(self, access_tokens: list[str]) -> dict[str, Any]:
        tokens = list(dict.fromkeys(str(token or "").strip() for token in access_tokens if str(token or "").strip()))
        if not tokens:
            raise ValueError("access_tokens is required")

        job_id = uuid.uuid4().hex
        job = {
            "job_id": job_id,
            "mode": "background",
            "status": "queued",
            "total": len(tokens),
            "completed": 0,
            "refreshed": 0,
            "failed": 0,
            "errors": [],
            "created_at": self._now(),
            "updated_at": self._now(),
        }
        with self._lock:
            self._jobs[job_id] = job
            self._trim_locked()

        thread = Thread(target=self._run, args=(job_id, tokens), name=f"account-refresh-{job_id[:8]}", daemon=True)
        thread.start()
        return dict(job)

    def get(self, job_id: str) -> dict[str, Any] | None:
        with self._lock:
            job = self._jobs.get(job_id)
            return dict(job) if job else None

    def _trim_locked(self) -> None:
        if len(self._jobs) <= self.max_jobs:
            return
        removable = sorted(
            (
                job
                for job in self._jobs.values()
                if job.get("status") in {"success", "partial", "error"}
            ),
            key=lambda item: str(item.get("updated_at") or ""),
        )
        for job in removable[: max(0, len(self._jobs) - self.max_jobs)]:
            self._jobs.pop(str(job.get("job_id")), None)

    def _update(self, job_id: str, **updates: Any) -> None:
        with self._lock:
            job = self._jobs.get(job_id)
            if job is None:
                return
            job.update(updates)
            job["updated_at"] = self._now()

    def _run(self, job_id: str, tokens: list[str]) -> None:
        self._update(job_id, status="running", started_at=self._now())
        try:
            for start in range(0, len(tokens), self.batch_size):
                batch = tokens[start:start + self.batch_size]
                result = self._refresh_batch(batch)
                with self._lock:
                    job = self._jobs.get(job_id)
                    if job is None:
                        return
                    job["completed"] = int(job.get("completed") or 0) + len(batch)
                    job["refreshed"] = int(job.get("refreshed") or 0) + int(result.get("refreshed") or 0)
                    batch_errors = result.get("errors") if isinstance(result.get("errors"), list) else []
                    job["failed"] = int(job.get("failed") or 0) + len(batch_errors)
                    job["errors"] = [*job.get("errors", []), *batch_errors][-50:]
                    job["updated_at"] = self._now()
            with self._lock:
                job = self._jobs.get(job_id)
                if job is not None:
                    job["status"] = "partial" if int(job.get("failed") or 0) else "success"
                    job["finished_at"] = self._now()
                    job["updated_at"] = self._now()
        except Exception as exc:
            self._update(job_id, status="error", error=str(exc), finished_at=self._now())

    def _refresh_batch(self, batch: list[str]) -> dict[str, Any]:
        refreshed = 0
        errors: list[dict[str, str]] = []
        max_workers = min(self.max_workers, len(batch))
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(self.service.fetch_remote_info, token, "refresh_accounts_background"): token
                for token in batch
            }
            for future in as_completed(futures):
                token = futures[future]
                try:
                    account = future.result()
                except Exception as exc:
                    errors.append({"token": anonymize_token(token), "error": str(exc)})
                    continue
                if account is not None:
                    refreshed += 1
        self.service.save_accounts_snapshot()
        # Yield briefly between batches so NAS deployments stay responsive.
        time.sleep(0.01)
        return {"refreshed": refreshed, "errors": errors}


account_refresh_job_service = AccountRefreshJobService(account_service)
