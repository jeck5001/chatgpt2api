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
