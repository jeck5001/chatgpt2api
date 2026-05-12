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
