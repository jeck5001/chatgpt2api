from __future__ import annotations

import unittest
from typing import Any
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from api import accounts as accounts_module
from services.account_service import AccountService
from services.storage.base import StorageBackend


AUTH_HEADERS = {"Authorization": "Bearer chatgpt2api"}


class _StubStorage(StorageBackend):
    def __init__(self, accounts: list[dict[str, Any]] | None = None):
        self._accounts = list(accounts or [])

    def load_accounts(self) -> list[dict[str, Any]]:
        return [dict(item) for item in self._accounts]

    def save_accounts(self, accounts: list[dict[str, Any]]) -> None:
        self._accounts = [dict(item) for item in accounts]

    def load_auth_keys(self) -> list[dict[str, Any]]:
        return []

    def save_auth_keys(self, auth_keys: list[dict[str, Any]]) -> None:
        pass

    def load_studio_state(self) -> dict[str, Any]:
        return {}

    def save_studio_state(self, state: dict[str, Any]) -> None:
        pass

    def health_check(self) -> dict[str, Any]:
        return {"ok": True}

    def get_backend_info(self) -> dict[str, Any]:
        return {"backend": "stub"}


def _seed_account(
    token: str,
    *,
    email: str | None = None,
    type: str = "free",
    status: str = "正常",
    quota: int = 10,
    last_used_at: str | None = None,
) -> dict[str, Any]:
    return {
        "access_token": token,
        "email": email,
        "type": type,
        "status": status,
        "quota": quota,
        "last_used_at": last_used_at,
    }


class AccountsApiTests(unittest.TestCase):
    def setUp(self):
        seed = [
            _seed_account(
                "tok-a",
                email="a@example.com",
                quota=5,
                last_used_at="2026-05-12 10:00:00",
            ),
            _seed_account(
                "tok-b",
                email="b@example.com",
                quota=20,
                last_used_at="2026-05-13 10:00:00",
            ),
            _seed_account("tok-c", email="c@example.com", status="限流"),
            _seed_account("tok-d", email="d@example.com", status="异常"),
            _seed_account("tok-pro", email="pro@example.com", type="pro", quota=0),
            _seed_account("tok-unknown", email="u@example.com"),
        ]
        self._service = AccountService(_StubStorage(seed))
        self._patcher = patch.object(accounts_module, "account_service", self._service)
        self._patcher.start()

        app = FastAPI()
        app.include_router(accounts_module.create_router())
        self.client = TestClient(app)

    def tearDown(self):
        self._patcher.stop()

    def test_get_accounts_returns_envelope_with_summary(self):
        response = self.client.get("/api/accounts", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        data = response.json()
        self.assertEqual(data["total"], 6)
        self.assertEqual(data["page"], 1)
        self.assertEqual(data["page_size"], 50)
        self.assertFalse(data["has_more"])

        summary = data["summary"]
        self.assertEqual(summary["total"], 6)
        # 正常: tok-a, tok-b, tok-pro, tok-unknown
        self.assertEqual(summary["active"], 4)
        self.assertEqual(summary["limited"], 1)
        self.assertEqual(summary["abnormal"], 1)
        self.assertEqual(summary["disabled"], 0)
        self.assertFalse(summary["quota"]["has_unlimited"])
        self.assertFalse(summary["quota"]["has_unknown"])
        self.assertEqual(summary["quota"]["value"], 35)

    def test_get_accounts_filters_by_status(self):
        response = self.client.get("/api/accounts?status=限流", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        data = response.json()
        self.assertEqual(data["total"], 1)
        self.assertEqual(data["items"][0]["access_token"], "tok-c")
        # summary reflects the whole pool, not the filtered view
        self.assertEqual(data["summary"]["total"], 6)

    def test_get_accounts_filters_by_type(self):
        response = self.client.get("/api/accounts?type=pro", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        data = response.json()
        self.assertEqual(data["total"], 1)
        self.assertEqual(data["items"][0]["access_token"], "tok-pro")

    def test_get_accounts_filters_by_q_email_substring(self):
        response = self.client.get("/api/accounts?q=b@example", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        items = response.json()["items"]
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["access_token"], "tok-b")

    def test_get_accounts_filters_by_q_token_substring(self):
        response = self.client.get("/api/accounts?q=tok-c", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        items = response.json()["items"]
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["access_token"], "tok-c")

    def test_get_accounts_paginates_with_page_size(self):
        page_one = self.client.get(
            "/api/accounts?page=1&page_size=2",
            headers=AUTH_HEADERS,
        ).json()

        self.assertEqual(len(page_one["items"]), 2)
        self.assertEqual(page_one["page"], 1)
        self.assertEqual(page_one["page_size"], 2)
        self.assertEqual(page_one["total"], 6)
        self.assertTrue(page_one["has_more"])

        page_two = self.client.get(
            "/api/accounts?page=2&page_size=2",
            headers=AUTH_HEADERS,
        ).json()

        self.assertEqual(len(page_two["items"]), 2)
        self.assertTrue(page_two["has_more"])

        page_one_tokens = {item["access_token"] for item in page_one["items"]}
        page_two_tokens = {item["access_token"] for item in page_two["items"]}
        self.assertEqual(page_one_tokens & page_two_tokens, set())

    def test_get_accounts_sorts_newest_last_used_first(self):
        response = self.client.get("/api/accounts", headers=AUTH_HEADERS)

        tokens = [item["access_token"] for item in response.json()["items"]]
        # tok-b has the most recent last_used_at, tok-a is next; everyone else
        # has no last_used_at so they're tail-ordered by access_token ascending.
        self.assertEqual(tokens[0], "tok-b")
        self.assertEqual(tokens[1], "tok-a")
        self.assertEqual(tokens[2:], ["tok-c", "tok-d", "tok-pro", "tok-unknown"])

    def test_get_accounts_clamps_page_size_to_upper_bound(self):
        response = self.client.get(
            "/api/accounts?page_size=99999",
            headers=AUTH_HEADERS,
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["page_size"], 200)

    def test_delete_endpoint_no_longer_returns_items(self):
        response = self.client.request(
            "DELETE",
            "/api/accounts",
            headers=AUTH_HEADERS,
            json={"tokens": ["tok-a"]},
        )

        self.assertEqual(response.status_code, 200, response.text)
        data = response.json()
        self.assertEqual(data["removed"], 1)
        self.assertNotIn("items", data)

    def test_update_endpoint_no_longer_returns_items(self):
        response = self.client.post(
            "/api/accounts/update",
            headers=AUTH_HEADERS,
            json={"access_token": "tok-a", "status": "禁用"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        data = response.json()
        self.assertEqual(data["item"]["status"], "禁用")
        self.assertNotIn("items", data)

    def test_refresh_all_accounts_starts_background_job(self):
        with (
            patch.object(self._service, "refresh_accounts") as refresh_accounts,
            patch.object(self._service, "fetch_remote_info", return_value={"access_token": "tok-a"}),
        ):
            response = self.client.post(
                "/api/accounts/refresh",
                headers=AUTH_HEADERS,
                json={"access_tokens": []},
            )

        self.assertEqual(response.status_code, 200, response.text)
        data = response.json()
        self.assertEqual(data["mode"], "background")
        self.assertIn(data["status"], {"queued", "running", "success"})
        self.assertEqual(data["total"], 6)
        self.assertTrue(data["job_id"])
        refresh_accounts.assert_not_called()

        status_response = self.client.get(
            f"/api/accounts/refresh/{data['job_id']}",
            headers=AUTH_HEADERS,
        )
        self.assertEqual(status_response.status_code, 200, status_response.text)
        self.assertEqual(status_response.json()["job_id"], data["job_id"])

    def test_refresh_selected_accounts_stays_synchronous(self):
        response = self.client.post(
            "/api/accounts/refresh",
            headers=AUTH_HEADERS,
            json={"access_tokens": ["tok-a"]},
        )

        self.assertEqual(response.status_code, 200, response.text)
        data = response.json()
        self.assertNotIn("job_id", data)
        self.assertIn("refreshed", data)


if __name__ == "__main__":
    unittest.main()
