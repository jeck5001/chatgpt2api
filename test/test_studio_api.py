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
        self.recipes = []
        self.turns = [
            {
                "id": "turn-1",
                "conversation_id": "conversation-1",
                "owner_id": "admin",
                "task_id": "task-1",
                "mode": "generate",
                "status": "success",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "",
            }
        ]
        self.project_updates = []
        self.template_updates = []
        self.created_turns = []
        self.synced = []
        self.retried = []
        self.marked_errors = []
        self.deleted_conversations = []
        self.deleted_turns = []
        self.delete_conversation_result = True
        self.delete_turn_result = True

    def list_projects(self, identity):
        return self.projects

    def create_project(self, identity, name):
        item = {"id": "project-1", "name": name, "owner_id": identity["id"], "archived": False}
        self.projects.append(item)
        return item

    def update_project(self, identity, project_id, updates):
        self.project_updates.append((identity, project_id, updates))
        return {"id": project_id, "name": "Spring", "owner_id": identity["id"], "archived": True}

    def list_prompt_templates(self, identity):
        return [{"id": "template-1", "name": "商业摄影 / 产品", "content": "product photo"}]

    def create_prompt_template(self, identity, name, category, content):
        return {"id": "template-2", "name": name, "category": category, "content": content, "owner_id": identity["id"]}

    def update_prompt_template(self, identity, template_id, updates):
        self.template_updates.append((identity, template_id, updates))
        return {"id": template_id, "name": "Template", "category": "Custom", "content": "product photo", "owner_id": identity["id"]}

    def list_recipes(self, identity):
        return self.recipes

    def create_recipe(
        self,
        identity,
        *,
        name,
        prompt,
        model,
        size=None,
        source_image_path="",
        source_turn_id="",
        project_id="",
        tags=None,
    ):
        item = {
            "id": f"recipe-{len(self.recipes) + 1}",
            "owner_id": identity["id"],
            "name": name,
            "prompt": prompt,
            "model": model,
            "size": size,
            "source_image_path": source_image_path,
            "source_turn_id": source_turn_id,
            "project_id": project_id,
            "tags": tags or [],
        }
        self.recipes.append(item)
        return item

    def delete_recipe(self, identity, recipe_id):
        before = len(self.recipes)
        self.recipes = [item for item in self.recipes if item["id"] != recipe_id]
        return len(self.recipes) != before

    def add_favorite(self, identity, image_path, source_turn_id="", note=""):
        item = {"id": "favorite-1", "owner_id": identity["id"], "image_path": image_path, "source_turn_id": source_turn_id, "note": note}
        self.favorites.append(item)
        return item

    def list_turns(self, identity, conversation_id):
        return [item for item in self.turns if item.get("conversation_id") == conversation_id]

    def delete_conversation(self, identity, conversation_id, *, purge_images=False):
        self.deleted_conversations.append((identity, conversation_id, purge_images))
        return self.delete_conversation_result

    def delete_turn(self, identity, turn_id, *, purge_images=False):
        self.deleted_turns.append((identity, turn_id, purge_images))
        return self.delete_turn_result

    def create_turn(self, identity, conversation_id, **values):
        if conversation_id not in {"conversation-1", "conversation-2"}:
            raise ValueError("conversation not found")
        values.setdefault("owner_id", identity["id"])
        item = {"id": f"turn-{len(self.turns) + 1}", "conversation_id": conversation_id, **values}
        self.created_turns.append(item)
        self.turns.append(item)
        return item

    def create_queued_turn(self, identity, conversation_id, **values):
        if not str(values.get("client_task_id") or "").strip():
            raise ValueError("client_task_id is required")
        for item in self.turns:
            if item.get("owner_id") == identity["id"] and item.get("client_task_id") == values.get("client_task_id"):
                if item.get("conversation_id") == conversation_id:
                    return item
                raise ValueError("client_task_id is already used by another turn")
        return self.create_turn(identity, conversation_id, status="queued", result_images=[], error="", **values)

    def get_turn(self, identity, turn_id):
        for item in self.turns:
            if item["id"] == turn_id:
                return item
        return None

    def sync_turn_from_task(self, identity, turn_id, task):
        self.synced.append((identity, turn_id, task))
        item = {"id": turn_id, "task_id": task["id"], "status": task["status"], "mode": "generate"}
        if turn_id == "turn-edit":
            item["mode"] = "edit"
        return item

    def mark_turn_error(self, identity, turn_id, error, *, task_id=None):
        self.marked_errors.append((identity, turn_id, error, task_id))
        turn = self.get_turn(identity, turn_id)
        if turn is None:
            return None
        if task_id is not None:
            turn["task_id"] = task_id
        turn["status"] = "error"
        turn["error"] = error
        turn["result_images"] = []
        return turn

    def mark_turn_retrying(self, identity, turn_id, client_task_id):
        if not str(client_task_id or "").strip():
            raise ValueError("client_task_id is required")
        self.retried.append((identity, turn_id, client_task_id))
        turn = self.get_turn(identity, turn_id)
        if turn is None:
            return None
        if turn.get("mode") == "edit":
            raise ValueError("edit retry is not supported because reference images are not persisted")
        if turn.get("status") != "error":
            raise ValueError("only error turns can be retried")
        if turn.get("client_task_id") == client_task_id:
            raise ValueError("retry client_task_id must be different from the current turn")
        for item in self.turns:
            if item is not turn and item.get("owner_id") == turn.get("owner_id") and item.get("client_task_id") == client_task_id:
                raise ValueError("client_task_id is already used by another turn")
        turn["client_task_id"] = client_task_id
        turn["task_id"] = client_task_id
        turn["status"] = "queued"
        turn["error"] = ""
        turn["result_images"] = []
        return turn


class FakeImageTaskService:
    def __init__(self):
        self.generations = []
        self.edits = []
        self.fail_generation_with = None
        self.fail_edit_with = None
        self.tasks = {
            "task-1": {"id": "task-1", "status": "success", "data": [{"url": "http://testserver/images/2026/05/cat.png"}]},
            "task-2": {"id": "task-2", "status": "queued"},
        }

    def submit_generation(self, identity, *, client_task_id, prompt, model, size, base_url):
        self._validate_client_task_id(client_task_id)
        if self.fail_generation_with is not None:
            raise self.fail_generation_with
        owner_id = identity["id"]
        self.generations.append(
            {
                "identity": identity,
                "client_task_id": client_task_id,
                "prompt": prompt,
                "model": model,
                "size": size,
                "base_url": base_url,
            }
        )
        task = {"id": client_task_id, "status": "queued", "owner_id": owner_id}
        self.tasks[(owner_id, client_task_id)] = task
        return task

    def submit_edit(self, identity, *, client_task_id, prompt, model, size, base_url, images):
        self._validate_client_task_id(client_task_id)
        if self.fail_edit_with is not None:
            raise self.fail_edit_with
        owner_id = identity["id"]
        self.edits.append(
            {
                "identity": identity,
                "client_task_id": client_task_id,
                "prompt": prompt,
                "model": model,
                "size": size,
                "base_url": base_url,
                "images": images,
            }
        )
        task = {"id": client_task_id, "status": "queued", "owner_id": owner_id}
        self.tasks[(owner_id, client_task_id)] = task
        return task

    def get_task(self, identity, task_id):
        return self.tasks.get((identity["id"], task_id)) or self.tasks.get(task_id)

    @staticmethod
    def _validate_client_task_id(client_task_id):
        if not str(client_task_id or "").strip():
            raise ValueError("client_task_id is required")


class StudioApiTests(unittest.TestCase):
    def setUp(self):
        self.fake_service = FakeStudioService()
        self.fake_image_task_service = FakeImageTaskService()
        self.service_patcher = mock.patch.object(studio_module, "studio_service", self.fake_service)
        self.image_task_service_patcher = mock.patch.object(
            studio_module,
            "image_task_service",
            self.fake_image_task_service,
            create=True,
        )
        self.service_patcher.start()
        self.image_task_service_patcher.start()
        self.addCleanup(self.service_patcher.stop)
        self.addCleanup(self.image_task_service_patcher.stop)
        app = FastAPI()
        app.include_router(studio_module.create_router())
        self.client = TestClient(app)

    def test_create_project(self):
        response = self.client.post("/api/projects", headers=AUTH_HEADERS, json={"name": "Spring"})

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["item"]["name"], "Spring")

    def test_create_project_allows_empty_name(self):
        response = self.client.post("/api/projects", headers=AUTH_HEADERS, json={"name": ""})

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["item"]["name"], "")

    def test_update_project_ignores_null_archived(self):
        response = self.client.patch("/api/projects/project-1", headers=AUTH_HEADERS, json={"archived": None})

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(len(self.fake_service.project_updates), 1)
        self.assertNotIn("archived", self.fake_service.project_updates[0][2])

    def test_list_prompt_templates(self):
        response = self.client.get("/api/prompt-templates", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["items"][0]["id"], "template-1")

    def test_create_prompt_template_allows_empty_name(self):
        response = self.client.post(
            "/api/prompt-templates",
            headers=AUTH_HEADERS,
            json={"name": "", "category": "Custom", "content": "product photo"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["item"]["name"], "")

    def test_image_recipe_endpoints_preserve_generation_settings(self):
        create_response = self.client.post(
            "/api/image-recipes",
            headers=AUTH_HEADERS,
            json={
                "name": "Orange recipe",
                "prompt": "orange product photo",
                "model": "gpt-image-2",
                "size": "1024x1792",
                "source_image_path": "2026/05/orange.png",
                "source_turn_id": "turn-1",
                "project_id": "project-1",
                "tags": ["海报"],
            },
        )

        self.assertEqual(create_response.status_code, 200, create_response.text)
        created = create_response.json()["item"]
        self.assertEqual(created["model"], "gpt-image-2")
        self.assertEqual(created["size"], "1024x1792")
        self.assertEqual(created["source_image_path"], "2026/05/orange.png")

        list_response = self.client.get("/api/image-recipes", headers=AUTH_HEADERS)
        self.assertEqual(list_response.status_code, 200, list_response.text)
        self.assertEqual(list_response.json()["items"][0]["id"], created["id"])

        delete_response = self.client.delete(f"/api/image-recipes/{created['id']}", headers=AUTH_HEADERS)
        self.assertEqual(delete_response.status_code, 200, delete_response.text)
        self.assertEqual(self.fake_service.recipes, [])

    def test_image_prompt_draft_endpoint_returns_described_prompt(self):
        with mock.patch.object(
            studio_module,
            "draft_prompt_from_images",
            create=True,
            return_value="cinematic product photo, warm rim light",
        ) as draft_prompt:
            response = self.client.post(
                "/api/image-prompt-drafts",
                headers=AUTH_HEADERS,
                files=[("image", ("reference.png", b"image-bytes", "image/png"))],
            )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(
            response.json()["item"]["draft_prompt"],
            "cinematic product photo, warm rim light",
        )
        images = draft_prompt.call_args.args[0]
        self.assertEqual(images, [(b"image-bytes", "reference.png", "image/png")])

    def test_image_prompt_draft_endpoint_requires_image(self):
        response = self.client.post(
            "/api/image-prompt-drafts",
            headers=AUTH_HEADERS,
        )

        self.assertEqual(response.status_code, 400, response.text)

    def test_prompt_optimization_endpoint_returns_polished_prompt(self):
        with mock.patch.object(
            studio_module,
            "optimize_image_prompt",
            create=True,
            return_value="A cinematic cyberpunk cat portrait with neon rim light",
        ) as optimize_prompt:
            response = self.client.post(
                "/api/prompt-optimizations",
                headers=AUTH_HEADERS,
                json={"prompt": "一只赛博朋克的猫"},
            )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(
            response.json()["item"]["optimized_prompt"],
            "A cinematic cyberpunk cat portrait with neon rim light",
        )
        optimize_prompt.assert_called_once_with("一只赛博朋克的猫")

    def test_prompt_optimization_endpoint_requires_prompt(self):
        response = self.client.post(
            "/api/prompt-optimizations",
            headers=AUTH_HEADERS,
            json={"prompt": "   "},
        )

        self.assertEqual(response.status_code, 422, response.text)

    def test_update_prompt_template_ignores_null_content(self):
        response = self.client.patch("/api/prompt-templates/template-1", headers=AUTH_HEADERS, json={"content": None})

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(len(self.fake_service.template_updates), 1)
        self.assertNotIn("content", self.fake_service.template_updates[0][2])

    def test_add_favorite(self):
        response = self.client.post(
            "/api/image-favorites",
            headers=AUTH_HEADERS,
            json={"image_path": "2026/05/image.png", "source_turn_id": "turn-1"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["item"]["image_path"], "2026/05/image.png")

    def test_delete_conversation_returns_ok(self):
        response = self.client.delete(
            "/api/image-conversations/conversation-1", headers=AUTH_HEADERS
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json(), {"ok": True})
        self.assertEqual(self.fake_service.deleted_conversations[0][1], "conversation-1")
        self.assertFalse(self.fake_service.deleted_conversations[0][2])

    def test_delete_conversation_passes_purge_flag(self):
        response = self.client.delete(
            "/api/image-conversations/conversation-1?purge=true", headers=AUTH_HEADERS
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertTrue(self.fake_service.deleted_conversations[0][2])

    def test_delete_conversation_returns_404_when_missing(self):
        self.fake_service.delete_conversation_result = False
        response = self.client.delete(
            "/api/image-conversations/conversation-missing", headers=AUTH_HEADERS
        )

        self.assertEqual(response.status_code, 404, response.text)

    def test_delete_image_turn_returns_ok(self):
        response = self.client.delete("/api/image-turns/turn-1", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json(), {"ok": True})
        self.assertEqual(self.fake_service.deleted_turns[0][1], "turn-1")
        self.assertFalse(self.fake_service.deleted_turns[0][2])

    def test_delete_image_turn_passes_purge_flag(self):
        response = self.client.delete(
            "/api/image-turns/turn-1?purge=true", headers=AUTH_HEADERS
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertTrue(self.fake_service.deleted_turns[0][2])

    def test_delete_image_turn_returns_404_when_missing(self):
        self.fake_service.delete_turn_result = False
        response = self.client.delete("/api/image-turns/turn-missing", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 404, response.text)

    def test_create_generation_turn_submits_task_and_syncs(self):
        response = self.client.post(
            "/api/image-turns/generations",
            headers=AUTH_HEADERS,
            json={
                "conversation_id": "conversation-1",
                "client_task_id": "task-new",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(self.fake_image_task_service.generations[0]["client_task_id"], "task-new")
        self.assertEqual(self.fake_service.created_turns[0]["prompt"], "cat")
        self.assertEqual(self.fake_service.created_turns[0]["mode"], "generate")
        self.assertEqual(self.fake_service.synced[0][2]["id"], "task-new")
        self.assertEqual(response.json()["item"]["id"], self.fake_service.synced[0][1])

    def test_create_generation_turn_with_bad_conversation_does_not_submit_task(self):
        response = self.client.post(
            "/api/image-turns/generations",
            headers=AUTH_HEADERS,
            json={
                "conversation_id": "missing-conversation",
                "client_task_id": "task-new",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_image_task_service.generations, [])

    def test_create_generation_turn_with_blank_client_task_id_does_not_persist_or_submit(self):
        response = self.client.post(
            "/api/image-turns/generations",
            headers=AUTH_HEADERS,
            json={
                "conversation_id": "conversation-1",
                "client_task_id": "   ",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_service.created_turns, [])
        self.assertEqual(self.fake_image_task_service.generations, [])

    def test_create_generation_turn_marks_turn_error_when_task_submit_fails(self):
        self.fake_image_task_service.fail_generation_with = ValueError("submit failed")

        response = self.client.post(
            "/api/image-turns/generations",
            headers=AUTH_HEADERS,
            json={
                "conversation_id": "conversation-1",
                "client_task_id": "task-fail",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(len(self.fake_service.created_turns), 1)
        self.assertEqual(self.fake_service.created_turns[0]["status"], "error")
        self.assertEqual(self.fake_service.created_turns[0]["error"], "submit failed")

    def test_duplicate_generation_turn_reuses_existing_turn(self):
        body = {
            "conversation_id": "conversation-1",
            "client_task_id": "task-duplicate",
            "prompt": "cat",
            "model": "gpt-image-2",
            "size": "1024x1024",
        }

        first = self.client.post("/api/image-turns/generations", headers=AUTH_HEADERS, json=body)
        second = self.client.post("/api/image-turns/generations", headers=AUTH_HEADERS, json=body)

        self.assertEqual(first.status_code, 200, first.text)
        self.assertEqual(second.status_code, 200, second.text)
        self.assertEqual(first.json()["item"]["id"], second.json()["item"]["id"])
        self.assertEqual(len(self.fake_service.created_turns), 1)

    def test_generation_turn_rejects_client_task_id_used_in_other_conversation(self):
        self.fake_service.turns.append(
            {
                "id": "turn-existing",
                "conversation_id": "conversation-1",
                "owner_id": "admin",
                "client_task_id": "task-duplicate",
                "task_id": "task-duplicate",
                "mode": "generate",
                "status": "queued",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "",
            }
        )

        response = self.client.post(
            "/api/image-turns/generations",
            headers=AUTH_HEADERS,
            json={
                "conversation_id": "conversation-2",
                "client_task_id": "task-duplicate",
                "prompt": "dog",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_service.created_turns, [])
        self.assertEqual(self.fake_image_task_service.generations, [])

    def test_list_image_turns_returns_items(self):
        response = self.client.get(
            "/api/image-turns",
            headers=AUTH_HEADERS,
            params={"conversation_id": "conversation-1"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["items"][0]["id"], "turn-1")

    def test_sync_image_turn_returns_synced_item(self):
        response = self.client.post("/api/image-turns/turn-1/sync", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(self.fake_service.synced[0][1], "turn-1")
        self.assertEqual(response.json()["item"]["task_id"], "task-1")

    def test_admin_sync_uses_turn_owner_for_task_lookup(self):
        self.fake_service.turns.append(
            {
                "id": "turn-user",
                "conversation_id": "conversation-1",
                "owner_id": "owner-1",
                "task_id": "user-task",
                "mode": "generate",
                "status": "queued",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "",
            }
        )
        self.fake_image_task_service.tasks[("owner-1", "user-task")] = {"id": "user-task", "status": "success"}

        response = self.client.post("/api/image-turns/turn-user/sync", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(self.fake_service.synced[0][2]["id"], "user-task")

    def test_create_edit_turn_accepts_multiple_images_and_reference_metadata(self):
        response = self.client.post(
            "/api/image-turns/edits",
            headers=AUTH_HEADERS,
            data={
                "conversation_id": "conversation-1",
                "client_task_id": "task-edit",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
            files=[
                ("image", ("first.png", b"first", "image/png")),
                ("image[]", ("second.jpg", b"second", "image/jpeg")),
            ],
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual([image[1] for image in self.fake_image_task_service.edits[0]["images"]], ["first.png", "second.jpg"])
        self.assertEqual(
            self.fake_service.created_turns[0]["reference_images"],
            [{"filename": "first.png", "content_type": "image/png"}, {"filename": "second.jpg", "content_type": "image/jpeg"}],
        )
        self.assertEqual(self.fake_service.created_turns[0]["mode"], "edit")

    def test_create_edit_turn_with_bad_conversation_does_not_submit_task(self):
        response = self.client.post(
            "/api/image-turns/edits",
            headers=AUTH_HEADERS,
            data={
                "conversation_id": "missing-conversation",
                "client_task_id": "task-edit",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
            files=[("image", ("first.png", b"first", "image/png"))],
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_image_task_service.edits, [])

    def test_create_edit_turn_with_blank_client_task_id_does_not_persist_or_submit(self):
        response = self.client.post(
            "/api/image-turns/edits",
            headers=AUTH_HEADERS,
            data={
                "conversation_id": "conversation-1",
                "client_task_id": "   ",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
            files=[("image", ("first.png", b"first", "image/png"))],
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_service.created_turns, [])
        self.assertEqual(self.fake_image_task_service.edits, [])

    def test_create_edit_turn_marks_turn_error_when_task_submit_fails(self):
        self.fake_image_task_service.fail_edit_with = ValueError("edit submit failed")

        response = self.client.post(
            "/api/image-turns/edits",
            headers=AUTH_HEADERS,
            data={
                "conversation_id": "conversation-1",
                "client_task_id": "task-edit-fail",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "1024x1024",
            },
            files=[("image", ("first.png", b"first", "image/png"))],
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(len(self.fake_service.created_turns), 1)
        self.assertEqual(self.fake_service.created_turns[0]["status"], "error")
        self.assertEqual(self.fake_service.created_turns[0]["error"], "edit submit failed")

    def test_retry_edit_turn_returns_bad_request(self):
        self.fake_service.turns.append(
            {
                "id": "turn-edit",
                "conversation_id": "conversation-1",
                "task_id": "task-edit",
                "mode": "edit",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "",
            }
        )

        response = self.client.post(
            "/api/image-turns/turn-edit/retry",
            headers=AUTH_HEADERS,
            json={"client_task_id": "task-retry"},
        )

        self.assertEqual(response.status_code, 400, response.text)

    def test_retry_non_error_turn_returns_bad_request_without_submit(self):
        for status in ("success", "queued", "running"):
            with self.subTest(status=status):
                self.setUp()
                self.fake_service.turns[0]["status"] = status

                response = self.client.post(
                    "/api/image-turns/turn-1/retry",
                    headers=AUTH_HEADERS,
                    json={"client_task_id": f"task-retry-{status}"},
                )

                self.assertEqual(response.status_code, 400, response.text)
                self.assertEqual(self.fake_image_task_service.generations, [])

    def test_retry_with_blank_client_task_id_does_not_mutate_or_submit(self):
        self.fake_service.turns[0]["status"] = "error"
        self.fake_service.turns[0]["error"] = "failed"
        original = dict(self.fake_service.turns[0])

        response = self.client.post(
            "/api/image-turns/turn-1/retry",
            headers=AUTH_HEADERS,
            json={"client_task_id": "   "},
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_service.turns[0], original)
        self.assertEqual(self.fake_image_task_service.generations, [])

    def test_retry_with_duplicate_client_task_id_returns_bad_request_without_submit(self):
        self.fake_service.turns[0]["owner_id"] = "admin"
        self.fake_service.turns[0]["client_task_id"] = "task-1"
        self.fake_service.turns.append(
            {
                "id": "turn-failed",
                "conversation_id": "conversation-1",
                "owner_id": "admin",
                "client_task_id": "task-2",
                "task_id": "task-2",
                "mode": "generate",
                "status": "error",
                "error": "failed",
                "prompt": "dog",
                "model": "gpt-image-2",
                "size": "",
            }
        )

        response = self.client.post(
            "/api/image-turns/turn-failed/retry",
            headers=AUTH_HEADERS,
            json={"client_task_id": "task-1"},
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_image_task_service.generations, [])
        self.assertEqual(self.fake_service.turns[-1]["status"], "error")
        self.assertEqual(self.fake_service.turns[-1]["task_id"], "task-2")

    def test_retry_with_same_current_client_task_id_returns_bad_request_without_submit(self):
        self.fake_service.turns[0]["status"] = "error"
        self.fake_service.turns[0]["error"] = "failed"
        self.fake_service.turns[0]["client_task_id"] = "task-1"

        response = self.client.post(
            "/api/image-turns/turn-1/retry",
            headers=AUTH_HEADERS,
            json={"client_task_id": "task-1"},
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_image_task_service.generations, [])
        self.assertEqual(self.fake_service.turns[0]["status"], "error")
        self.assertEqual(self.fake_service.turns[0]["task_id"], "task-1")

    def test_retry_marks_turn_error_when_task_submit_fails(self):
        self.fake_service.turns[0]["status"] = "error"
        self.fake_service.turns[0]["error"] = "failed"
        self.fake_image_task_service.fail_generation_with = ValueError("retry submit failed")

        response = self.client.post(
            "/api/image-turns/turn-1/retry",
            headers=AUTH_HEADERS,
            json={"client_task_id": "task-retry-fail"},
        )

        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.fake_service.turns[0]["status"], "error")
        self.assertEqual(self.fake_service.turns[0]["task_id"], "task-retry-fail")
        self.assertEqual(self.fake_service.turns[0]["error"], "retry submit failed")

    def test_admin_retry_submits_task_as_turn_owner(self):
        self.fake_service.turns.append(
            {
                "id": "turn-user",
                "conversation_id": "conversation-1",
                "owner_id": "owner-1",
                "task_id": "old-task",
                "mode": "generate",
                "status": "error",
                "error": "failed",
                "prompt": "cat",
                "model": "gpt-image-2",
                "size": "",
            }
        )

        response = self.client.post(
            "/api/image-turns/turn-user/retry",
            headers=AUTH_HEADERS,
            json={"client_task_id": "retry-user-task"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(self.fake_image_task_service.generations[0]["identity"]["id"], "owner-1")


if __name__ == "__main__":
    unittest.main()
