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
        self.turns = [
            {
                "id": "turn-1",
                "conversation_id": "conversation-1",
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

    def add_favorite(self, identity, image_path, source_turn_id="", note=""):
        item = {"id": "favorite-1", "owner_id": identity["id"], "image_path": image_path, "source_turn_id": source_turn_id, "note": note}
        self.favorites.append(item)
        return item

    def list_turns(self, identity, conversation_id):
        return [item for item in self.turns if item.get("conversation_id") == conversation_id]

    def create_turn(self, identity, conversation_id, **values):
        if conversation_id != "conversation-1":
            raise ValueError("conversation not found")
        item = {"id": f"turn-{len(self.created_turns) + 1}", "conversation_id": conversation_id, **values}
        self.created_turns.append(item)
        self.turns.append(item)
        return item

    def create_queued_turn(self, identity, conversation_id, **values):
        if not str(values.get("client_task_id") or "").strip():
            raise ValueError("client_task_id is required")
        for item in self.turns:
            if item.get("conversation_id") == conversation_id and item.get("client_task_id") == values.get("client_task_id"):
                return item
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
        self.tasks = {
            "task-1": {"id": "task-1", "status": "success", "data": [{"url": "http://testserver/images/2026/05/cat.png"}]},
            "task-2": {"id": "task-2", "status": "queued"},
        }

    def submit_generation(self, identity, *, client_task_id, prompt, model, size, base_url):
        self._validate_client_task_id(client_task_id)
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
        task = {"id": client_task_id, "status": "queued"}
        self.tasks[client_task_id] = task
        return task

    def submit_edit(self, identity, *, client_task_id, prompt, model, size, base_url, images):
        self._validate_client_task_id(client_task_id)
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
        task = {"id": client_task_id, "status": "queued"}
        self.tasks[client_task_id] = task
        return task

    def get_task(self, identity, task_id):
        return self.tasks.get(task_id)

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


if __name__ == "__main__":
    unittest.main()
