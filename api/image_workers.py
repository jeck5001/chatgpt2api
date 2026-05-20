from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Header, HTTPException
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field

from api.support import require_admin
from services.image_task_service import image_task_service
from services.image_worker_service import image_worker_service


class ImageWorkerRegisterRequest(BaseModel):
    id: str = Field(..., min_length=1)
    name: str = ""
    base_url: str = ""
    capacity: int = 1
    modes: list[str] = Field(default_factory=lambda: ["generate"])
    enabled: bool = True


class ImageWorkerHeartbeatRequest(BaseModel):
    active_tasks: int | None = None
    success_count: int | None = None
    failure_count: int | None = None
    avg_latency_ms: int | None = None


class ImageWorkerCompleteRequest(BaseModel):
    data: list[dict[str, Any]] = Field(default_factory=list)
    error: str = ""
    avg_latency_ms: int | None = None


def create_router() -> APIRouter:
    router = APIRouter()

    @router.get("/api/image-workers")
    async def list_image_workers(authorization: str | None = Header(default=None)):
        require_admin(authorization)
        return {"items": await run_in_threadpool(image_worker_service.list_workers)}

    @router.post("/api/image-workers")
    async def register_image_worker(
        body: ImageWorkerRegisterRequest,
        authorization: str | None = Header(default=None),
    ):
        require_admin(authorization)
        item = await run_in_threadpool(
            image_worker_service.register_worker,
            worker_id=body.id,
            name=body.name,
            base_url=body.base_url,
            capacity=body.capacity,
            modes=body.modes,
            enabled=body.enabled,
        )
        return {"item": item}

    @router.post("/api/image-workers/{worker_id}/heartbeat")
    async def heartbeat_image_worker(
        worker_id: str,
        body: ImageWorkerHeartbeatRequest,
        authorization: str | None = Header(default=None),
    ):
        require_admin(authorization)
        item = await run_in_threadpool(
            image_worker_service.heartbeat,
            worker_id,
            active_tasks=body.active_tasks,
            success_count=body.success_count,
            failure_count=body.failure_count,
            avg_latency_ms=body.avg_latency_ms,
        )
        return {"item": item}

    @router.post("/api/image-workers/{worker_id}/tasks/claim")
    async def claim_image_worker_task(worker_id: str, authorization: str | None = Header(default=None)):
        require_admin(authorization)
        item = await run_in_threadpool(image_task_service.claim_worker_task, worker_id)
        return {"item": item}

    @router.post("/api/image-workers/{worker_id}/tasks/{task_id}/complete")
    async def complete_image_worker_task(
        worker_id: str,
        task_id: str,
        body: ImageWorkerCompleteRequest,
        authorization: str | None = Header(default=None),
    ):
        require_admin(authorization)
        item = await run_in_threadpool(
            image_task_service.complete_worker_task,
            worker_id,
            task_id,
            data=body.data,
            error=body.error,
            avg_latency_ms=body.avg_latency_ms,
        )
        if item is None:
            raise HTTPException(status_code=404, detail={"error": "worker task not found"})
        return {"item": item}

    return router
