# Internal Image Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a server-backed internal AI image studio that replaces the current local-only `/image` experience with projects, conversations, turns, prompt templates, favorites, and a polished three-column creation workspace.

**Architecture:** Add a focused studio domain layer behind the existing FastAPI app, persisted through the current storage abstraction so JSON, SQLite/PostgreSQL, and git backends keep working. Keep image execution in `ImageTaskService`; new studio turn endpoints create metadata records and delegate generation/edit execution to the existing task service.

**Tech Stack:** Python 3.13, FastAPI, Pydantic, SQLAlchemy, unittest/TestClient, Next.js 16, React 19, TypeScript, localforage, existing UI primitives in `web/src/components/ui`.

---

## File Structure

Backend files:

- Modify `services/storage/base.py`: add abstract `load_studio_state()` and `save_studio_state()` methods.
- Modify `services/storage/json_storage.py`: persist studio records in `data/studio.json`.
- Modify `services/storage/database_storage.py`: add `studio_state` table with JSON payload.
- Modify `services/storage/git_storage.py`: persist studio records in `studio.json` inside the configured repo.
- Modify `services/storage/factory.py`: pass the new git studio file path option.
- Create `services/studio_service.py`: own normalization, authorization filtering, project/conversation/turn/template/favorite operations, and turn/task sync rules.
- Create `api/studio.py`: expose project, conversation, turn, template, and favorite endpoints.
- Modify `api/app.py`: include the studio router.
- Modify `api/system.py`: keep current image manager responses stable while the frontend decorates favorite state from `/api/image-favorites`.
- Modify `services/image_task_service.py`: expose a small public helper for reading a task by identity and ID if the studio service needs one.

Backend tests:

- Create `test/test_studio_service.py`: service-level storage, authorization, turn sync, retry, and favorite tests.
- Create `test/test_studio_api.py`: FastAPI route tests with fake studio/image task services.
- Modify `test/test_image_tasks_api.py`: regression test that existing image task endpoints still work.
- Modify `scripts/test_storage.py`: include smoke coverage for studio state load/save when storage is exercised by script.

Frontend files:

- Modify `web/src/lib/api.ts`: add studio types and request helpers.
- Create `web/src/app/image/types.ts`: studio UI types that should not live in the page component.
- Create `web/src/app/image/lib.ts`: pure helpers for IDs, titles, task status derivation, reference conversion, and prompt drafts.
- Create `web/src/app/image/components/studio-shell.tsx`: desktop/mobile layout shell.
- Create `web/src/app/image/components/project-rail.tsx`: project and recent conversation list.
- Create `web/src/app/image/components/studio-composer.tsx`: prompt composer, mode, model, size, count, references, and generate/edit submit.
- Create `web/src/app/image/components/studio-results.tsx`: turn list, result cards, retry, favorite, continue editing, and lightbox trigger.
- Create `web/src/app/image/components/studio-inspector.tsx`: templates, references, quota/status summary.
- Modify `web/src/app/image/page.tsx`: turn current monolithic page into orchestration around the new components.
- Modify `web/src/app/image-manager/page.tsx`: add favorite filter/action and "reuse to edit" action.
- Modify `web/src/store/image-conversations.ts`: keep local migration helpers available for the legacy-data notice.

Frontend validation:

- Run `cd web && bun run build`.
- Use Browser against the local app after implementation to check `/image` on desktop and 390px mobile width.

---

## Task 1: Add Studio State to Storage Backends

**Files:**
- Modify: `services/storage/base.py`
- Modify: `services/storage/json_storage.py`
- Modify: `services/storage/database_storage.py`
- Modify: `services/storage/git_storage.py`
- Modify: `services/storage/factory.py`
- Test: `test/test_studio_service.py`

- [ ] **Step 1: Write failing storage contract tests**

Add this starter test file at `test/test_studio_service.py`:

```python
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from services.storage.json_storage import JSONStorageBackend


class StudioStorageTests(unittest.TestCase):
    def test_json_storage_round_trips_studio_state(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            data_dir = Path(tmp_dir)
            storage = JSONStorageBackend(data_dir / "accounts.json", data_dir / "auth_keys.json")
            state = {
                "projects": [{"id": "project-1", "owner_id": "owner-1", "name": "Spring"}],
                "conversations": [{"id": "conversation-1", "project_id": "project-1"}],
                "turns": [{"id": "turn-1", "conversation_id": "conversation-1"}],
                "prompt_templates": [{"id": "template-1", "name": "Product"}],
                "favorites": [{"id": "favorite-1", "image_path": "2026/05/image.png"}],
            }

            storage.save_studio_state(state)
            reloaded = JSONStorageBackend(data_dir / "accounts.json", data_dir / "auth_keys.json")

            self.assertEqual(reloaded.load_studio_state(), state)
```

- [ ] **Step 2: Run the failing test**

Run: `uv run python -m unittest test.test_studio_service.StudioStorageTests.test_json_storage_round_trips_studio_state -v`

Expected: FAIL with an attribute error because `JSONStorageBackend` does not have `save_studio_state`.

- [ ] **Step 3: Extend the abstract storage interface**

In `services/storage/base.py`, add these abstract methods to `StorageBackend`:

```python
    @abstractmethod
    def load_studio_state(self) -> dict[str, Any]:
        """加载图片工作台项目、会话、轮次、模板和收藏数据"""
        pass

    @abstractmethod
    def save_studio_state(self, state: dict[str, Any]) -> None:
        """保存图片工作台数据"""
        pass
```

- [ ] **Step 4: Implement JSON storage**

In `services/storage/json_storage.py`, update `__init__` and add the methods:

```python
    def __init__(self, file_path: Path, auth_keys_path: Path | None = None, studio_path: Path | None = None):
        self.file_path = file_path
        self.auth_keys_path = auth_keys_path or file_path.with_name("auth_keys.json")
        self.studio_path = studio_path or file_path.with_name("studio.json")
        self.file_path.parent.mkdir(parents=True, exist_ok=True)
        self.auth_keys_path.parent.mkdir(parents=True, exist_ok=True)
        self.studio_path.parent.mkdir(parents=True, exist_ok=True)
```

```python
    def load_studio_state(self) -> dict[str, Any]:
        if not self.studio_path.exists():
            return {}
        try:
            data = json.loads(self.studio_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, Exception):
            return {}
        return data if isinstance(data, dict) else {}

    def save_studio_state(self, state: dict[str, Any]) -> None:
        self.studio_path.parent.mkdir(parents=True, exist_ok=True)
        self.studio_path.write_text(
            json.dumps(state, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
```

Also include `studio_file_exists` and `studio_file_path` in `health_check()` and `get_backend_info()`.

- [ ] **Step 5: Run the JSON storage test**

Run: `uv run python -m unittest test.test_studio_service.StudioStorageTests.test_json_storage_round_trips_studio_state -v`

Expected: PASS.

- [ ] **Step 6: Implement database storage**

In `services/storage/database_storage.py`, add a model:

```python
class StudioStateModel(Base):
    """图片工作台聚合状态"""
    __tablename__ = "studio_state"

    id = Column(String(64), primary_key=True)
    data = Column(Text, nullable=False)
```

Add methods to `DatabaseStorageBackend`:

```python
    def load_studio_state(self) -> dict[str, Any]:
        session = self.Session()
        try:
            row = session.query(StudioStateModel).filter_by(id="default").first()
            if row is None:
                return {}
            data = json.loads(row.data)
            return data if isinstance(data, dict) else {}
        except json.JSONDecodeError:
            return {}
        finally:
            session.close()

    def save_studio_state(self, state: dict[str, Any]) -> None:
        session = self.Session()
        try:
            row = session.query(StudioStateModel).filter_by(id="default").first()
            payload = json.dumps(state, ensure_ascii=False)
            if row is None:
                session.add(StudioStateModel(id="default", data=payload))
            else:
                row.data = payload
            session.commit()
        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()
```

Update `health_check()` to include `studio_state_count`.

- [ ] **Step 7: Implement git storage**

In `services/storage/git_storage.py`, add `studio_file_path` to `__init__` and methods:

```python
        studio_file_path: str = "studio.json",
```

```python
        self.studio_file_path = studio_file_path
```

```python
    def load_studio_state(self) -> dict[str, Any]:
        try:
            data = self._load_json_value(self.studio_file_path)
            return data if isinstance(data, dict) else {}
        except Exception as e:
            print(f"[git-storage] load studio state failed: {e}")
            raise

    def save_studio_state(self, state: dict[str, Any]) -> None:
        try:
            self._save_json_file(self.studio_file_path, state, "Update studio state")
        except Exception as e:
            print(f"[git-storage] save studio state failed: {e}")
            raise e
```

Include `studio_file_path` in `health_check()` and `get_backend_info()`.

- [ ] **Step 8: Wire factory options**

In `services/storage/factory.py`, pass `studio_path` for JSON:

```python
studio_path = data_dir / "studio.json"
return JSONStorageBackend(file_path, auth_keys_path, studio_path)
```

For git, read:

```python
studio_file_path = os.getenv("GIT_STUDIO_FILE_PATH", "studio.json").strip()
```

and pass `studio_file_path=studio_file_path`.

- [ ] **Step 9: Run storage and existing tests**

Run: `uv run python -m unittest test.test_studio_service test.test_config -v`

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add services/storage/base.py services/storage/json_storage.py services/storage/database_storage.py services/storage/git_storage.py services/storage/factory.py test/test_studio_service.py
git commit -m "feat: add studio storage state"
```

---

## Task 2: Build Studio Service Domain Logic

**Files:**
- Create: `services/studio_service.py`
- Modify: `test/test_studio_service.py`

- [ ] **Step 1: Add failing service tests**

Append these tests to `test/test_studio_service.py`:

```python
from services.studio_service import StudioService


OWNER = {"id": "owner-1", "name": "Owner", "role": "user"}
OTHER_OWNER = {"id": "owner-2", "name": "Other", "role": "user"}
ADMIN = {"id": "admin-1", "name": "Admin", "role": "admin"}


class StudioServiceTests(unittest.TestCase):
    def make_service(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir)
            storage = JSONStorageBackend(path / "accounts.json", path / "auth_keys.json", path / "studio.json")
            return StudioService(storage), storage, path

    def test_user_project_conversation_turn_lifecycle(self):
        service, _storage, _path = self.make_service()

        project = service.create_project(OWNER, "Spring Campaign")
        conversation = service.create_conversation(OWNER, project["id"], "Hero images", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="orange product photo",
            model="gpt-image-2",
            size="1024x1024",
            reference_images=[],
        )

        self.assertEqual(service.list_projects(OWNER)[0]["name"], "Spring Campaign")
        self.assertEqual(service.list_conversations(OWNER, project["id"])[0]["id"], conversation["id"])
        self.assertEqual(service.list_turns(OWNER, conversation["id"])[0]["id"], turn["id"])

    def test_user_cannot_access_other_users_project(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Private")

        with self.assertRaises(ValueError) as ctx:
            service.create_conversation(OTHER_OWNER, project["id"], "Nope", "generate")

        self.assertIn("not found", str(ctx.exception).lower())

    def test_admin_can_list_all_projects(self):
        service, _storage, _path = self.make_service()
        service.create_project(OWNER, "Owner Project")
        service.create_project(OTHER_OWNER, "Other Project")

        names = [item["name"] for item in service.list_projects(ADMIN)]

        self.assertEqual(names, ["Other Project", "Owner Project"])

    def test_favorite_is_idempotent_by_owner_and_path(self):
        service, _storage, _path = self.make_service()

        first = service.add_favorite(OWNER, "2026/05/image.png", source_turn_id="turn-1")
        second = service.add_favorite(OWNER, "2026/05/image.png", source_turn_id="turn-1")

        self.assertEqual(first["id"], second["id"])
        self.assertEqual(len(service.list_favorites(OWNER)), 1)
```

- [ ] **Step 2: Run failing service tests**

Run: `uv run python -m unittest test.test_studio_service.StudioServiceTests -v`

Expected: FAIL because `services.studio_service` does not exist.

- [ ] **Step 3: Create `services/studio_service.py` with state normalization**

Create the file with this foundation:

```python
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
```

- [ ] **Step 4: Implement service methods**

Continue `services/studio_service.py` with:

```python
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
```

Add project, conversation, and turn methods:

```python
    def update_project(self, identity: dict[str, object], project_id: str, updates: dict[str, Any]) -> dict[str, Any] | None:
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

    def create_conversation(self, identity: dict[str, object], project_id: str, title: str, mode: str) -> dict[str, Any]:
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
                if item.get("project_id") == project_id and (_is_admin(identity) or item.get("owner_id") == _owner_id(identity))
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
                if item.get("conversation_id") == conversation_id and (_is_admin(identity) or item.get("owner_id") == _owner_id(identity))
            ]
```

Add templates and favorites:

```python
    def list_prompt_templates(self, identity: dict[str, object]) -> list[dict[str, Any]]:
        with self._lock:
            owner = _owner_id(identity)
            items = [
                _public(item)
                for item in self._state["prompt_templates"]
                if bool(item.get("builtin")) or _is_admin(identity) or item.get("owner_id") == owner
            ]
            return sorted(items, key=lambda item: (str(item.get("category") or ""), str(item.get("name") or "")))

    def create_prompt_template(self, identity: dict[str, object], name: str, category: str, content: str) -> dict[str, Any]:
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

    def update_prompt_template(self, identity: dict[str, object], template_id: str, updates: dict[str, Any]) -> dict[str, Any] | None:
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

    def add_favorite(self, identity: dict[str, object], image_path: str, source_turn_id: str = "", note: str = "") -> dict[str, Any]:
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
                if not (item.get("id") == favorite_id and (_is_admin(identity) or item.get("owner_id") == _owner_id(identity)))
            ]
            changed = len(self._state["favorites"]) != before
            if changed:
                self._save_locked()
            return changed
```

At the bottom:

```python
studio_service = StudioService(config.get_storage_backend())
```

- [ ] **Step 5: Run service tests**

Run: `uv run python -m unittest test.test_studio_service -v`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add services/studio_service.py test/test_studio_service.py
git commit -m "feat: add studio domain service"
```

---

## Task 3: Add Studio API Routes

**Files:**
- Create: `api/studio.py`
- Modify: `api/app.py`
- Create: `test/test_studio_api.py`

- [ ] **Step 1: Write failing API tests**

Create `test/test_studio_api.py`:

```python
from __future__ import annotations

import unittest
from unittest import mock

from fastapi import FastAPI
from fastapi.testclient import TestClient

import api.studio as studio_module


AUTH_HEADERS = {"Authorization": "Bearer chatgpt2api"}


class FakeStudioService:
    def __init__(self):
        self.projects = []
        self.favorites = []

    def list_projects(self, identity):
        return self.projects

    def create_project(self, identity, name):
        item = {"id": "project-1", "name": name, "owner_id": identity["id"], "archived": False}
        self.projects.append(item)
        return item

    def list_prompt_templates(self, identity):
        return [{"id": "template-1", "name": "商业摄影 / 产品", "content": "product photo"}]

    def add_favorite(self, identity, image_path, source_turn_id="", note=""):
        item = {"id": "favorite-1", "owner_id": identity["id"], "image_path": image_path, "source_turn_id": source_turn_id, "note": note}
        self.favorites.append(item)
        return item


class StudioApiTests(unittest.TestCase):
    def setUp(self):
        self.fake_service = FakeStudioService()
        self.service_patcher = mock.patch.object(studio_module, "studio_service", self.fake_service)
        self.service_patcher.start()
        self.addCleanup(self.service_patcher.stop)
        app = FastAPI()
        app.include_router(studio_module.create_router())
        self.client = TestClient(app)

    def test_create_project(self):
        response = self.client.post("/api/projects", headers=AUTH_HEADERS, json={"name": "Spring"})

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["item"]["name"], "Spring")

    def test_list_prompt_templates(self):
        response = self.client.get("/api/prompt-templates", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["items"][0]["id"], "template-1")

    def test_add_favorite(self):
        response = self.client.post(
            "/api/image-favorites",
            headers=AUTH_HEADERS,
            json={"image_path": "2026/05/image.png", "source_turn_id": "turn-1"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["item"]["image_path"], "2026/05/image.png")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run failing API tests**

Run: `uv run python -m unittest test.test_studio_api -v`

Expected: FAIL because `api.studio` does not exist.

- [ ] **Step 3: Create `api/studio.py` request models and basic routes**

Create `api/studio.py`:

```python
from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from api.support import require_identity
from services.studio_service import studio_service


class ProjectCreateRequest(BaseModel):
    name: str = ""


class ProjectUpdateRequest(BaseModel):
    name: str | None = None
    archived: bool | None = None


class ConversationCreateRequest(BaseModel):
    project_id: str = Field(..., min_length=1)
    title: str = ""
    mode: str = "generate"


class FavoriteCreateRequest(BaseModel):
    image_path: str = Field(..., min_length=1)
    source_turn_id: str = ""
    note: str = ""


class TemplateCreateRequest(BaseModel):
    name: str = ""
    category: str = ""
    content: str = Field(..., min_length=1)
```

Add route factory:

```python
def create_router() -> APIRouter:
    router = APIRouter()

    @router.get("/api/projects")
    async def list_projects(authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        return {"items": studio_service.list_projects(identity)}

    @router.post("/api/projects")
    async def create_project(body: ProjectCreateRequest, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        return {"item": studio_service.create_project(identity, body.name)}

    @router.patch("/api/projects/{project_id}")
    async def update_project(project_id: str, body: ProjectUpdateRequest, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        item = studio_service.update_project(identity, project_id, body.model_dump(exclude_none=True))
        if item is None:
            raise HTTPException(status_code=404, detail={"error": "project not found"})
        return {"item": item}

    @router.get("/api/prompt-templates")
    async def list_prompt_templates(authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        return {"items": studio_service.list_prompt_templates(identity)}

    @router.post("/api/image-favorites")
    async def add_favorite(body: FavoriteCreateRequest, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        try:
            item = studio_service.add_favorite(identity, body.image_path, body.source_turn_id, body.note)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail={"error": str(exc)}) from exc
        return {"item": item}

    @router.get("/api/image-favorites")
    async def list_favorites(authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        return {"items": studio_service.list_favorites(identity)}

    @router.delete("/api/image-favorites/{favorite_id}")
    async def delete_favorite(favorite_id: str, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        if not studio_service.delete_favorite(identity, favorite_id):
            raise HTTPException(status_code=404, detail={"error": "favorite not found"})
        return {"ok": True}

    return router
```

- [ ] **Step 4: Add conversation/template update routes**

Extend `api/studio.py`:

```python
class TemplateUpdateRequest(BaseModel):
    name: str | None = None
    category: str | None = None
    content: str | None = None
```

Add routes:

```python
    @router.get("/api/image-conversations")
    async def list_conversations(project_id: str = "", authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        return {"items": studio_service.list_conversations(identity, project_id)}

    @router.post("/api/image-conversations")
    async def create_conversation(body: ConversationCreateRequest, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        try:
            return {"item": studio_service.create_conversation(identity, body.project_id, body.title, body.mode)}
        except ValueError as exc:
            raise HTTPException(status_code=404, detail={"error": str(exc)}) from exc

    @router.post("/api/prompt-templates")
    async def create_prompt_template(body: TemplateCreateRequest, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        try:
            return {"item": studio_service.create_prompt_template(identity, body.name, body.category, body.content)}
        except ValueError as exc:
            raise HTTPException(status_code=400, detail={"error": str(exc)}) from exc

    @router.patch("/api/prompt-templates/{template_id}")
    async def update_prompt_template(template_id: str, body: TemplateUpdateRequest, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        try:
            item = studio_service.update_prompt_template(identity, template_id, body.model_dump(exclude_none=True))
        except ValueError as exc:
            raise HTTPException(status_code=400, detail={"error": str(exc)}) from exc
        if item is None:
            raise HTTPException(status_code=404, detail={"error": "template not found"})
        return {"item": item}

    @router.delete("/api/prompt-templates/{template_id}")
    async def delete_prompt_template(template_id: str, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        if not studio_service.delete_prompt_template(identity, template_id):
            raise HTTPException(status_code=404, detail={"error": "template not found"})
        return {"ok": True}
```

- [ ] **Step 5: Register the router**

In `api/app.py`, import and include `studio`:

```python
from api import accounts, ai, image_tasks, register, studio, system
```

```python
    app.include_router(studio.create_router())
```

Place it before `system.create_router(app_version)` so internal API routes are registered before the static fallback.

- [ ] **Step 6: Run API tests**

Run: `uv run python -m unittest test.test_studio_api test.test_image_tasks_api -v`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add api/studio.py api/app.py test/test_studio_api.py
git commit -m "feat: add studio api routes"
```

---

## Task 4: Add Turn Endpoints That Delegate to Image Tasks

**Files:**
- Modify: `services/studio_service.py`
- Modify: `services/image_task_service.py`
- Modify: `api/studio.py`
- Modify: `test/test_studio_service.py`
- Modify: `test/test_studio_api.py`

- [ ] **Step 1: Write failing turn sync tests**

Add to `StudioServiceTests` in `test/test_studio_service.py`:

```python
    def test_sync_turn_from_successful_task(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="cat",
            model="gpt-image-2",
            size="",
            reference_images=[],
        )

        synced = service.sync_turn_from_task(
            OWNER,
            turn["id"],
            {"id": "task-1", "status": "success", "data": [{"url": "http://testserver/images/2026/05/cat.png"}]},
        )

        self.assertEqual(synced["status"], "success")
        self.assertEqual(synced["result_images"][0]["url"], "http://testserver/images/2026/05/cat.png")

    def test_retry_failed_turn_clears_error_and_uses_new_task_id(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="cat",
            model="gpt-image-2",
            size="",
            reference_images=[],
            status="error",
            error="failed",
        )

        retried = service.mark_turn_retrying(OWNER, turn["id"], "task-2")

        self.assertEqual(retried["status"], "queued")
        self.assertEqual(retried["client_task_id"], "task-2")
        self.assertEqual(retried["error"], "")
```

- [ ] **Step 2: Run failing turn tests**

Run: `uv run python -m unittest test.test_studio_service.StudioServiceTests.test_sync_turn_from_successful_task test.test_studio_service.StudioServiceTests.test_retry_failed_turn_clears_error_and_uses_new_task_id -v`

Expected: FAIL because sync/retry methods do not exist.

- [ ] **Step 3: Add public task lookup**

In `services/image_task_service.py`, add:

```python
    def get_task(self, identity: dict[str, object], task_id: str) -> dict[str, Any] | None:
        result = self.list_tasks(identity, [task_id])
        items = result.get("items") or []
        return items[0] if items else None
```

- [ ] **Step 4: Add turn sync methods**

In `services/studio_service.py`, add:

```python
def _image_path_from_url(url: str) -> str:
    marker = "/images/"
    if marker not in url:
        return ""
    return url.split(marker, 1)[1].strip("/")
```

Add service methods:

```python
    def get_turn(self, identity: dict[str, object], turn_id: str) -> dict[str, Any] | None:
        with self._lock:
            item = self._find_visible(identity, "turns", turn_id)
            return _public(item) if item is not None else None

    def sync_turn_from_task(self, identity: dict[str, object], turn_id: str, task: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            turn = self._find_visible(identity, "turns", turn_id)
            if turn is None:
                raise ValueError("turn not found")
            status = _clean(task.get("status"))
            if status in TURN_STATUSES:
                turn["status"] = status
            data = task.get("data")
            if isinstance(data, list):
                results = []
                for item in data:
                    if not isinstance(item, dict):
                        continue
                    url = _clean(item.get("url"))
                    b64_json = _clean(item.get("b64_json"))
                    results.append({
                        "url": url,
                        "path": _image_path_from_url(url),
                        "b64_json": b64_json,
                        "revised_prompt": _clean(item.get("revised_prompt")),
                    })
                turn["result_images"] = results
            turn["error"] = _clean(task.get("error"))
            turn["updated_at"] = _now_iso()
            self._save_locked()
            return _public(turn)

    def mark_turn_retrying(self, identity: dict[str, object], turn_id: str, client_task_id: str) -> dict[str, Any]:
        with self._lock:
            turn = self._find_visible(identity, "turns", turn_id)
            if turn is None:
                raise ValueError("turn not found")
            task_id = _clean(client_task_id)
            if not task_id:
                raise ValueError("client_task_id is required")
            turn["client_task_id"] = task_id
            turn["task_id"] = task_id
            turn["status"] = STATUS_QUEUED
            turn["error"] = ""
            turn["result_images"] = []
            turn["updated_at"] = _now_iso()
            self._save_locked()
            return _public(turn)
```

- [ ] **Step 5: Add route request models for turn submission**

In `api/studio.py`, add imports and models:

```python
from fastapi import File, Form, Request, UploadFile
from fastapi.concurrency import run_in_threadpool

from api.support import resolve_image_base_url
from services.image_task_service import image_task_service
```

```python
class TurnGenerationRequest(BaseModel):
    conversation_id: str = Field(..., min_length=1)
    client_task_id: str = Field(..., min_length=1)
    prompt: str = Field(..., min_length=1)
    model: str = "gpt-image-2"
    size: str | None = None


class TurnRetryRequest(BaseModel):
    client_task_id: str = Field(..., min_length=1)
```

- [ ] **Step 6: Add turn routes**

In `api/studio.py`, add:

```python
    @router.get("/api/image-turns")
    async def list_turns(conversation_id: str = "", authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        return {"items": studio_service.list_turns(identity, conversation_id)}

    @router.post("/api/image-turns/generations")
    async def create_generation_turn(body: TurnGenerationRequest, request: Request, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        try:
            task = await run_in_threadpool(
                image_task_service.submit_generation,
                identity,
                client_task_id=body.client_task_id,
                prompt=body.prompt,
                model=body.model,
                size=body.size,
                base_url=resolve_image_base_url(request),
            )
            turn = studio_service.create_turn(
                identity,
                body.conversation_id,
                client_task_id=body.client_task_id,
                task_id=task["id"],
                mode="generate",
                prompt=body.prompt,
                model=body.model,
                size=body.size,
                reference_images=[],
                status=task.get("status", "queued"),
            )
            return {"item": studio_service.sync_turn_from_task(identity, turn["id"], task)}
        except ValueError as exc:
            raise HTTPException(status_code=400, detail={"error": str(exc)}) from exc

    @router.post("/api/image-turns/{turn_id}/sync")
    async def sync_turn(turn_id: str, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        turn = studio_service.get_turn(identity, turn_id)
        if turn is None:
            raise HTTPException(status_code=404, detail={"error": "turn not found"})
        task = image_task_service.get_task(identity, str(turn.get("task_id") or ""))
        if task is None:
            raise HTTPException(status_code=404, detail={"error": "task not found"})
        return {"item": studio_service.sync_turn_from_task(identity, turn_id, task)}
```

Add the edit route:

```python
    @router.post("/api/image-turns/edits")
    async def create_edit_turn(
        request: Request,
        authorization: str | None = Header(default=None),
        image: list[UploadFile] | None = File(default=None),
        image_list: list[UploadFile] | None = File(default=None, alias="image[]"),
        conversation_id: str = Form(...),
        client_task_id: str = Form(...),
        prompt: str = Form(...),
        model: str = Form(default="gpt-image-2"),
        size: str | None = Form(default=None),
    ):
        identity = require_identity(authorization)
        uploads = [*(image or []), *(image_list or [])]
        if not uploads:
            raise HTTPException(status_code=400, detail={"error": "image file is required"})
        images: list[tuple[bytes, str, str]] = []
        reference_images: list[dict[str, str]] = []
        for upload in uploads:
            image_data = await upload.read()
            if not image_data:
                raise HTTPException(status_code=400, detail={"error": "image file is empty"})
            filename = upload.filename or "image.png"
            content_type = upload.content_type or "image/png"
            images.append((image_data, filename, content_type))
            reference_images.append({"name": filename, "type": content_type})
        try:
            task = await run_in_threadpool(
                image_task_service.submit_edit,
                identity,
                client_task_id=client_task_id,
                prompt=prompt,
                model=model,
                size=size,
                base_url=resolve_image_base_url(request),
                images=images,
            )
            turn = studio_service.create_turn(
                identity,
                conversation_id,
                client_task_id=client_task_id,
                task_id=task["id"],
                mode="edit",
                prompt=prompt,
                model=model,
                size=size,
                reference_images=reference_images,
                status=task.get("status", "queued"),
            )
            return {"item": studio_service.sync_turn_from_task(identity, turn["id"], task)}
        except ValueError as exc:
            raise HTTPException(status_code=400, detail={"error": str(exc)}) from exc
```

- [ ] **Step 7: Add retry route**

Add:

```python
    @router.post("/api/image-turns/{turn_id}/retry")
    async def retry_turn(turn_id: str, body: TurnRetryRequest, request: Request, authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        turn = studio_service.get_turn(identity, turn_id)
        if turn is None:
            raise HTTPException(status_code=404, detail={"error": "turn not found"})
        try:
            if turn.get("mode") == "edit":
                raise HTTPException(status_code=400, detail={"error": "edit retry requires re-uploading reference images in this MVP"})
            task = await run_in_threadpool(
                image_task_service.submit_generation,
                identity,
                client_task_id=body.client_task_id,
                prompt=str(turn.get("prompt") or ""),
                model=str(turn.get("model") or "gpt-image-2"),
                size=str(turn.get("size") or "") or None,
                base_url=resolve_image_base_url(request),
            )
            retried = studio_service.mark_turn_retrying(identity, turn_id, body.client_task_id)
            return {"item": studio_service.sync_turn_from_task(identity, retried["id"], task)}
        except ValueError as exc:
            raise HTTPException(status_code=400, detail={"error": str(exc)}) from exc
```

- [ ] **Step 8: Run turn tests**

Run: `uv run python -m unittest test.test_studio_service test.test_studio_api test.test_image_task_service -v`

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add services/studio_service.py services/image_task_service.py api/studio.py test/test_studio_service.py test/test_studio_api.py
git commit -m "feat: add studio turn workflow"
```

---

## Task 5: Add Frontend API Types and Helpers

**Files:**
- Modify: `web/src/lib/api.ts`
- Create: `web/src/app/image/types.ts`
- Create: `web/src/app/image/lib.ts`

- [ ] **Step 1: Add studio API types**

In `web/src/lib/api.ts`, add:

```ts
export type StudioProject = {
  id: string;
  name: string;
  owner_id: string;
  archived: boolean;
  created_at: string;
  updated_at: string;
};

export type StudioConversation = {
  id: string;
  project_id: string;
  owner_id: string;
  title: string;
  mode: "generate" | "edit";
  created_at: string;
  updated_at: string;
};

export type StudioTurn = {
  id: string;
  conversation_id: string;
  owner_id: string;
  client_task_id: string;
  task_id: string;
  mode: "generate" | "edit";
  prompt: string;
  model: ImageModel | string;
  size?: string;
  reference_images: Array<{ name?: string; path?: string; url?: string }>;
  result_images: Array<{ path?: string; url?: string; b64_json?: string; revised_prompt?: string }>;
  status: "queued" | "running" | "success" | "error";
  error?: string;
  created_at: string;
  updated_at: string;
};

export type PromptTemplate = {
  id: string;
  name: string;
  category: string;
  content: string;
  builtin: boolean;
  owner_id?: string;
  created_at: string;
  updated_at: string;
};

export type ImageFavorite = {
  id: string;
  owner_id: string;
  image_path: string;
  source_turn_id?: string;
  note?: string;
  created_at: string;
};
```

- [ ] **Step 2: Add studio API functions**

In `web/src/lib/api.ts`, add:

```ts
export async function fetchStudioProjects() {
  return httpRequest<{ items: StudioProject[] }>("/api/projects");
}

export async function createStudioProject(name: string) {
  return httpRequest<{ item: StudioProject }>("/api/projects", {
    method: "POST",
    body: { name },
  });
}

export async function fetchStudioConversations(projectId: string) {
  const params = new URLSearchParams();
  params.set("project_id", projectId);
  return httpRequest<{ items: StudioConversation[] }>(`/api/image-conversations?${params.toString()}`);
}

export async function createStudioConversation(projectId: string, title: string, mode: "generate" | "edit") {
  return httpRequest<{ item: StudioConversation }>("/api/image-conversations", {
    method: "POST",
    body: { project_id: projectId, title, mode },
  });
}

export async function fetchStudioTurns(conversationId: string) {
  const params = new URLSearchParams();
  params.set("conversation_id", conversationId);
  return httpRequest<{ items: StudioTurn[] }>(`/api/image-turns?${params.toString()}`);
}

export async function createStudioGenerationTurn(conversationId: string, clientTaskId: string, prompt: string, model?: ImageModel, size?: string) {
  return httpRequest<{ item: StudioTurn }>("/api/image-turns/generations", {
    method: "POST",
    body: {
      conversation_id: conversationId,
      client_task_id: clientTaskId,
      prompt,
      ...(model ? { model } : {}),
      ...(size ? { size } : {}),
    },
  });
}

export async function syncStudioTurn(turnId: string) {
  return httpRequest<{ item: StudioTurn }>(`/api/image-turns/${turnId}/sync`, {
    method: "POST",
    body: {},
  });
}

export async function retryStudioTurn(turnId: string, clientTaskId: string) {
  return httpRequest<{ item: StudioTurn }>(`/api/image-turns/${turnId}/retry`, {
    method: "POST",
    body: { client_task_id: clientTaskId },
  });
}

export async function fetchPromptTemplates() {
  return httpRequest<{ items: PromptTemplate[] }>("/api/prompt-templates");
}

export async function fetchImageFavorites() {
  return httpRequest<{ items: ImageFavorite[] }>("/api/image-favorites");
}

export async function favoriteImage(imagePath: string, sourceTurnId = "") {
  return httpRequest<{ item: ImageFavorite }>("/api/image-favorites", {
    method: "POST",
    body: { image_path: imagePath, source_turn_id: sourceTurnId },
  });
}

export async function unfavoriteImage(favoriteId: string) {
  return httpRequest<{ ok: boolean }>(`/api/image-favorites/${favoriteId}`, {
    method: "DELETE",
  });
}
```

- [ ] **Step 3: Add UI types**

Create `web/src/app/image/types.ts`:

```ts
import type { ImageFavorite, PromptTemplate, StudioConversation, StudioProject, StudioTurn } from "@/lib/api";

export type StudioMode = "generate" | "edit";

export type ReferenceImageDraft = {
  id: string;
  name: string;
  file?: File;
  dataUrl?: string;
  url?: string;
  path?: string;
};

export type StudioState = {
  projects: StudioProject[];
  conversations: StudioConversation[];
  turns: StudioTurn[];
  templates: PromptTemplate[];
  favorites: ImageFavorite[];
  activeProjectId: string;
  activeConversationId: string;
  mode: StudioMode;
  prompt: string;
  model: string;
  size: string;
  count: string;
  references: ReferenceImageDraft[];
};
```

- [ ] **Step 4: Add pure helpers**

Create `web/src/app/image/lib.ts`:

```ts
import type { StudioTurn } from "@/lib/api";

export const ACTIVE_PROJECT_STORAGE_KEY = "chatgpt2api:image_active_project_id";
export const PROMPT_DRAFT_STORAGE_KEY = "chatgpt2api:image_prompt_draft";

export function createId(prefix = "client") {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export function buildConversationTitle(prompt: string) {
  const trimmed = prompt.trim();
  if (!trimmed) return "新的图片会话";
  return trimmed.length <= 18 ? trimmed : `${trimmed.slice(0, 18)}...`;
}

export function hasRunningTurns(turns: StudioTurn[]) {
  return turns.some((turn) => turn.status === "queued" || turn.status === "running");
}

export function resultImagePath(image: { path?: string; url?: string }) {
  if (image.path) return image.path;
  const marker = "/images/";
  if (image.url?.includes(marker)) return image.url.split(marker, 2)[1] || "";
  return "";
}

export function favoriteForPath(favorites: Array<{ id: string; image_path: string }>, path: string) {
  return favorites.find((favorite) => favorite.image_path === path) || null;
}
```

- [ ] **Step 5: Run frontend build**

Run: `cd web && bun run build`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add web/src/lib/api.ts web/src/app/image/types.ts web/src/app/image/lib.ts
git commit -m "feat: add studio frontend api helpers"
```

---

## Task 6: Refactor `/image` into Studio Components

**Files:**
- Create: `web/src/app/image/components/studio-shell.tsx`
- Create: `web/src/app/image/components/project-rail.tsx`
- Create: `web/src/app/image/components/studio-composer.tsx`
- Create: `web/src/app/image/components/studio-results.tsx`
- Create: `web/src/app/image/components/studio-inspector.tsx`
- Modify: `web/src/app/image/page.tsx`

- [ ] **Step 1: Create layout shell**

Create `web/src/app/image/components/studio-shell.tsx`:

```tsx
"use client";

import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

type StudioShellProps = {
  rail: ReactNode;
  main: ReactNode;
  inspector: ReactNode;
};

export function StudioShell({ rail, main, inspector }: StudioShellProps) {
  return (
    <section className="min-h-[calc(100vh-3rem)] bg-[#11100d] text-[#fff7e5]">
      <div className="grid min-h-[calc(100vh-3rem)] grid-cols-1 gap-4 p-3 lg:grid-cols-[260px_minmax(0,1fr)_320px] lg:p-6">
        <aside className={cn("rounded-[28px] border border-white/10 bg-white/[0.055] p-4 backdrop-blur")}>{rail}</aside>
        <main className="min-w-0 rounded-[28px] border border-white/10 bg-black/20 p-4 lg:p-6">{main}</main>
        <aside className="rounded-[28px] border border-white/10 bg-white/[0.065] p-4 backdrop-blur">{inspector}</aside>
      </div>
    </section>
  );
}
```

- [ ] **Step 2: Create project rail**

Create `web/src/app/image/components/project-rail.tsx`:

```tsx
"use client";

import { Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import type { StudioConversation, StudioProject } from "@/lib/api";
import { cn } from "@/lib/utils";

type ProjectRailProps = {
  projects: StudioProject[];
  conversations: StudioConversation[];
  activeProjectId: string;
  activeConversationId: string;
  onCreateProject: () => void;
  onSelectProject: (id: string) => void;
  onSelectConversation: (id: string) => void;
};

export function ProjectRail(props: ProjectRailProps) {
  return (
    <div className="flex h-full flex-col gap-6">
      <div>
        <p className="mb-3 text-[11px] font-bold uppercase tracking-[0.32em] text-stone-500">Projects</p>
        <div className="space-y-2">
          {props.projects.map((project) => (
            <button
              key={project.id}
              type="button"
              onClick={() => props.onSelectProject(project.id)}
              className={cn(
                "w-full rounded-2xl px-4 py-3 text-left text-sm transition",
                project.id === props.activeProjectId
                  ? "border border-lime-200/30 bg-lime-200/10 text-stone-50"
                  : "text-stone-300 hover:bg-white/10",
              )}
            >
              <span className="block font-semibold">{project.name}</span>
              <span className="text-xs text-stone-500">{new Date(project.updated_at).toLocaleString("zh-CN")}</span>
            </button>
          ))}
        </div>
      </div>
      <div className="min-h-0 flex-1">
        <p className="mb-3 text-[11px] font-bold uppercase tracking-[0.32em] text-stone-500">Recent Turns</p>
        <div className="space-y-2 overflow-y-auto">
          {props.conversations.map((conversation) => (
            <button
              key={conversation.id}
              type="button"
              onClick={() => props.onSelectConversation(conversation.id)}
              className={cn(
                "w-full rounded-2xl px-4 py-3 text-left text-sm transition",
                conversation.id === props.activeConversationId ? "bg-white/10 text-stone-50" : "text-stone-300 hover:bg-white/10",
              )}
            >
              <span className="block font-semibold">{conversation.title}</span>
              <span className="text-xs text-stone-500">{conversation.mode === "edit" ? "图生图" : "文生图"}</span>
            </button>
          ))}
        </div>
      </div>
      <Button type="button" variant="secondary" className="rounded-full" onClick={props.onCreateProject}>
        <Plus className="mr-2 size-4" />
        新建项目
      </Button>
    </div>
  );
}
```

- [ ] **Step 3: Create composer/results/inspector components**

Create `web/src/app/image/components/studio-composer.tsx`:

```tsx
"use client";

export function StudioComposer(props: {
  prompt: string;
  model: string;
  size: string;
  count: string;
  isSubmitting: boolean;
  onPromptChange: (value: string) => void;
  onModelChange: (value: string) => void;
  onSizeChange: (value: string) => void;
  onCountChange: (value: string) => void;
  onSubmit: () => void;
}) {
  return (
    <div className="rounded-[28px] border border-white/10 bg-white/[0.075] p-5">
      <div className="mb-3 text-[11px] font-bold uppercase tracking-[0.32em] text-stone-500">Prompt</div>
      <textarea
        value={props.prompt}
        onChange={(event) => props.onPromptChange(event.target.value)}
        className="min-h-24 w-full resize-none bg-transparent text-lg leading-8 text-stone-50 outline-none placeholder:text-stone-600"
        placeholder="描述你想生成的图片..."
      />
      <div className="mt-4 flex flex-wrap items-center gap-2">
        <input value={props.model} onChange={(event) => props.onModelChange(event.target.value)} className="rounded-full bg-black/40 px-4 py-2 text-sm" aria-label="模型" />
        <input value={props.size} onChange={(event) => props.onSizeChange(event.target.value)} className="rounded-full bg-black/40 px-4 py-2 text-sm" placeholder="尺寸" />
        <input value={props.count} onChange={(event) => props.onCountChange(event.target.value)} className="w-20 rounded-full bg-black/40 px-4 py-2 text-sm" aria-label="数量" />
        <button type="button" onClick={props.onSubmit} disabled={props.isSubmitting || !props.prompt.trim()} className="ml-auto rounded-full bg-lime-200 px-5 py-2 text-sm font-bold text-stone-950 disabled:opacity-50">
          {props.isSubmitting ? "生成中" : "生成"}
        </button>
      </div>
    </div>
  );
}
```

Create `web/src/app/image/components/studio-results.tsx`:

```tsx
"use client";

import { Heart, RefreshCw, WandSparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import type { StudioTurn } from "@/lib/api";
import { resultImagePath } from "@/app/image/lib";

export function StudioResults(props: {
  turns: StudioTurn[];
  favoritePaths: Set<string>;
  onFavorite: (turnId: string, path: string) => void;
  onContinueEdit: (url: string, path: string) => void;
  onRetry: (turnId: string) => void;
}) {
  if (props.turns.length === 0) {
    return <div className="rounded-[28px] border border-dashed border-white/15 p-10 text-center text-stone-400">输入提示词后，生成结果会出现在这里。</div>;
  }
  return (
    <div className="space-y-5">
      {props.turns.map((turn) => (
        <article key={turn.id} className="rounded-[28px] border border-white/10 bg-white/[0.045] p-4">
          <div className="mb-3 flex items-center justify-between gap-3">
            <div>
              <p className="text-sm font-semibold text-stone-100">{turn.prompt}</p>
              <p className="text-xs text-stone-500">{turn.status}</p>
            </div>
            {turn.status === "error" ? (
              <Button type="button" size="sm" variant="secondary" onClick={() => props.onRetry(turn.id)}>
                <RefreshCw className="mr-2 size-4" />
                重试
              </Button>
            ) : null}
          </div>
          <div className="grid gap-3 md:grid-cols-2">
            {turn.result_images.map((image, index) => {
              const path = resultImagePath(image);
              const url = image.url || (image.b64_json ? `data:image/png;base64,${image.b64_json}` : "");
              return (
                <div key={`${turn.id}-${index}`} className="overflow-hidden rounded-3xl bg-black/30">
                  {url ? <img src={url} alt={turn.prompt} className="aspect-square w-full object-cover" /> : <div className="aspect-square" />}
                  <div className="flex items-center justify-between gap-2 p-3">
                    <Button type="button" size="sm" variant="secondary" onClick={() => props.onFavorite(turn.id, path)} disabled={!path}>
                      <Heart className="mr-2 size-4" />
                      {props.favoritePaths.has(path) ? "已收藏" : "收藏"}
                    </Button>
                    <Button type="button" size="sm" onClick={() => props.onContinueEdit(url, path)} disabled={!url}>
                      <WandSparkles className="mr-2 size-4" />
                      继续编辑
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>
          {turn.error ? <p className="mt-3 text-sm text-red-300">{turn.error}</p> : null}
        </article>
      ))}
    </div>
  );
}
```

Create `web/src/app/image/components/studio-inspector.tsx`:

```tsx
"use client";

import type { PromptTemplate } from "@/lib/api";

export function StudioInspector(props: {
  templates: PromptTemplate[];
  quotaLabel: string;
  statusLabel: string;
  onInsertTemplate: (content: string) => void;
}) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-stone-50">生成设置</h2>
        <p className="mt-2 text-sm leading-6 text-stone-400">{props.statusLabel}</p>
      </div>
      <div>
        <p className="mb-3 text-[11px] font-bold uppercase tracking-[0.32em] text-stone-500">Prompt Templates</p>
        <div className="space-y-2">
          {props.templates.map((template) => (
            <button key={template.id} type="button" onClick={() => props.onInsertTemplate(template.content)} className="w-full rounded-full bg-white/10 px-4 py-2 text-left text-sm text-stone-100 hover:bg-white/15">
              {template.name}
            </button>
          ))}
        </div>
      </div>
      <div className="rounded-3xl bg-black/35 p-4">
        <p className="text-sm font-semibold text-stone-100">{props.quotaLabel}</p>
        <div className="mt-3 h-2 rounded-full bg-white/10">
          <div className="h-2 w-2/3 rounded-full bg-lime-200" />
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Rewrite `web/src/app/image/page.tsx` orchestration**

Replace the local conversation persistence path with server-backed loading:

```tsx
const [projects, setProjects] = useState<StudioProject[]>([]);
const [conversations, setConversations] = useState<StudioConversation[]>([]);
const [turns, setTurns] = useState<StudioTurn[]>([]);
const [templates, setTemplates] = useState<PromptTemplate[]>([]);
const [favorites, setFavorites] = useState<ImageFavorite[]>([]);
const [activeProjectId, setActiveProjectId] = useState("");
const [activeConversationId, setActiveConversationId] = useState("");
```

Use these actions:

```tsx
const loadInitialData = async () => {
  const [projectData, templateData, favoriteData] = await Promise.all([
    fetchStudioProjects(),
    fetchPromptTemplates(),
    fetchImageFavorites(),
  ]);
  let nextProjects = projectData.items;
  if (nextProjects.length === 0) {
    const created = await createStudioProject("默认项目");
    nextProjects = [created.item];
  }
  setProjects(nextProjects);
  setTemplates(templateData.items);
  setFavorites(favoriteData.items);
  setActiveProjectId(nextProjects[0]?.id || "");
};
```

When submitting:

```tsx
const ensureConversation = async () => {
  if (activeConversationId) return activeConversationId;
  const created = await createStudioConversation(activeProjectId, buildConversationTitle(prompt), "generate");
  setActiveConversationId(created.item.id);
  setConversations((current) => [created.item, ...current]);
  return created.item.id;
};

const handleSubmit = async () => {
  const conversationId = await ensureConversation();
  const created = await createStudioGenerationTurn(conversationId, createId("task"), prompt, model as ImageModel, size || undefined);
  setTurns((current) => [...current, created.item]);
};
```

Add polling for running turns with `syncStudioTurn(turn.id)` every 2 seconds until no turn is queued/running.

- [ ] **Step 5: Build and fix TypeScript errors**

Run: `cd web && bun run build`

Expected: PASS. Fix import/type errors by editing only the new image studio files and `web/src/lib/api.ts`.

- [ ] **Step 6: Commit**

```bash
git add web/src/app/image web/src/lib/api.ts
git commit -m "feat: build studio image workspace"
```

---

## Task 7: Add Favorites and Reuse to Image Manager

**Files:**
- Modify: `api/system.py`
- Modify: `web/src/lib/api.ts`
- Modify: `web/src/app/image-manager/page.tsx`
- Modify: `test/test_studio_api.py`

- [ ] **Step 1: Add API test for favorite list endpoint**

In `test/test_studio_api.py`, add:

```python
    def test_list_favorites(self):
        self.fake_service.favorites.append({"id": "favorite-1", "owner_id": "admin", "image_path": "2026/05/image.png"})

        response = self.client.get("/api/image-favorites", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["items"][0]["image_path"], "2026/05/image.png")
```

- [ ] **Step 2: Run the favorite endpoint test**

Run: `uv run python -m unittest test.test_studio_api.StudioApiTests.test_list_favorites -v`

Expected: PASS if Task 3 implemented `GET /api/image-favorites`; otherwise FAIL and add that route from Task 3.

- [ ] **Step 3: Add favorite state to `ManagedImage`**

In `web/src/lib/api.ts`, extend `ManagedImage`:

```ts
  favorite_id?: string | null;
  favorite?: boolean;
```

- [ ] **Step 4: Decorate image manager items client-side**

In `web/src/app/image-manager/page.tsx`, update `loadImages()` to fetch favorites:

```tsx
const [data, tagsData, favoriteData] = await Promise.all([
  fetchManagedImages({ start_date: startDate, end_date: endDate }),
  fetchImageTags(),
  fetchImageFavorites(),
]);
const favoriteByPath = new Map(favoriteData.items.map((item) => [item.image_path, item]));
setItems(data.items.map((item) => {
  const favorite = favoriteByPath.get(item.rel);
  return { ...item, favorite: Boolean(favorite), favorite_id: favorite?.id ?? null };
}));
```

- [ ] **Step 5: Add favorite toggle action**

Add handler in `ImageManagerContent`:

```tsx
const handleToggleFavorite = async (item: ManagedImage) => {
  try {
    if (item.favorite_id) {
      await unfavoriteImage(item.favorite_id);
      setItems((prev) => prev.map((image) => image.rel === item.rel ? { ...image, favorite: false, favorite_id: null } : image));
      toast.success("已取消收藏");
      return;
    }
    const result = await favoriteImage(item.rel);
    setItems((prev) => prev.map((image) => image.rel === item.rel ? { ...image, favorite: true, favorite_id: result.item.id } : image));
    toast.success("已收藏");
  } catch (error) {
    toast.error(error instanceof Error ? error.message : "收藏失败");
  }
};
```

Import `favoriteImage`, `unfavoriteImage`, and `fetchImageFavorites` from `@/lib/api`.

- [ ] **Step 6: Add visible favorite/reuse controls**

In each image card action area, add buttons:

```tsx
<Button type="button" size="sm" variant="secondary" onClick={() => void handleToggleFavorite(item)}>
  {item.favorite ? "取消收藏" : "收藏"}
</Button>
<Button type="button" size="sm" onClick={() => router.push(`/image?reuse=${encodeURIComponent(item.rel)}`)}>
  复用到图生图
</Button>
```

Import `useRouter` from `next/navigation` and initialize `const router = useRouter();`.

- [ ] **Step 7: Build frontend**

Run: `cd web && bun run build`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add web/src/lib/api.ts web/src/app/image-manager/page.tsx test/test_studio_api.py
git commit -m "feat: add image favorites in manager"
```

---

## Task 8: Add Local Draft Preservation and Migration Guard

**Files:**
- Modify: `web/src/app/image/page.tsx`
- Modify: `web/src/app/image/lib.ts`
- Modify: `web/src/store/image-conversations.ts`

- [ ] **Step 1: Add prompt draft helpers**

In `web/src/app/image/lib.ts`, add:

```ts
export function readPromptDraft() {
  if (typeof window === "undefined") return "";
  return window.localStorage.getItem(PROMPT_DRAFT_STORAGE_KEY) || "";
}

export function writePromptDraft(value: string) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(PROMPT_DRAFT_STORAGE_KEY, value);
}

export function clearPromptDraft() {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(PROMPT_DRAFT_STORAGE_KEY);
}
```

- [ ] **Step 2: Use prompt draft in page**

In `web/src/app/image/page.tsx`, initialize prompt from `readPromptDraft()` in a mount effect:

```tsx
useEffect(() => {
  setPrompt(readPromptDraft());
}, []);

useEffect(() => {
  writePromptDraft(prompt);
}, [prompt]);
```

After successful turn creation, call `clearPromptDraft()` only if the submitted prompt still matches the current prompt.

- [ ] **Step 3: Add local conversation migration guard**

Keep `web/src/store/image-conversations.ts` intact for now. Add a small banner in `page.tsx` if old local conversations exist:

```tsx
const stats = await getImageConversationStats();
setLegacyConversationCount(stats.count);
```

Render copy:

```tsx
{legacyConversationCount > 0 ? (
  <div className="rounded-2xl border border-amber-200/20 bg-amber-200/10 px-4 py-3 text-sm text-amber-50">
    检测到 {legacyConversationCount} 条旧版本地会话。本版本先保留本地数据，不自动迁移，避免误删。
  </div>
) : null}
```

- [ ] **Step 4: Build frontend**

Run: `cd web && bun run build`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/src/app/image/page.tsx web/src/app/image/lib.ts web/src/store/image-conversations.ts
git commit -m "feat: preserve studio prompt drafts"
```

---

## Task 9: End-to-End Verification

**Files:**
- Modify only files needed to fix defects found by verification.

- [ ] **Step 1: Run backend unit tests**

Run:

```bash
uv run python -m unittest \
  test.test_studio_service \
  test.test_studio_api \
  test.test_image_task_service \
  test.test_image_tasks_api \
  test.test_v1_images_generations \
  test.test_v1_images_edits \
  test.test_v1_models \
  -v
```

Expected: PASS.

- [ ] **Step 2: Run frontend build**

Run: `cd web && bun run build`

Expected: PASS.

- [ ] **Step 3: Run full test suite if targeted tests pass**

Run: `uv run python -m unittest discover -s test -v`

Expected: PASS. If tests fail because external credentials or live upstream behavior are required, record the exact failing test names and whether they are pre-existing integration requirements.

- [ ] **Step 4: Manual app smoke test**

Run backend:

```bash
uv run main.py
```

Run frontend in another terminal:

```bash
cd web && bun run dev
```

Open `http://localhost:3000/image` with Browser. Verify:

- Login works with the configured auth key.
- Default project is created when none exists.
- Prompt draft remains after a failed API request.
- Generation creates a turn and enters queued/running/success/error state.
- Favorite action updates UI.
- Continue editing from a result places the image in references.
- `/image-manager` shows favorite controls and "复用到图生图".
- 390px mobile width shows results, favorite, download, and continue editing.

- [ ] **Step 5: Commit verification fixes**

If verification required changes:

```bash
git add services api test web/src/lib/api.ts web/src/app/image web/src/app/image-manager/page.tsx web/src/store/image-conversations.ts
git commit -m "fix: stabilize internal image studio"
```

If no changes were needed, do not create an empty commit.

---

## Self-Review

Spec coverage:

- Three-column `/image` studio is covered by Task 6.
- Server-backed projects, conversations, turns, templates, and favorites are covered by Tasks 1 through 5.
- Existing image task reuse is covered by Task 4.
- Image manager favorites and reuse are covered by Task 7.
- Local draft preservation and old local data safety are covered by Task 8.
- Backend, frontend, regression, and manual verification are covered by Task 9.

Known implementation boundary:

- Edit retry is intentionally limited in Task 4 because uploaded reference file bytes are not persisted in the first MVP. Generation retry is fully supported; edit retry returns a clear 400 error unless the frontend resubmits references.
