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
        self.project_updates = []
        self.template_updates = []

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


if __name__ == "__main__":
    unittest.main()
