from __future__ import annotations

import json
import time
from collections.abc import Callable
from typing import Any
from urllib import error, request

from services.protocol import openai_v1_image_generations


def _clean(value: object, default: str = "") -> str:
    return str(value or default).strip()


class WorkerApiClient:
    def __init__(self, server_url: str, auth_key: str, *, timeout: float = 30.0):
        self.server_url = _clean(server_url).rstrip("/")
        self.auth_key = _clean(auth_key)
        self.timeout = timeout
        if not self.server_url:
            raise ValueError("server_url is required")
        if not self.auth_key:
            raise ValueError("auth_key is required")

    def post_json(self, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        url = f"{self.server_url}/{path.lstrip('/')}"
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        req = request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"Bearer {self.auth_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with request.urlopen(req, timeout=self.timeout) as resp:
                body = resp.read().decode("utf-8")
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"worker api failed: HTTP {exc.code} {detail}") from exc
        if not body:
            return {}
        parsed = json.loads(body)
        return parsed if isinstance(parsed, dict) else {}


class ImageWorkerRunner:
    def __init__(
        self,
        *,
        worker_id: str,
        server_url: str,
        auth_key: str,
        client: Any | None = None,
        name: str = "",
        capacity: int = 1,
        poll_interval_secs: float = 2.0,
        generation_handler: Callable[[dict[str, Any]], dict[str, Any]] = openai_v1_image_generations.handle,
    ):
        self.worker_id = _clean(worker_id)
        if not self.worker_id:
            raise ValueError("worker_id is required")
        self.name = _clean(name) or self.worker_id
        self.capacity = max(1, int(capacity or 1))
        self.poll_interval_secs = max(0.1, float(poll_interval_secs))
        self.client = client or WorkerApiClient(server_url, auth_key)
        self.generation_handler = generation_handler
        self.success_count = 0
        self.failure_count = 0
        self.active_tasks = 0
        self.avg_latency_ms = 0

    def register(self) -> dict[str, Any]:
        return self.client.post_json(
            "/api/image-workers",
            {
                "id": self.worker_id,
                "name": self.name,
                "capacity": self.capacity,
                "modes": ["generate"],
                "enabled": True,
            },
        )

    def heartbeat(self) -> dict[str, Any]:
        return self.client.post_json(
            f"/api/image-workers/{self.worker_id}/heartbeat",
            {
                "active_tasks": self.active_tasks,
                "success_count": self.success_count,
                "failure_count": self.failure_count,
                "avg_latency_ms": self.avg_latency_ms,
            },
        )

    def run_once(self) -> bool:
        claimed = self.client.post_json(f"/api/image-workers/{self.worker_id}/tasks/claim").get("item")
        if not isinstance(claimed, dict):
            return False
        task_id = _clean(claimed.get("id"))
        if not task_id:
            return False
        started = time.time()
        self.active_tasks += 1
        try:
            self.heartbeat()
            payload = claimed.get("payload") if isinstance(claimed.get("payload"), dict) else {}
            result = self.generation_handler(payload)
            if not isinstance(result, dict):
                raise RuntimeError("worker handler returned streaming result unexpectedly")
            data = result.get("data")
            if not isinstance(data, list) or not data:
                raise RuntimeError(_clean(result.get("message")) or "worker handler returned no image data")
            elapsed_ms = int((time.time() - started) * 1000)
            self.success_count += 1
            self.avg_latency_ms = elapsed_ms
            self._complete(task_id, data=data, error="", avg_latency_ms=elapsed_ms)
        except Exception as exc:
            elapsed_ms = int((time.time() - started) * 1000)
            self.failure_count += 1
            self.avg_latency_ms = elapsed_ms
            self._complete(task_id, data=[], error=str(exc) or "worker task failed", avg_latency_ms=elapsed_ms)
        finally:
            self.active_tasks = max(0, self.active_tasks - 1)
            self.heartbeat()
        return True

    def run_forever(self) -> None:
        self.register()
        self.heartbeat()
        while True:
            did_work = self.run_once()
            if not did_work:
                time.sleep(self.poll_interval_secs)

    def _complete(
        self,
        task_id: str,
        *,
        data: list[Any],
        error: str,
        avg_latency_ms: int,
    ) -> dict[str, Any]:
        return self.client.post_json(
            f"/api/image-workers/{self.worker_id}/tasks/{task_id}/complete",
            {
                "data": data,
                "error": error,
                "avg_latency_ms": avg_latency_ms,
            },
        )
