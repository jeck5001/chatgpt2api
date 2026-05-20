from __future__ import annotations

import json
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from services.config import DATA_DIR


def _now_iso() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _clean(value: object, default: str = "") -> str:
    return str(value or default).strip()


def _timestamp(value: object) -> float:
    raw = _clean(value)
    if not raw:
        return 0.0
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(raw[:26], fmt).timestamp()
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).timestamp()
    except Exception:
        return 0.0


def _positive_int(value: object, default: int = 0, minimum: int = 0) -> int:
    try:
        normalized = int(value)
    except (TypeError, ValueError):
        normalized = default
    return max(minimum, normalized)


def _normalize_modes(value: object) -> list[str]:
    source = value if isinstance(value, list) else ["generate"]
    modes = []
    for item in source:
        mode = _clean(item).lower()
        if mode and mode not in modes:
            modes.append(mode)
    return modes or ["generate"]


class ImageWorkerService:
    def __init__(self, path: Path, *, heartbeat_timeout_secs: int = 60):
        self.path = path
        self.heartbeat_timeout_secs = max(1, int(heartbeat_timeout_secs))
        self._lock = threading.RLock()
        self._workers: dict[str, dict[str, Any]] = {}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self._lock:
            self._workers = self._load_locked()

    def register_worker(
        self,
        *,
        worker_id: str,
        name: str = "",
        base_url: str = "",
        capacity: int = 1,
        modes: list[str] | None = None,
        enabled: bool = True,
    ) -> dict[str, Any]:
        worker_id = _clean(worker_id)
        if not worker_id:
            raise ValueError("worker_id is required")
        now = _now_iso()
        with self._lock:
            current = self._workers.get(worker_id, {})
            worker = {
                "id": worker_id,
                "name": _clean(name) or _clean(current.get("name")) or worker_id,
                "base_url": _clean(base_url) or _clean(current.get("base_url")),
                "enabled": bool(enabled),
                "capacity": _positive_int(capacity, _positive_int(current.get("capacity"), 1, 1), 1),
                "modes": _normalize_modes(modes if modes is not None else current.get("modes")),
                "active_tasks": _positive_int(current.get("active_tasks"), 0, 0),
                "success_count": _positive_int(current.get("success_count"), 0, 0),
                "failure_count": _positive_int(current.get("failure_count"), 0, 0),
                "avg_latency_ms": _positive_int(current.get("avg_latency_ms"), 0, 0),
                "created_at": _clean(current.get("created_at"), now),
                "updated_at": now,
                "heartbeat_at": _clean(current.get("heartbeat_at")),
            }
            self._workers[worker_id] = worker
            self._save_locked()
            return self._public_worker(worker)

    def heartbeat(
        self,
        worker_id: str,
        *,
        active_tasks: int | None = None,
        success_count: int | None = None,
        failure_count: int | None = None,
        avg_latency_ms: int | None = None,
    ) -> dict[str, Any]:
        worker_id = _clean(worker_id)
        if not worker_id:
            raise ValueError("worker_id is required")
        with self._lock:
            worker = self._workers.get(worker_id)
            if worker is None:
                worker = self.register_worker(worker_id=worker_id)
                worker = self._workers[worker_id]
            if active_tasks is not None:
                worker["active_tasks"] = _positive_int(active_tasks, 0, 0)
            if success_count is not None:
                worker["success_count"] = _positive_int(success_count, 0, 0)
            if failure_count is not None:
                worker["failure_count"] = _positive_int(failure_count, 0, 0)
            if avg_latency_ms is not None:
                worker["avg_latency_ms"] = _positive_int(avg_latency_ms, 0, 0)
            now = _now_iso()
            worker["heartbeat_at"] = now
            worker["updated_at"] = now
            self._save_locked()
            return self._public_worker(worker)

    def list_workers(self) -> list[dict[str, Any]]:
        with self._lock:
            items = [self._public_worker(worker) for worker in self._workers.values()]
        items.sort(key=lambda item: (not bool(item.get("healthy")), str(item.get("id") or "")))
        return items

    def select_worker(self, mode: str) -> dict[str, Any] | None:
        normalized_mode = _clean(mode).lower() or "generate"
        with self._lock:
            candidates = [
                worker
                for worker in self._workers.values()
                if self._is_healthy(worker) and normalized_mode in _normalize_modes(worker.get("modes"))
            ]
            if not candidates:
                return None
            candidates.sort(key=self._selection_key)
            worker = candidates[0]
            worker["active_tasks"] = _positive_int(worker.get("active_tasks"), 0, 0) + 1
            worker["updated_at"] = _now_iso()
            self._save_locked()
            return self._public_worker(worker)

    def release_worker(self, worker_id: str, *, success: bool | None = None, avg_latency_ms: int | None = None) -> None:
        worker_id = _clean(worker_id)
        if not worker_id:
            return
        with self._lock:
            worker = self._workers.get(worker_id)
            if worker is None:
                return
            worker["active_tasks"] = max(0, _positive_int(worker.get("active_tasks"), 0, 0) - 1)
            if success is True:
                worker["success_count"] = _positive_int(worker.get("success_count"), 0, 0) + 1
            elif success is False:
                worker["failure_count"] = _positive_int(worker.get("failure_count"), 0, 0) + 1
            if avg_latency_ms is not None:
                worker["avg_latency_ms"] = _positive_int(avg_latency_ms, 0, 0)
            worker["updated_at"] = _now_iso()
            self._save_locked()

    def _selection_key(self, worker: dict[str, Any]) -> tuple[int, int, float, str]:
        public = self._public_worker(worker)
        success = _positive_int(worker.get("success_count"), 0, 0)
        failure = _positive_int(worker.get("failure_count"), 0, 0)
        total = max(1, success + failure)
        failure_rate = failure / total
        return (
            -_positive_int(public.get("remaining_capacity"), 0, 0),
            _positive_int(worker.get("avg_latency_ms"), 0, 0),
            failure_rate,
            _clean(worker.get("id")),
        )

    def _public_worker(self, worker: dict[str, Any]) -> dict[str, Any]:
        capacity = _positive_int(worker.get("capacity"), 1, 1)
        active = _positive_int(worker.get("active_tasks"), 0, 0)
        heartbeat_age = max(0.0, time.time() - _timestamp(worker.get("heartbeat_at"))) if worker.get("heartbeat_at") else None
        healthy = self._is_healthy(worker)
        return {
            "id": _clean(worker.get("id")),
            "name": _clean(worker.get("name")),
            "base_url": _clean(worker.get("base_url")),
            "enabled": bool(worker.get("enabled", True)),
            "capacity": capacity,
            "modes": _normalize_modes(worker.get("modes")),
            "active_tasks": active,
            "remaining_capacity": max(0, capacity - active),
            "success_count": _positive_int(worker.get("success_count"), 0, 0),
            "failure_count": _positive_int(worker.get("failure_count"), 0, 0),
            "avg_latency_ms": _positive_int(worker.get("avg_latency_ms"), 0, 0),
            "heartbeat_at": _clean(worker.get("heartbeat_at")),
            "heartbeat_age_secs": heartbeat_age,
            "healthy": healthy,
            "created_at": _clean(worker.get("created_at")),
            "updated_at": _clean(worker.get("updated_at")),
        }

    def _is_healthy(self, worker: dict[str, Any]) -> bool:
        if not bool(worker.get("enabled", True)):
            return False
        if _positive_int(worker.get("active_tasks"), 0, 0) >= _positive_int(worker.get("capacity"), 1, 1):
            return False
        heartbeat_at = _timestamp(worker.get("heartbeat_at"))
        return heartbeat_at > 0 and time.time() - heartbeat_at <= self.heartbeat_timeout_secs

    def _load_locked(self) -> dict[str, dict[str, Any]]:
        if not self.path.exists():
            return {}
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except Exception:
            return {}
        raw_items = raw.get("workers") if isinstance(raw, dict) else raw
        if not isinstance(raw_items, list):
            return {}
        workers: dict[str, dict[str, Any]] = {}
        for item in raw_items:
            if not isinstance(item, dict):
                continue
            worker_id = _clean(item.get("id"))
            if not worker_id:
                continue
            workers[worker_id] = {
                "id": worker_id,
                "name": _clean(item.get("name"), worker_id),
                "base_url": _clean(item.get("base_url")),
                "enabled": bool(item.get("enabled", True)),
                "capacity": _positive_int(item.get("capacity"), 1, 1),
                "modes": _normalize_modes(item.get("modes")),
                "active_tasks": _positive_int(item.get("active_tasks"), 0, 0),
                "success_count": _positive_int(item.get("success_count"), 0, 0),
                "failure_count": _positive_int(item.get("failure_count"), 0, 0),
                "avg_latency_ms": _positive_int(item.get("avg_latency_ms"), 0, 0),
                "heartbeat_at": _clean(item.get("heartbeat_at")),
                "created_at": _clean(item.get("created_at"), _now_iso()),
                "updated_at": _clean(item.get("updated_at"), _clean(item.get("created_at"), _now_iso())),
            }
        return workers

    def _save_locked(self) -> None:
        items = sorted(self._workers.values(), key=lambda item: str(item.get("id") or ""))
        tmp_path = self.path.with_suffix(self.path.suffix + ".tmp")
        tmp_path.write_text(json.dumps({"workers": items}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        tmp_path.replace(self.path)


image_worker_service = ImageWorkerService(DATA_DIR / "image_workers.json")
