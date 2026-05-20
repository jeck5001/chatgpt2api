from __future__ import annotations

import json
import tempfile
import time
import unittest
from pathlib import Path

from services.image_task_service import ImageTaskService
from services.image_worker_service import ImageWorkerService


OWNER = {"id": "owner-1", "name": "Owner", "role": "admin"}
OTHER_OWNER = {"id": "owner-2", "name": "Other", "role": "user"}


def wait_for_task(service: ImageTaskService, identity: dict[str, object], task_id: str, status: str, timeout: float = 2.0):
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        result = service.list_tasks(identity, [task_id])
        last = (result.get("items") or [None])[0]
        if last and last.get("status") == status:
            return last
        time.sleep(0.02)
    raise AssertionError(f"task {task_id} did not reach {status}, last={last}")


class ImageTaskServiceTests(unittest.TestCase):
    def make_service(self, path: Path, handler=None, worker_service=None) -> ImageTaskService:
        return ImageTaskService(
            path,
            generation_handler=handler or (lambda _payload: {"data": [{"url": "http://example.test/image.png"}]}),
            edit_handler=handler or (lambda _payload: {"data": [{"url": "http://example.test/edit.png"}]}),
            retention_days_getter=lambda: 30,
            worker_service=worker_service,
        )

    def test_duplicate_submit_uses_existing_task(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            calls = 0

            def handler(_payload):
                nonlocal calls
                calls += 1
                time.sleep(0.05)
                return {"data": [{"url": "http://example.test/image.png"}]}

            service = self.make_service(Path(tmp_dir) / "image_tasks.json", handler)
            first = service.submit_generation(
                OWNER,
                client_task_id="task-1",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )
            second = service.submit_generation(
                OWNER,
                client_task_id="task-1",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )

            self.assertEqual(first["id"], "task-1")
            self.assertEqual(second["id"], "task-1")
            task = wait_for_task(service, OWNER, "task-1", "success")
            self.assertEqual(task["data"][0]["url"], "http://example.test/image.png")
            self.assertEqual(calls, 1)

    def test_different_owner_cannot_query_task(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(Path(tmp_dir) / "image_tasks.json")
            service.submit_generation(
                OWNER,
                client_task_id="private-task",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )

            wait_for_task(service, OWNER, "private-task", "success")
            result = service.list_tasks(OTHER_OWNER, ["private-task"])

            self.assertEqual(result["items"], [])
            self.assertEqual(result["missing_ids"], ["private-task"])

    def test_get_task_returns_none_for_empty_task_id(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(Path(tmp_dir) / "image_tasks.json")
            service.submit_generation(
                OWNER,
                client_task_id="task-1",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )

            wait_for_task(service, OWNER, "task-1", "success")

            self.assertIsNone(service.get_task(OWNER, ""))

    def test_submit_rolls_back_in_memory_task_when_save_fails(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(Path(tmp_dir) / "image_tasks.json")

            def fail_save():
                raise RuntimeError("save failed")

            service._save_locked = fail_save

            with self.assertRaises(RuntimeError):
                service.submit_generation(
                    OWNER,
                    client_task_id="dead-task",
                    prompt="cat",
                    model="gpt-image-2",
                    size=None,
                    base_url="http://local.test",
                )

            self.assertIsNone(service.get_task(OWNER, "dead-task"))
            self.assertEqual(service.list_tasks(OWNER, ["dead-task"])["missing_ids"], ["dead-task"])

    def test_success_task_persists_to_new_service_instance(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "image_tasks.json"
            service = self.make_service(path)
            service.submit_generation(
                OWNER,
                client_task_id="persisted-task",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )
            wait_for_task(service, OWNER, "persisted-task", "success")

            reloaded = self.make_service(path)
            result = reloaded.list_tasks(OWNER, ["persisted-task"])

            self.assertEqual(result["missing_ids"], [])
            self.assertEqual(result["items"][0]["status"], "success")
            self.assertEqual(result["items"][0]["data"][0]["url"], "http://example.test/image.png")

    def test_startup_marks_unfinished_tasks_as_error(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "image_tasks.json"
            path.write_text(
                json.dumps(
                    {
                        "tasks": [
                            {
                                "id": "queued-task",
                                "owner_id": "owner-1",
                                "status": "queued",
                                "mode": "generate",
                                "model": "gpt-image-2",
                                "created_at": "2099-01-01 00:00:00",
                                "updated_at": "2099-01-01 00:00:00",
                            },
                            {
                                "id": "running-task",
                                "owner_id": "owner-1",
                                "status": "running",
                                "mode": "generate",
                                "model": "gpt-image-2",
                                "created_at": "2099-01-01 00:00:00",
                                "updated_at": "2099-01-01 00:00:00",
                            },
                        ]
                    }
                ),
                encoding="utf-8",
            )

            service = self.make_service(path)
            result = service.list_tasks(OWNER, ["queued-task", "running-task"])

            self.assertEqual([item["status"] for item in result["items"]], ["error", "error"])
            self.assertTrue(all("已中断" in item.get("error", "") for item in result["items"]))

    def test_forget_tasks_removes_only_caller_owned_records(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "image_tasks.json"
            service = self.make_service(path)
            service.submit_generation(
                OWNER,
                client_task_id="task-keep",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )
            service.submit_generation(
                OWNER,
                client_task_id="task-drop",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )
            service.submit_generation(
                OTHER_OWNER,
                client_task_id="task-drop",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )
            wait_for_task(service, OWNER, "task-keep", "success")
            wait_for_task(service, OWNER, "task-drop", "success")
            wait_for_task(service, OTHER_OWNER, "task-drop", "success")

            removed = service.forget_tasks(OWNER, ["task-drop", "", "ghost"])

            self.assertEqual(removed, 1)
            self.assertIsNone(service.get_task(OWNER, "task-drop"))
            self.assertIsNotNone(service.get_task(OWNER, "task-keep"))
            self.assertIsNotNone(service.get_task(OTHER_OWNER, "task-drop"))

            reloaded = self.make_service(path)
            self.assertIsNone(reloaded.get_task(OWNER, "task-drop"))
            self.assertIsNotNone(reloaded.get_task(OTHER_OWNER, "task-drop"))

    def test_submit_inpaint_sends_source_and_mask_to_edit_handler(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            captured_payloads = []

            def handler(payload):
                captured_payloads.append(payload)
                return {"data": [{"url": "http://example.test/inpaint.png"}]}

            service = self.make_service(Path(tmp_dir) / "image_tasks.json", handler)

            task = service.submit_inpaint(
                OWNER,
                client_task_id="inpaint-task",
                prompt="replace the sign with a neon logo",
                model="gpt-image-2",
                size="1024x1024",
                base_url="http://local.test",
                image=(b"source-bytes", "source.png", "image/png"),
                mask=(b"mask-bytes", "mask.png", "image/png"),
            )

            self.assertEqual(task["mode"], "inpaint")
            settled = wait_for_task(service, OWNER, "inpaint-task", "success")
            self.assertEqual(settled["data"][0]["url"], "http://example.test/inpaint.png")
            self.assertEqual([item[1] for item in captured_payloads[0]["images"]], ["source.png", "mask.png"])
            self.assertIn("masked", captured_payloads[0]["prompt"].lower())

    def test_generation_dispatches_to_healthy_worker(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            calls = 0

            def handler(_payload):
                nonlocal calls
                calls += 1
                return {"data": [{"url": "http://example.test/local.png"}]}

            worker_service = ImageWorkerService(Path(tmp_dir) / "image_workers.json", heartbeat_timeout_secs=30)
            worker_service.register_worker(worker_id="node-a", capacity=2, modes=["generate"])
            worker_service.heartbeat("node-a")
            service = self.make_service(
                Path(tmp_dir) / "image_tasks.json",
                handler,
                worker_service=worker_service,
            )

            task = service.submit_generation(
                OWNER,
                client_task_id="remote-task",
                prompt="cat",
                model="gpt-image-2",
                size="1024x1024",
                base_url="http://local.test",
            )

            self.assertEqual(task["status"], "queued")
            self.assertEqual(task["dispatch_mode"], "remote")
            self.assertEqual(task["worker_id"], "node-a")
            self.assertEqual(calls, 0)

            claimed = service.claim_worker_task("node-a")
            self.assertEqual(claimed["id"], "remote-task")
            self.assertEqual(claimed["payload"]["prompt"], "cat")
            self.assertEqual(service.get_task(OWNER, "remote-task")["status"], "running")

            completed = service.complete_worker_task(
                "node-a",
                "remote-task",
                data=[{"url": "http://node-a.test/image.png"}],
            )

            self.assertEqual(completed["status"], "success")
            self.assertEqual(completed["data"][0]["url"], "http://node-a.test/image.png")

    def test_generation_falls_back_to_local_when_no_healthy_worker(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            calls = 0

            def handler(_payload):
                nonlocal calls
                calls += 1
                return {"data": [{"url": "http://example.test/local.png"}]}

            worker_service = ImageWorkerService(Path(tmp_dir) / "image_workers.json", heartbeat_timeout_secs=1)
            worker_service.register_worker(worker_id="stale", capacity=2, modes=["generate"])
            service = self.make_service(
                Path(tmp_dir) / "image_tasks.json",
                handler,
                worker_service=worker_service,
            )

            task = service.submit_generation(
                OWNER,
                client_task_id="local-task",
                prompt="cat",
                model="gpt-image-2",
                size=None,
                base_url="http://local.test",
            )

            self.assertEqual(task["dispatch_mode"], "local")
            settled = wait_for_task(service, OWNER, "local-task", "success")
            self.assertEqual(settled.get("dispatch_mode"), "local")
            self.assertEqual(calls, 1)


if __name__ == "__main__":
    unittest.main()
