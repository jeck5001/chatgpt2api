from __future__ import annotations

import unittest

from services.image_worker_runner import ImageWorkerRunner


class FakeWorkerClient:
    def __init__(self, claim_item=None):
        self.claim_item = claim_item
        self.calls = []

    def post_json(self, path, payload=None):
        self.calls.append(("POST", path, payload))
        if path.endswith("/tasks/claim"):
            return {"item": self.claim_item}
        if path.endswith("/complete"):
            return {"item": {"id": path.split("/")[-2], **(payload or {})}}
        return {"item": {"ok": True, **(payload or {})}}


def _find_complete_call(client: FakeWorkerClient):
    for call in client.calls:
        if call[1].endswith("/complete"):
            return call
    raise AssertionError("complete call was not sent")


class ImageWorkerRunnerTests(unittest.TestCase):
    def test_register_sends_worker_metadata(self):
        client = FakeWorkerClient()
        runner = ImageWorkerRunner(
            worker_id="node-a",
            server_url="http://main.test",
            auth_key="secret",
            client=client,
            name="Node A",
            capacity=2,
        )

        runner.register()

        self.assertEqual(client.calls[0][1], "/api/image-workers")
        self.assertEqual(client.calls[0][2]["id"], "node-a")
        self.assertEqual(client.calls[0][2]["capacity"], 2)

    def test_run_once_claims_executes_and_completes_task(self):
        client = FakeWorkerClient(
            {
                "id": "task-1",
                "mode": "generate",
                "payload": {"prompt": "cat", "model": "gpt-image-2"},
            }
        )

        def handler(payload):
            return {"data": [{"url": f"http://worker.test/{payload['prompt']}.png"}]}

        runner = ImageWorkerRunner(
            worker_id="node-a",
            server_url="http://main.test",
            auth_key="secret",
            client=client,
            generation_handler=handler,
        )

        did_work = runner.run_once()

        self.assertTrue(did_work)
        complete_call = _find_complete_call(client)
        self.assertEqual(complete_call[1], "/api/image-workers/node-a/tasks/task-1/complete")
        self.assertEqual(complete_call[2]["data"][0]["url"], "http://worker.test/cat.png")
        self.assertGreaterEqual(complete_call[2]["avg_latency_ms"], 0)

    def test_run_once_returns_false_when_no_task_is_claimed(self):
        client = FakeWorkerClient(None)
        runner = ImageWorkerRunner(
            worker_id="node-a",
            server_url="http://main.test",
            auth_key="secret",
            client=client,
        )

        self.assertFalse(runner.run_once())
        self.assertEqual(client.calls, [("POST", "/api/image-workers/node-a/tasks/claim", None)])

    def test_run_once_completes_with_error_when_handler_fails(self):
        client = FakeWorkerClient(
            {
                "id": "task-1",
                "mode": "generate",
                "payload": {"prompt": "cat"},
            }
        )

        def handler(_payload):
            raise RuntimeError("upstream down")

        runner = ImageWorkerRunner(
            worker_id="node-a",
            server_url="http://main.test",
            auth_key="secret",
            client=client,
            generation_handler=handler,
        )

        self.assertTrue(runner.run_once())
        complete_call = _find_complete_call(client)
        self.assertEqual(complete_call[2]["data"], [])
        self.assertEqual(complete_call[2]["error"], "upstream down")


if __name__ == "__main__":
    unittest.main()
