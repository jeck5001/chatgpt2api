from __future__ import annotations

import unittest
from unittest import mock

from fastapi import FastAPI
from fastapi.testclient import TestClient

import api.image_workers as image_workers_module


AUTH_HEADERS = {"Authorization": "Bearer chatgpt2api"}


class FakeWorkerService:
    def __init__(self):
        self.register_calls = []
        self.heartbeat_calls = []

    def list_workers(self):
        return [{"id": "node-a", "healthy": True, "remaining_capacity": 1}]

    def register_worker(self, **kwargs):
        self.register_calls.append(kwargs)
        return {"id": kwargs["worker_id"], "healthy": False}

    def heartbeat(self, worker_id, **kwargs):
        self.heartbeat_calls.append((worker_id, kwargs))
        return {"id": worker_id, "healthy": True, "active_tasks": kwargs.get("active_tasks", 0)}


class FakeImageTaskService:
    def __init__(self):
        self.claim_calls = []
        self.complete_calls = []

    def claim_worker_task(self, worker_id):
        self.claim_calls.append(worker_id)
        return {
            "id": "task-1",
            "mode": "generate",
            "payload": {"prompt": "cat", "model": "gpt-image-2"},
        }

    def complete_worker_task(self, worker_id, task_id, **kwargs):
        self.complete_calls.append((worker_id, task_id, kwargs))
        return {
            "id": task_id,
            "status": "success",
            "dispatch_mode": "remote",
            "worker_id": worker_id,
            "data": kwargs.get("data") or [],
        }


class ImageWorkersApiTests(unittest.TestCase):
    def setUp(self):
        self.fake_worker_service = FakeWorkerService()
        self.fake_task_service = FakeImageTaskService()
        self.worker_patcher = mock.patch.object(
            image_workers_module,
            "image_worker_service",
            self.fake_worker_service,
        )
        self.task_patcher = mock.patch.object(
            image_workers_module,
            "image_task_service",
            self.fake_task_service,
        )
        self.worker_patcher.start()
        self.task_patcher.start()
        self.addCleanup(self.worker_patcher.stop)
        self.addCleanup(self.task_patcher.stop)
        app = FastAPI()
        app.include_router(image_workers_module.create_router())
        self.client = TestClient(app)

    def test_register_worker(self):
        response = self.client.post(
            "/api/image-workers",
            headers=AUTH_HEADERS,
            json={
                "id": "node-a",
                "name": "Node A",
                "base_url": "http://node-a.test",
                "capacity": 2,
                "modes": ["generate"],
            },
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["item"]["id"], "node-a")
        self.assertEqual(self.fake_worker_service.register_calls[0]["capacity"], 2)

    def test_heartbeat_worker(self):
        response = self.client.post(
            "/api/image-workers/node-a/heartbeat",
            headers=AUTH_HEADERS,
            json={"active_tasks": 1, "avg_latency_ms": 900},
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertTrue(response.json()["item"]["healthy"])
        self.assertEqual(self.fake_worker_service.heartbeat_calls[0][1]["avg_latency_ms"], 900)

    def test_worker_claims_and_completes_task(self):
        claim = self.client.post("/api/image-workers/node-a/tasks/claim", headers=AUTH_HEADERS)
        complete = self.client.post(
            "/api/image-workers/node-a/tasks/task-1/complete",
            headers=AUTH_HEADERS,
            json={"data": [{"url": "http://node-a.test/cat.png"}], "avg_latency_ms": 1200},
        )

        self.assertEqual(claim.status_code, 200, claim.text)
        self.assertEqual(claim.json()["item"]["payload"]["prompt"], "cat")
        self.assertEqual(complete.status_code, 200, complete.text)
        self.assertEqual(complete.json()["item"]["status"], "success")
        self.assertEqual(self.fake_task_service.complete_calls[0][2]["avg_latency_ms"], 1200)


if __name__ == "__main__":
    unittest.main()
