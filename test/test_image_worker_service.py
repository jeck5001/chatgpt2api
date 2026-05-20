from __future__ import annotations

import tempfile
import time
import unittest
from pathlib import Path

from services.image_worker_service import ImageWorkerService


class ImageWorkerServiceTests(unittest.TestCase):
    def make_service(self, path: Path) -> ImageWorkerService:
        return ImageWorkerService(path, heartbeat_timeout_secs=30)

    def test_register_and_heartbeat_make_worker_healthy(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(Path(tmp_dir) / "image_workers.json")

            worker = service.register_worker(
                worker_id="node-a",
                name="Node A",
                base_url="http://node-a.test",
                capacity=2,
                modes=["generate"],
            )
            heartbeat = service.heartbeat("node-a", active_tasks=1, avg_latency_ms=850)

            self.assertEqual(worker["id"], "node-a")
            self.assertEqual(heartbeat["active_tasks"], 1)
            self.assertTrue(heartbeat["healthy"])
            self.assertEqual(heartbeat["remaining_capacity"], 1)

    def test_select_worker_prefers_capacity_and_latency(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(Path(tmp_dir) / "image_workers.json")
            service.register_worker(worker_id="busy", capacity=2, modes=["generate"])
            service.register_worker(worker_id="fast", capacity=2, modes=["generate"])
            service.heartbeat("busy", active_tasks=1, avg_latency_ms=200)
            service.heartbeat("fast", active_tasks=0, avg_latency_ms=800)

            selected = service.select_worker("generate")

            self.assertIsNotNone(selected)
            self.assertEqual(selected["id"], "fast")
            self.assertEqual(selected["active_tasks"], 1)

    def test_select_worker_ignores_stale_disabled_and_wrong_mode_nodes(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "image_workers.json"
            service = ImageWorkerService(path, heartbeat_timeout_secs=1)
            service.register_worker(worker_id="stale", capacity=2, modes=["generate"])
            service.heartbeat("stale")
            time.sleep(1.05)
            service.register_worker(worker_id="disabled", enabled=False)
            service.heartbeat("disabled")
            service.register_worker(worker_id="edit-only", modes=["edit"])
            service.heartbeat("edit-only")

            self.assertIsNone(service.select_worker("generate"))

    def test_worker_state_persists(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "image_workers.json"
            service = self.make_service(path)
            service.register_worker(worker_id="node-a", name="Node A", capacity=3)
            service.heartbeat("node-a", active_tasks=1)

            reloaded = self.make_service(path)
            items = reloaded.list_workers()

            self.assertEqual(items[0]["id"], "node-a")
            self.assertEqual(items[0]["name"], "Node A")
            self.assertEqual(items[0]["active_tasks"], 1)


if __name__ == "__main__":
    unittest.main()
