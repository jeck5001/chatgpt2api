from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from api.support import require_identity
from services.studio_service import studio_service


class ProjectCreateRequest(BaseModel):
    name: str = Field(..., min_length=1)


class ProjectUpdateRequest(BaseModel):
    name: str | None = None
    archived: bool | None = None


class ConversationCreateRequest(BaseModel):
    project_id: str = Field(..., min_length=1)
    title: str = ""
    mode: str = "generate"


class FavoriteCreateRequest(BaseModel):
    image_path: str = Field(..., min_length=1)
    source_turn_id: str = ""
    note: str = ""


class TemplateCreateRequest(BaseModel):
    name: str = Field(..., min_length=1)
    category: str = ""
    content: str = Field(..., min_length=1)


class TemplateUpdateRequest(BaseModel):
    name: str | None = None
    category: str | None = None
    content: str | None = None


def _identity(authorization: str | None) -> dict[str, object]:
    return require_identity(authorization)


def _not_found(message: str) -> HTTPException:
    return HTTPException(status_code=404, detail={"error": message})


def _bad_request(exc: ValueError) -> HTTPException:
    return HTTPException(status_code=400, detail={"error": str(exc)})


def create_router() -> APIRouter:
    router = APIRouter()

    @router.get("/api/projects")
    async def list_projects(authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        return {"items": studio_service.list_projects(identity)}

    @router.post("/api/projects")
    async def create_project(body: ProjectCreateRequest, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        return {"item": studio_service.create_project(identity, body.name)}

    @router.patch("/api/projects/{project_id}")
    async def update_project(project_id: str, body: ProjectUpdateRequest, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        item = studio_service.update_project(identity, project_id, body.model_dump(exclude_unset=True))
        if item is None:
            raise _not_found("project not found")
        return {"item": item}

    @router.get("/api/image-conversations")
    async def list_image_conversations(project_id: str = "", authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        return {"items": studio_service.list_conversations(identity, project_id)}

    @router.post("/api/image-conversations")
    async def create_image_conversation(body: ConversationCreateRequest, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        try:
            item = studio_service.create_conversation(identity, body.project_id, body.title, body.mode)
        except ValueError as exc:
            raise _not_found(str(exc)) from exc
        return {"item": item}

    @router.get("/api/prompt-templates")
    async def list_prompt_templates(authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        return {"items": studio_service.list_prompt_templates(identity)}

    @router.post("/api/prompt-templates")
    async def create_prompt_template(body: TemplateCreateRequest, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        try:
            item = studio_service.create_prompt_template(identity, body.name, body.category, body.content)
        except ValueError as exc:
            raise _bad_request(exc) from exc
        return {"item": item}

    @router.patch("/api/prompt-templates/{template_id}")
    async def update_prompt_template(template_id: str, body: TemplateUpdateRequest, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        try:
            item = studio_service.update_prompt_template(identity, template_id, body.model_dump(exclude_unset=True))
        except ValueError as exc:
            raise _bad_request(exc) from exc
        if item is None:
            raise _not_found("template not found")
        return {"item": item}

    @router.delete("/api/prompt-templates/{template_id}")
    async def delete_prompt_template(template_id: str, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        if not studio_service.delete_prompt_template(identity, template_id):
            raise _not_found("template not found")
        return {"ok": True}

    @router.post("/api/image-favorites")
    async def add_image_favorite(body: FavoriteCreateRequest, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        try:
            item = studio_service.add_favorite(identity, body.image_path, source_turn_id=body.source_turn_id, note=body.note)
        except ValueError as exc:
            raise _bad_request(exc) from exc
        return {"item": item}

    @router.get("/api/image-favorites")
    async def list_image_favorites(authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        return {"items": studio_service.list_favorites(identity)}

    @router.delete("/api/image-favorites/{favorite_id}")
    async def delete_image_favorite(favorite_id: str, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        if not studio_service.delete_favorite(identity, favorite_id):
            raise _not_found("favorite not found")
        return {"ok": True}

    return router
