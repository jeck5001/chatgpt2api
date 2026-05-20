from __future__ import annotations

import os
import unittest

os.environ.setdefault("CHATGPT2API_AUTH_KEY", "chatgpt2api")

from api import support


class AccountWatcherSupportTests(unittest.TestCase):
    def test_refresh_interval_seconds_reads_latest_config_value(self) -> None:
        class DynamicConfig:
            def __init__(self) -> None:
                self.value = 3

            @property
            def refresh_account_interval_minute(self) -> int:
                return self.value

        dynamic_config = DynamicConfig()
        original_config = support.config
        try:
            support.config = dynamic_config

            self.assertEqual(support._account_refresh_interval_seconds(), 180)
            dynamic_config.value = 7
            self.assertEqual(support._account_refresh_interval_seconds(), 420)
        finally:
            support.config = original_config


if __name__ == "__main__":
    unittest.main()
