from __future__ import annotations

import unittest

from fastapi import FastAPI
from fastapi.testclient import TestClient

from api import system as system_module


AUTH_HEADERS = {"Authorization": "Bearer chatgpt2api"}


class AppBootstrapApiTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(system_module.create_router("0.1.0-test"))
        self.client = TestClient(app)

    def test_bootstrap_returns_identity_and_capabilities(self):
        response = self.client.get("/api/app/bootstrap", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertEqual(payload["version"], "0.1.0-test")
        self.assertEqual(payload["identity"]["role"], "admin")
        self.assertIn("studio", payload["capabilities"])
        self.assertIn("image_generation", payload["capabilities"])

    def test_bootstrap_rejects_missing_auth(self):
        response = self.client.get("/api/app/bootstrap")

        self.assertEqual(response.status_code, 401)


if __name__ == "__main__":
    unittest.main()
