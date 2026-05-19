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

    def test_list_page_paginates_with_total_and_has_more(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {
                        "id": f"log-{i}",
                        "type": "call",
                        "time": f"2026-05-{i:02d} 10:00:00",
                        "summary": f"调用 {i}",
                        "detail": {"key_id": f"k{i}"},
                    }
                    for i in range(1, 11)
                ],
            )

            service = LogService(path)
            page_one = service.list_page(page=1, page_size=4)

            self.assertEqual(page_one["total"], 10)
            self.assertEqual(page_one["page"], 1)
            self.assertEqual(page_one["page_size"], 4)
            self.assertTrue(page_one["has_more"])
            self.assertEqual(len(page_one["items"]), 4)
            # newest-first ordering: log-10 leads
            self.assertEqual(page_one["items"][0]["id"], "log-10")
            self.assertEqual(page_one["items"][-1]["id"], "log-7")

            page_three = service.list_page(page=3, page_size=4)
            self.assertEqual(len(page_three["items"]), 2)
            self.assertFalse(page_three["has_more"])
            self.assertEqual(page_three["items"][0]["id"], "log-2")

    def test_list_page_filters_by_q_in_summary(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {"id": "a", "type": "call", "summary": "文生图调用完成", "detail": {}},
                    {"id": "b", "type": "call", "summary": "图生图调用完成", "detail": {}},
                    {"id": "c", "type": "call", "summary": "调用失败", "detail": {"error": "timeout"}},
                ],
            )

            service = LogService(path)
            result = service.list_page(q="失败")

            self.assertEqual(result["total"], 1)
            self.assertEqual(result["items"][0]["id"], "c")

    def test_list_page_filters_by_q_in_detail(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {"id": "a", "type": "call", "summary": "调用完成", "detail": {"key_id": "alpha"}},
                    {"id": "b", "type": "call", "summary": "调用完成", "detail": {"key_id": "beta"}},
                ],
            )

            service = LogService(path)
            result = service.list_page(q="alpha")

            self.assertEqual(result["total"], 1)
            self.assertEqual(result["items"][0]["id"], "a")

    def test_list_page_combines_q_with_type_filter(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {"id": "a", "type": "call", "summary": "失败", "detail": {}},
                    {"id": "b", "type": "account", "summary": "登录失败", "detail": {}},
                ],
            )

            service = LogService(path)
            result = service.list_page(type="account", q="失败")

            self.assertEqual(result["total"], 1)
            self.assertEqual(result["items"][0]["id"], "b")

    def test_list_page_returns_empty_envelope_for_missing_file(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            service = LogService(path)

            result = service.list_page(page=2, page_size=10)

            self.assertEqual(result, {
                "items": [],
                "total": 0,
                "page": 2,
                "page_size": 10,
                "has_more": False,
            })

    def test_delete_by_filter_removes_matching_entries(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {"id": "a", "type": "call", "time": "2026-05-10 10:00:00", "summary": "调用完成", "detail": {}},
                    {"id": "b", "type": "call", "time": "2026-05-12 10:00:00", "summary": "调用失败", "detail": {"error": "boom"}},
                    {"id": "c", "type": "account", "time": "2026-05-12 11:00:00", "summary": "登录", "detail": {}},
                    {"id": "d", "type": "call", "time": "2026-05-15 10:00:00", "summary": "调用完成", "detail": {}},
                ],
            )

            service = LogService(path)
            result = service.delete_by_filter(type="call", start_date="2026-05-11", end_date="2026-05-13")

            self.assertEqual(result, {"removed": 1})
            remaining_ids = [item["id"] for item in service.list()]
            # newest-first order from list(): d, c, a (b removed)
            self.assertEqual(remaining_ids, ["d", "c", "a"])

    def test_delete_by_filter_with_q_matches_summary_and_detail(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {"id": "a", "type": "call", "summary": "调用完成", "detail": {"key_id": "alpha"}},
                    {"id": "b", "type": "call", "summary": "调用失败", "detail": {"error": "boom"}},
                    {"id": "c", "type": "call", "summary": "调用完成", "detail": {"key_id": "beta失败"}},
                ],
            )

            service = LogService(path)
            result = service.delete_by_filter(q="失败")

            self.assertEqual(result, {"removed": 2})
            remaining_ids = [item["id"] for item in service.list()]
            self.assertEqual(remaining_ids, ["a"])

    def test_delete_by_filter_empty_payload_clears_all(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            _write_lines(
                path,
                [
                    {"id": "a", "type": "call", "summary": "调用完成", "detail": {}},
                    {"id": "b", "type": "account", "summary": "登录", "detail": {}},
                ],
            )

            service = LogService(path)
            result = service.delete_by_filter()

            self.assertEqual(result, {"removed": 2})
            self.assertEqual(service.list(), [])

    def test_delete_by_filter_is_noop_on_missing_file(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "logs.jsonl"
            service = LogService(path)

            self.assertEqual(service.delete_by_filter(q="anything"), {"removed": 0})


if __name__ == "__main__":
    unittest.main()
