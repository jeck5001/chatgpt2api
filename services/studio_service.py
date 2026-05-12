from __future__ import annotations

import uuid
from datetime import datetime, timezone
from threading import RLock
from typing import Any

from services.config import config
from services.storage.base import StorageBackend

STATUS_QUEUED = "queued"
STATUS_RUNNING = "running"
STATUS_SUCCESS = "success"
STATUS_ERROR = "error"
TURN_STATUSES = {STATUS_QUEUED, STATUS_RUNNING, STATUS_SUCCESS, STATUS_ERROR}
MODES = {"generate", "edit"}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


def _clean(value: object) -> str:
    return str(value or "").strip()


def _owner_id(identity: dict[str, object]) -> str:
    return _clean(identity.get("id")) or "anonymous"


def _is_admin(identity: dict[str, object]) -> bool:
    return _clean(identity.get("role")).lower() == "admin"


def _public(item: dict[str, Any]) -> dict[str, Any]:
    return dict(item)


DEFAULT_TEMPLATES = [
    {
        "id": "builtin_product_photo",
        "name": "商业摄影 / 产品",
        "category": "商业摄影",
        "content": "高端产品商业摄影，真实光影，干净背景，浅景深，细节清晰",
        "builtin": True,
        "owner_id": "",
        "created_at": "2026-05-12T00:00:00+00:00",
        "updated_at": "2026-05-12T00:00:00+00:00",
    },
    {
        "id": "builtin_brand_poster",
        "name": "品牌海报 / 主视觉",
        "category": "品牌海报",
        "content": "品牌主视觉海报，高级排版，明确视觉焦点，适合营销物料",
        "builtin": True,
        "owner_id": "",
        "created_at": "2026-05-12T00:00:00+00:00",
        "updated_at": "2026-05-12T00:00:00+00:00",
    },
    {
        "id": "builtin_style_transfer",
        "name": "头像 / 风格迁移",
        "category": "头像",
        "content": "保留主体特征，转换为统一视觉风格，干净构图，适合作为头像",
        "builtin": True,
        "owner_id": "",
        "created_at": "2026-05-12T00:00:00+00:00",
        "updated_at": "2026-05-12T00:00:00+00:00",
    },
]


class StudioService:
    def __init__(self, storage: StorageBackend):
        self.storage = storage
        self._lock = RLock()
        self._state = self._normalize_state(self.storage.load_studio_state())

    def _normalize_state(self, raw: object) -> dict[str, list[dict[str, Any]]]:
        source = raw if isinstance(raw, dict) else {}
        state: dict[str, list[dict[str, Any]]] = {
            "projects": [],
            "conversations": [],
            "turns": [],
            "prompt_templates": [],
            "favorites": [],
        }
        for key in state:
            values = source.get(key)
            if isinstance(values, list):
                state[key] = [dict(item) for item in values if isinstance(item, dict)]
        existing_template_ids = {str(item.get("id") or "") for item in state["prompt_templates"]}
        for template in DEFAULT_TEMPLATES:
            if template["id"] not in existing_template_ids:
                state["prompt_templates"].append(dict(template))
        return state

    def _save_locked(self) -> None:
        self.storage.save_studio_state(self._state)

    def _visible(self, identity: dict[str, object], items: list[dict[str, Any]]) -> list[dict[str, Any]]:
        if _is_admin(identity):
            return [_public(item) for item in items]
        owner = _owner_id(identity)
        return [_public(item) for item in items if _clean(item.get("owner_id")) == owner]

    def _find_visible(self, identity: dict[str, object], key: str, item_id: str) -> dict[str, Any] | None:
        for item in self._state[key]:
            if item.get("id") != item_id:
                continue
            if _is_admin(identity) or _clean(item.get("owner_id")) == _owner_id(identity):
                return item
            return None
        return None

    def list_projects(self, identity: dict[str, object]) -> list[dict[str, Any]]:
        with self._lock:
            items = [item for item in self._visible(identity, self._state["projects"]) if not bool(item.get("archived"))]
            return sorted(items, key=lambda item: str(item.get("updated_at") or ""), reverse=True)

    def create_project(self, identity: dict[str, object], name: str) -> dict[str, Any]:
        normalized_name = _clean(name) or "未命名项目"
        now = _now_iso()
        with self._lock:
            item = {
                "id": _id("project"),
                "name": normalized_name,
                "owner_id": _owner_id(identity),
                "archived": False,
                "created_at": now,
                "updated_at": now,
            }
            self._state["projects"].append(item)
            self._save_locked()
            return _public(item)

    def update_project(
        self,
        identity: dict[str, object],
        project_id: str,
        updates: dict[str, Any],
    ) -> dict[str, Any] | None:
        with self._lock:
            item = self._find_visible(identity, "projects", project_id)
            if item is None:
                return None
            if "name" in updates:
                item["name"] = _clean(updates.get("name")) or item.get("name") or "未命名项目"
            if "archived" in updates:
                item["archived"] = bool(updates.get("archived"))
            item["updated_at"] = _now_iso()
            self._save_locked()
            return _public(item)

    def create_conversation(
        self,
        identity: dict[str, object],
        project_id: str,
        title: str,
        mode: str,
    ) -> dict[str, Any]:
        with self._lock:
            project = self._find_visible(identity, "projects", project_id)
            if project is None:
                raise ValueError("project not found")
            normalized_mode = mode if mode in MODES else "generate"
            now = _now_iso()
            item = {
                "id": _id("conversation"),
                "project_id": project_id,
                "owner_id": _owner_id(identity),
                "title": _clean(title) or "新的图片会话",
                "mode": normalized_mode,
                "created_at": now,
                "updated_at": now,
            }
            self._state["conversations"].append(item)
            project["updated_at"] = now
            self._save_locked()
            return _public(item)

    def list_conversations(self, identity: dict[str, object], project_id: str) -> list[dict[str, Any]]:
        with self._lock:
            project = self._find_visible(identity, "projects", project_id)
            if project is None:
                return []
            items = [
                _public(item)
                for item in self._state["conversations"]
                if item.get("project_id") == project_id
                and (_is_admin(identity) or item.get("owner_id") == _owner_id(identity))
            ]
            return sorted(items, key=lambda item: str(item.get("updated_at") or ""), reverse=True)

    def create_turn(self, identity: dict[str, object], conversation_id: str, **values: Any) -> dict[str, Any]:
        with self._lock:
            conversation = self._find_visible(identity, "conversations", conversation_id)
            if conversation is None:
                raise ValueError("conversation not found")
            now = _now_iso()
            status = _clean(values.get("status")) or STATUS_QUEUED
            if status not in TURN_STATUSES:
                status = STATUS_QUEUED
            item = {
                "id": _id("turn"),
                "conversation_id": conversation_id,
                "owner_id": _owner_id(identity),
                "client_task_id": _clean(values.get("client_task_id")),
                "task_id": _clean(values.get("task_id")),
                "mode": values.get("mode") if values.get("mode") in MODES else "generate",
                "prompt": _clean(values.get("prompt")),
                "model": _clean(values.get("model")) or "gpt-image-2",
                "size": _clean(values.get("size")),
                "reference_images": values.get("reference_images") if isinstance(values.get("reference_images"), list) else [],
                "result_images": values.get("result_images") if isinstance(values.get("result_images"), list) else [],
                "status": status,
                "error": _clean(values.get("error")),
                "created_at": now,
                "updated_at": now,
            }
            self._state["turns"].append(item)
            conversation["updated_at"] = now
            self._save_locked()
            return _public(item)

    def list_turns(self, identity: dict[str, object], conversation_id: str) -> list[dict[str, Any]]:
        with self._lock:
            conversation = self._find_visible(identity, "conversations", conversation_id)
            if conversation is None:
                return []
            return [
                _public(item)
                for item in sorted(self._state["turns"], key=lambda row: str(row.get("created_at") or ""))
                if item.get("conversation_id") == conversation_id
                and (_is_admin(identity) or item.get("owner_id") == _owner_id(identity))
            ]

    def list_prompt_templates(self, identity: dict[str, object]) -> list[dict[str, Any]]:
        with self._lock:
            owner = _owner_id(identity)
            items = [
                _public(item)
                for item in self._state["prompt_templates"]
                if bool(item.get("builtin")) or _is_admin(identity) or item.get("owner_id") == owner
            ]
            return sorted(items, key=lambda item: (str(item.get("category") or ""), str(item.get("name") or "")))

    def create_prompt_template(
        self,
        identity: dict[str, object],
        name: str,
        category: str,
        content: str,
    ) -> dict[str, Any]:
        if not _clean(content):
            raise ValueError("template content is required")
        now = _now_iso()
        with self._lock:
            item = {
                "id": _id("template"),
                "name": _clean(name) or "未命名模板",
                "category": _clean(category) or "自定义",
                "content": _clean(content),
                "builtin": False,
                "owner_id": _owner_id(identity),
                "created_at": now,
                "updated_at": now,
            }
            self._state["prompt_templates"].append(item)
            self._save_locked()
            return _public(item)

    def update_prompt_template(
        self,
        identity: dict[str, object],
        template_id: str,
        updates: dict[str, Any],
    ) -> dict[str, Any] | None:
        with self._lock:
            item = self._find_visible(identity, "prompt_templates", template_id)
            if item is None or bool(item.get("builtin")):
                return None
            if "name" in updates:
                item["name"] = _clean(updates.get("name")) or item.get("name") or "未命名模板"
            if "category" in updates:
                item["category"] = _clean(updates.get("category")) or item.get("category") or "自定义"
            if "content" in updates:
                content = _clean(updates.get("content"))
                if not content:
                    raise ValueError("template content is required")
                item["content"] = content
            item["updated_at"] = _now_iso()
            self._save_locked()
            return _public(item)

    def delete_prompt_template(self, identity: dict[str, object], template_id: str) -> bool:
        with self._lock:
            before = len(self._state["prompt_templates"])
            self._state["prompt_templates"] = [
                item
                for item in self._state["prompt_templates"]
                if not (
                    item.get("id") == template_id
                    and not bool(item.get("builtin"))
                    and (_is_admin(identity) or item.get("owner_id") == _owner_id(identity))
                )
            ]
            changed = len(self._state["prompt_templates"]) != before
            if changed:
                self._save_locked()
            return changed

    def add_favorite(
        self,
        identity: dict[str, object],
        image_path: str,
        source_turn_id: str = "",
        note: str = "",
    ) -> dict[str, Any]:
        normalized_path = _clean(image_path).lstrip("/")
        if not normalized_path:
            raise ValueError("image_path is required")
        owner = _owner_id(identity)
        now = _now_iso()
        with self._lock:
            for item in self._state["favorites"]:
                if item.get("owner_id") == owner and item.get("image_path") == normalized_path:
                    return _public(item)
            item = {
                "id": _id("favorite"),
                "owner_id": owner,
                "image_path": normalized_path,
                "source_turn_id": _clean(source_turn_id),
                "note": _clean(note),
                "created_at": now,
            }
            self._state["favorites"].append(item)
            self._save_locked()
            return _public(item)

    def list_favorites(self, identity: dict[str, object]) -> list[dict[str, Any]]:
        with self._lock:
            items = self._visible(identity, self._state["favorites"])
            return sorted(items, key=lambda item: str(item.get("created_at") or ""), reverse=True)

    def delete_favorite(self, identity: dict[str, object], favorite_id: str) -> bool:
        with self._lock:
            before = len(self._state["favorites"])
            self._state["favorites"] = [
                item
                for item in self._state["favorites"]
                if not (
                    item.get("id") == favorite_id
                    and (_is_admin(identity) or item.get("owner_id") == _owner_id(identity))
                )
            ]
            changed = len(self._state["favorites"]) != before
            if changed:
                self._save_locked()
            return changed


studio_service = StudioService(config.get_storage_backend())
