from __future__ import annotations

import unittest
from typing import Any

from services.account_refresh_job_service import AccountRefreshJobService


class FakeAccountService:
    def __init__(self) -> None:
        self.saved = 0
        self.fetched: list[str] = []
        self.immediate_invalid_values: list[bool] = []

    def fetch_remote_info(
        self,
        access_token: str,
        event: str = "fetch_remote_info",
        *,
        immediate_invalid: bool = False,
    ) -> dict[str, Any]:
        self.fetched.append(access_token)
        self.immediate_invalid_values.append(immediate_invalid)
        return {"access_token": access_token, "event": event, "immediate_invalid": immediate_invalid}

    def save_accounts_snapshot(self) -> None:
        self.saved += 1


class AccountRefreshJobServiceTests(unittest.TestCase):
    def test_refresh_batch_saves_once_per_batch(self) -> None:
        account_service = FakeAccountService()
        job_service = AccountRefreshJobService(account_service, batch_size=2, max_workers=2)

        result = job_service._refresh_batch(["tok-a", "tok-b"])

        self.assertEqual(result["refreshed"], 2)
        self.assertEqual(result["errors"], [])
        self.assertEqual(account_service.fetched, ["tok-a", "tok-b"])
        self.assertEqual(account_service.immediate_invalid_values, [True, True])
        self.assertEqual(account_service.saved, 1)

    def test_refresh_batch_marks_invalid_tokens_immediately(self) -> None:
        account_service = FakeAccountService()
        job_service = AccountRefreshJobService(account_service, batch_size=2, max_workers=2)

        result = job_service._refresh_batch(["tok-a"])

        self.assertEqual(result["refreshed"], 1)
        self.assertEqual(result["errors"], [])
        self.assertEqual(account_service.immediate_invalid_values, [True])


if __name__ == "__main__":
    unittest.main()
