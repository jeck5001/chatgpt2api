from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from services.log_service import LogService


def _write_lines(path: Path, items):
    path.write_text(
        "\n".join(json.dumps(item, ensure_ascii=False) for item in items) + "\n",
        encoding="utf-8",
    )


class LogServiceTests(unittest.TestCase):
    def test_delete_by_image_paths_drops_entries_referencing_those_paths(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {
                        "id": "log-1",
                        "type": "call",
                        "summary": "文生图调用完成",
                        "detail": {
                            "urls": [
                                "http://test/images/2026/05/cat.png",
                            ],
                        },
                    },
                    {
                        "id": "log-2",
                        "type": "call",
                        "summary": "文生图调用完成",
                        "detail": {
                            "urls": [
                                "http://test/images/2026/05/dog.png",
                            ],
                        },
                    },
                    {
                        "id": "log-3",
                        "type": "call",
                        "summary": "图生图调用完成",
                        "detail": {
                            "urls": [
                                "http://test/images/2026/05/cat.png?download=1",
                            ],
                        },
                    },
                ],
            )

            service = LogService(path)
            result = service.delete_by_image_paths(["2026/05/cat.png"])

            self.assertEqual(result, {"removed": 2})
            remaining_summaries = [item["summary"] for item in service.list()]
            self.assertEqual(remaining_summaries, ["文生图调用完成"])
            self.assertEqual(
                service.list()[0]["detail"]["urls"],
                ["http://test/images/2026/05/dog.png"],
            )

    def test_delete_by_image_paths_is_noop_with_no_matches(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            entry = {
                "id": "log-1",
                "type": "call",
                "summary": "文生图调用完成",
                "detail": {"urls": ["http://test/images/2026/05/cat.png"]},
            }
            _write_lines(path, [entry])

            service = LogService(path)
            result = service.delete_by_image_paths(["2026/05/dog.png"])

            self.assertEqual(result, {"removed": 0})
            self.assertEqual(len(service.list()), 1)

    def test_delete_by_image_paths_ignores_empty_and_missing_file(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            service = LogService(path)

            self.assertEqual(
                service.delete_by_image_paths(["2026/05/cat.png"]),
                {"removed": 0},
            )

            _write_lines(
                path,
                [
                    {
                        "id": "log-1",
                        "type": "call",
                        "summary": "文生图调用完成",
                        "detail": {"urls": ["http://test/images/2026/05/cat.png"]},
                    }
                ],
            )

            self.assertEqual(
                service.delete_by_image_paths([" ", ""]),
                {"removed": 0},
            )
            self.assertEqual(len(service.list()), 1)

    def test_delete_by_image_paths_skips_entries_without_url_list(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {
                        "id": "log-1",
                        "type": "call",
                        "summary": "文生图调用失败",
                        "detail": {"error": "boom"},
                    },
                    {
                        "id": "log-2",
                        "type": "account",
                        "summary": "登录",
                        "detail": {},
                    },
                ],
            )

            service = LogService(path)
            result = service.delete_by_image_paths(["2026/05/cat.png"])

            self.assertEqual(result, {"removed": 0})
            self.assertEqual(len(service.list()), 2)


if __name__ == "__main__":
    unittest.main()
