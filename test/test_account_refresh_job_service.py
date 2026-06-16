from __future__ import annotations

import unittest
from typing import Any

from services.account_refresh_job_service import AccountRefreshJobService


class FakeAccountService:
    def __init__(self) -> None:
        self.saved = 0
        self.fetched: list[str] = []
        self.defer_invalid_removal_values: list[bool] = []

    def fetch_remote_info(
        self,
        access_token: str,
        event: str = "fetch_remote_info",
        defer_invalid_removal: bool = True,
    ) -> dict[str, Any]:
        self.fetched.append(access_token)
        self.defer_invalid_removal_values.append(defer_invalid_removal)
        return {
            "access_token": access_token,
            "event": event,
            "defer_invalid_removal": defer_invalid_removal,
        }

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
        self.assertEqual(account_service.defer_invalid_removal_values, [False, False])
        self.assertEqual(account_service.saved, 1)

    def test_refresh_batch_marks_invalid_tokens_immediately(self) -> None:
        account_service = FakeAccountService()
        job_service = AccountRefreshJobService(account_service, batch_size=2, max_workers=2)

        result = job_service._refresh_batch(["tok-a"])

        self.assertEqual(result["refreshed"], 1)
        self.assertEqual(result["errors"], [])
        self.assertEqual(account_service.defer_invalid_removal_values, [False])


if __name__ == "__main__":
    unittest.main()
