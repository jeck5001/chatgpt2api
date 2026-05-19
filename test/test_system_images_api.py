from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest import mock

from fastapi import FastAPI
from fastapi.testclient import TestClient

import api.system as system_module


AUTH_HEADERS = {"Authorization": "Bearer chatgpt2api"}


class SystemImagesApiTests(unittest.TestCase):
    def setUp(self):
        self.fake_studio_service = SimpleNamespace(
            image_asset_metadata_index=lambda identity: {
                "2026/05/19/orange.png": {
                    "prompt": "orange product photo",
                    "model": "gpt-image-2",
                }
            }
        )
        self.list_images_patch = mock.patch.object(
            system_module,
            "list_images",
            return_value={"items": [], "groups": []},
        )
        self.studio_service_patch = mock.patch.object(
            system_module,
            "studio_service",
            self.fake_studio_service,
        )
        self.list_images = self.list_images_patch.start()
        self.studio_service_patch.start()
        self.addCleanup(self.list_images_patch.stop)
        self.addCleanup(self.studio_service_patch.stop)
        app = FastAPI()
        app.include_router(system_module.create_router("0.1.0-test"))
        self.client = TestClient(app)

    def test_get_images_uses_studio_metadata_index(self):
        response = self.client.get("/api/images", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(
            self.list_images.call_args.kwargs["metadata_by_path"],
            {
                "2026/05/19/orange.png": {
                    "prompt": "orange product photo",
                    "model": "gpt-image-2",
                }
            },
        )


if __name__ == "__main__":
    unittest.main()
