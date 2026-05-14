from __future__ import annotations

from copy import deepcopy
import uuid
from datetime import datetime, timezone
from threading import RLock
from typing import Any
from urllib.parse import urlsplit

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
    return deepcopy(item)


def _copy_list(value: object) -> list[Any]:
    return deepcopy(value) if isinstance(value, list) else []


def _image_path_from_url(url: str) -> str:
    marker = "/images/"
    if marker not in url:
        return ""
    path = urlsplit(url).path
    if marker not in path:
        return ""
    return path.split(marker, 1)[1].lstrip("/")


def _task_images(data: object) -> list[dict[str, Any]]:
    if not isinstance(data, list):
        return []
    images: list[dict[str, Any]] = []
    for source in data:
        if not isinstance(source, dict):
            continue
        image: dict[str, Any] = {}
        url = source.get("url")
        if isinstance(url, str) and url:
            image["url"] = url
            path = _image_path_from_url(url)
            if path:
                image["path"] = path
        b64_json = source.get("b64_json")
        if isinstance(b64_json, str) and b64_json:
            image["b64_json"] = b64_json
        revised_prompt = source.get("revised_prompt")
        if isinstance(revised_prompt, str) and revised_prompt:
            image["revised_prompt"] = revised_prompt
        if image:
            images.append(image)
    return images


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
                state[key] = [deepcopy(item) for item in values if isinstance(item, dict)]
        existing_template_ids = {str(item.get("id") or "") for item in state["prompt_templates"]}
        for template in DEFAULT_TEMPLATES:
            if template["id"] not in existing_template_ids:
                state["prompt_templates"].append(dict(template))
        return state

    def _save_locked(self) -> None:
        self.storage.save_studio_state(self._state)

    def _rollback_save_locked(self, before: dict[str, list[dict[str, Any]]]) -> None:
        try:
            self._save_locked()
        except Exception:
            self._state = before
            raise

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
            before = deepcopy(self._state)
            item = {
                "id": _id("project"),
                "name": normalized_name,
                "owner_id": _owner_id(identity),
                "archived": False,
                "created_at": now,
                "updated_at": now,
            }
            self._state["projects"].append(item)
            self._rollback_save_locked(before)
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
            before = deepcopy(self._state)
            if "name" in updates:
                item["name"] = _clean(updates.get("name")) or item.get("name") or "未命名项目"
            if "archived" in updates:
                item["archived"] = bool(updates.get("archived"))
            item["updated_at"] = _now_iso()
            self._rollback_save_locked(before)
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
            before = deepcopy(self._state)
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
            self._rollback_save_locked(before)
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

    def delete_conversation(self, identity: dict[str, object], conversation_id: str) -> bool:
        with self._lock:
            conversation = self._find_visible(identity, "conversations", conversation_id)
            if conversation is None:
                return False
            before = deepcopy(self._state)
            self._state["conversations"] = [
                item
                for item in self._state["conversations"]
                if item.get("id") != conversation_id
            ]
            self._state["turns"] = [
                item
                for item in self._state["turns"]
                if item.get("conversation_id") != conversation_id
            ]
            self._rollback_save_locked(before)
            return True

    def create_turn(self, identity: dict[str, object], conversation_id: str, **values: Any) -> dict[str, Any]:
        with self._lock:
            conversation = self._find_visible(identity, "conversations", conversation_id)
            if conversation is None:
                raise ValueError("conversation not found")
            before = deepcopy(self._state)
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
                "reference_images": _copy_list(values.get("reference_images")),
                "result_images": _copy_list(values.get("result_images")),
                "status": status,
                "error": _clean(values.get("error")),
                "created_at": now,
                "updated_at": now,
            }
            self._state["turns"].append(item)
            conversation["updated_at"] = now
            self._rollback_save_locked(before)
            return _public(item)

    def create_queued_turn(self, identity: dict[str, object], conversation_id: str, **values: Any) -> dict[str, Any]:
        with self._lock:
            conversation = self._find_visible(identity, "conversations", conversation_id)
            if conversation is None:
                raise ValueError("conversation not found")
            client_task_id = _clean(values.get("client_task_id"))
            if not client_task_id:
                raise ValueError("client_task_id is required")
            owner_id = _owner_id(identity)
            for item in self._state["turns"]:
                if _clean(item.get("owner_id")) != owner_id:
                    continue
                if _clean(item.get("client_task_id")) != client_task_id:
                    continue
                if item.get("conversation_id") == conversation_id:
                    return _public(item)
                raise ValueError("client_task_id is already used by another turn")
            before = deepcopy(self._state)
            now = _now_iso()
            item = {
                "id": _id("turn"),
                "conversation_id": conversation_id,
                "owner_id": owner_id,
                "client_task_id": client_task_id,
                "task_id": _clean(values.get("task_id")) or client_task_id,
                "mode": values.get("mode") if values.get("mode") in MODES else "generate",
                "prompt": _clean(values.get("prompt")),
                "model": _clean(values.get("model")) or "gpt-image-2",
                "size": _clean(values.get("size")),
                "reference_images": _copy_list(values.get("reference_images")),
                "result_images": [],
                "status": STATUS_QUEUED,
                "error": "",
                "created_at": now,
                "updated_at": now,
            }
            self._state["turns"].append(item)
            conversation["updated_at"] = now
            self._rollback_save_locked(before)
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

    def get_turn(self, identity: dict[str, object], turn_id: str) -> dict[str, Any] | None:
        with self._lock:
            item = self._find_visible(identity, "turns", turn_id)
            return _public(item) if item is not None else None

    def delete_turn(self, identity: dict[str, object], turn_id: str) -> bool:
        with self._lock:
            item = self._find_visible(identity, "turns", turn_id)
            if item is None:
                return False
            before = deepcopy(self._state)
            self._state["turns"] = [
                turn
                for turn in self._state["turns"]
                if turn.get("id") != turn_id
            ]
            self._rollback_save_locked(before)
            return True

    def sync_turn_from_task(
        self,
        identity: dict[str, object],
        turn_id: str,
        task: dict[str, Any],
    ) -> dict[str, Any] | None:
        with self._lock:
            item = self._find_visible(identity, "turns", turn_id)
            if item is None:
                return None
            before = deepcopy(self._state)
            now = _now_iso()
            task_id = _clean(task.get("id"))
            status = _clean(task.get("status"))
            if task_id:
                item["task_id"] = task_id
            if status in TURN_STATUSES:
                item["status"] = status
            if "data" in task:
                item["result_images"] = _task_images(task.get("data"))
            item["error"] = _clean(task.get("error"))
            item["updated_at"] = now
            conversation = self._find_visible(identity, "conversations", str(item.get("conversation_id") or ""))
            if conversation is not None:
                conversation["updated_at"] = now
            self._rollback_save_locked(before)
            return _public(item)

    def mark_turn_retrying(self, identity: dict[str, object], turn_id: str, client_task_id: str) -> dict[str, Any] | None:
        with self._lock:
            item = self._find_visible(identity, "turns", turn_id)
            if item is None:
                return None
            task_id = _clean(client_task_id)
            if not task_id:
                raise ValueError("client_task_id is required")
            if item.get("mode") == "edit":
                raise ValueError("edit retry is not supported because reference images are not persisted")
            if item.get("status") != STATUS_ERROR:
                raise ValueError("only error turns can be retried")
            if _clean(item.get("client_task_id")) == task_id:
                raise ValueError("retry client_task_id must be different from the current turn")
            owner_id = _clean(item.get("owner_id"))
            for other in self._state["turns"]:
                if other.get("id") == turn_id:
                    continue
                if _clean(other.get("owner_id")) != owner_id:
                    continue
                if _clean(other.get("client_task_id")) == task_id:
                    raise ValueError("client_task_id is already used by another turn")
            before = deepcopy(self._state)
            now = _now_iso()
            item["client_task_id"] = task_id
            item["task_id"] = task_id
            item["status"] = STATUS_QUEUED
            item["error"] = ""
            item["result_images"] = []
            item["updated_at"] = now
            conversation = self._find_visible(identity, "conversations", str(item.get("conversation_id") or ""))
            if conversation is not None:
                conversation["updated_at"] = now
            self._rollback_save_locked(before)
            return _public(item)

    def mark_turn_error(
        self,
        identity: dict[str, object],
        turn_id: str,
        error: str,
        *,
        task_id: str | None = None,
    ) -> dict[str, Any] | None:
        with self._lock:
            item = self._find_visible(identity, "turns", turn_id)
            if item is None:
                return None
            before = deepcopy(self._state)
            now = _now_iso()
            if task_id is not None:
                item["task_id"] = _clean(task_id)
            item["status"] = STATUS_ERROR
            item["error"] = _clean(error) or "image task submit failed"
            item["result_images"] = []
            item["updated_at"] = now
            conversation = self._find_visible(identity, "conversations", str(item.get("conversation_id") or ""))
            if conversation is not None:
                conversation["updated_at"] = now
            self._rollback_save_locked(before)
            return _public(item)

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
            before = deepcopy(self._state)
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
            self._rollback_save_locked(before)
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
            before = deepcopy(self._state)
            next_name = item.get("name") or "未命名模板"
            next_category = item.get("category") or "自定义"
            next_content = item.get("content") or ""
            if "name" in updates:
                next_name = _clean(updates.get("name")) or next_name
            if "category" in updates:
                next_category = _clean(updates.get("category")) or next_category
            if "content" in updates:
                content = _clean(updates.get("content"))
                if not content:
                    raise ValueError("template content is required")
                next_content = content
            item["name"] = next_name
            item["category"] = next_category
            item["content"] = next_content
            item["updated_at"] = _now_iso()
            self._rollback_save_locked(before)
            return _public(item)

    def delete_prompt_template(self, identity: dict[str, object], template_id: str) -> bool:
        with self._lock:
            before_state = deepcopy(self._state)
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
                self._rollback_save_locked(before_state)
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
            before = deepcopy(self._state)
            item = {
                "id": _id("favorite"),
                "owner_id": owner,
                "image_path": normalized_path,
                "source_turn_id": _clean(source_turn_id),
                "note": _clean(note),
                "created_at": now,
            }
            self._state["favorites"].append(item)
            self._rollback_save_locked(before)
            return _public(item)

    def list_favorites(self, identity: dict[str, object]) -> list[dict[str, Any]]:
        with self._lock:
            items = self._visible(identity, self._state["favorites"])
            return sorted(items, key=lambda item: str(item.get("created_at") or ""), reverse=True)

    def delete_favorite(self, identity: dict[str, object], favorite_id: str) -> bool:
        with self._lock:
            before_state = deepcopy(self._state)
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
                self._rollback_save_locked(before_state)
            return changed


studio_service = StudioService(config.get_storage_backend())
