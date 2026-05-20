from __future__ import annotations

from fastapi import APIRouter, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field

from api.support import require_identity, resolve_image_base_url
from services.image_task_service import image_task_service
from services.studio_service import studio_service
from services.vision_prompt_service import draft_prompt_from_images


class ProjectCreateRequest(BaseModel):
    name: str = ""


class ProjectUpdateRequest(BaseModel):
    name: str | None = None
    archived: bool | None = None


class ConversationCreateRequest(BaseModel):
    project_id: str = Field(..., min_length=1)
    title: str = ""
    mode: str = "generate"


class TurnGenerationRequest(BaseModel):
    conversation_id: str = Field(..., min_length=1)
    client_task_id: str = Field(..., min_length=1)
    prompt: str = Field(..., min_length=1)
    model: str = "gpt-image-2"
    size: str | None = None


class TurnRetryRequest(BaseModel):
    client_task_id: str = Field(..., min_length=1)


class FavoriteCreateRequest(BaseModel):
    image_path: str = Field(..., min_length=1)
    source_turn_id: str = ""
    note: str = ""


class TemplateCreateRequest(BaseModel):
    name: str = ""
    category: str = ""
    content: str = Field(..., min_length=1)


class TemplateUpdateRequest(BaseModel):
    name: str | None = None
    category: str | None = None
    content: str | None = None


class RecipeCreateRequest(BaseModel):
    name: str = ""
    prompt: str = Field(..., min_length=1)
    model: str = "gpt-image-2"
    size: str | None = None
    source_image_path: str = ""
    source_turn_id: str = ""
    project_id: str = ""
    tags: list[str] = Field(default_factory=list)


def _identity(authorization: str | None) -> dict[str, object]:
    return require_identity(authorization)


def _not_found(message: str) -> HTTPException:
    return HTTPException(status_code=404, detail={"error": message})


def _bad_request(exc: ValueError) -> HTTPException:
    return HTTPException(status_code=400, detail={"error": str(exc)})


def _bad_gateway(exc: Exception) -> HTTPException:
    return HTTPException(status_code=502, detail={"error": str(exc) or "image task submit failed"})


def _turn_task_identity(identity: dict[str, object], turn: dict[str, object]) -> dict[str, object]:
    owner_id = str(turn.get("owner_id") or "").strip()
    if not owner_id:
        return identity
    return {**identity, "id": owner_id}


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
        item = studio_service.update_project(identity, project_id, body.model_dump(exclude_unset=True, exclude_none=True))
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

    @router.delete("/api/image-conversations/{conversation_id}")
    async def delete_image_conversation(
        conversation_id: str,
        purge: bool = False,
        authorization: str | None = Header(default=None),
    ):
        identity = _identity(authorization)
        if not studio_service.delete_conversation(
            identity, conversation_id, purge_images=purge
        ):
            raise _not_found("conversation not found")
        return {"ok": True}

    @router.get("/api/image-turns")
    async def list_image_turns(conversation_id: str = "", authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        return {"items": studio_service.list_turns(identity, conversation_id)}

    @router.delete("/api/image-turns/{turn_id}")
    async def delete_image_turn(
        turn_id: str,
        purge: bool = False,
        authorization: str | None = Header(default=None),
    ):
        identity = _identity(authorization)
        if not studio_service.delete_turn(identity, turn_id, purge_images=purge):
            raise _not_found("turn not found")
        return {"ok": True}

    @router.post("/api/image-turns/generations")
    async def create_generation_turn(
        body: TurnGenerationRequest,
        request: Request,
        authorization: str | None = Header(default=None),
    ):
        identity = _identity(authorization)
        try:
            turn = studio_service.create_queued_turn(
                identity,
                body.conversation_id,
                client_task_id=body.client_task_id,
                task_id=body.client_task_id,
                mode="generate",
                prompt=body.prompt,
                model=body.model,
                size=body.size,
                reference_images=[],
            )
            try:
                task = await run_in_threadpool(
                    image_task_service.submit_generation,
                    identity,
                    client_task_id=body.client_task_id,
                    prompt=body.prompt,
                    model=body.model,
                    size=body.size,
                    base_url=resolve_image_base_url(request),
                )
            except ValueError as exc:
                studio_service.mark_turn_error(identity, turn["id"], str(exc), task_id=body.client_task_id)
                raise
            except Exception as exc:
                studio_service.mark_turn_error(identity, turn["id"], str(exc), task_id=body.client_task_id)
                raise _bad_gateway(exc) from exc
            item = studio_service.sync_turn_from_task(identity, turn["id"], task)
        except ValueError as exc:
            raise _bad_request(exc) from exc
        if item is None:
            raise _not_found("turn not found")
        return {"item": item}

    @router.post("/api/image-turns/edits")
    async def create_edit_turn(
        request: Request,
        authorization: str | None = Header(default=None),
        image: list[UploadFile] | None = File(default=None),
        image_list: list[UploadFile] | None = File(default=None, alias="image[]"),
        conversation_id: str = Form(...),
        client_task_id: str = Form(...),
        prompt: str = Form(...),
        model: str = Form(default="gpt-image-2"),
        size: str | None = Form(default=None),
    ):
        identity = _identity(authorization)
        uploads = [*(image or []), *(image_list or [])]
        if not uploads:
            raise HTTPException(status_code=400, detail={"error": "image file is required"})
        images: list[tuple[bytes, str, str]] = []
        reference_images: list[dict[str, str]] = []
        for upload in uploads:
            image_data = await upload.read()
            if not image_data:
                raise HTTPException(status_code=400, detail={"error": "image file is empty"})
            filename = upload.filename or "image.png"
            content_type = upload.content_type or "image/png"
            images.append((image_data, filename, content_type))
            reference_images.append({"filename": filename, "content_type": content_type})
        try:
            turn = studio_service.create_queued_turn(
                identity,
                conversation_id,
                client_task_id=client_task_id,
                task_id=client_task_id,
                mode="edit",
                prompt=prompt,
                model=model,
                size=size,
                reference_images=reference_images,
            )
            try:
                task = await run_in_threadpool(
                    image_task_service.submit_edit,
                    identity,
                    client_task_id=client_task_id,
                    prompt=prompt,
                    model=model,
                    size=size,
                    base_url=resolve_image_base_url(request),
                    images=images,
                )
            except ValueError as exc:
                studio_service.mark_turn_error(identity, turn["id"], str(exc), task_id=client_task_id)
                raise
            except Exception as exc:
                studio_service.mark_turn_error(identity, turn["id"], str(exc), task_id=client_task_id)
                raise _bad_gateway(exc) from exc
            item = studio_service.sync_turn_from_task(identity, turn["id"], task)
        except ValueError as exc:
            raise _bad_request(exc) from exc
        if item is None:
            raise _not_found("turn not found")
        return {"item": item}

    @router.post("/api/image-turns/{turn_id}/sync")
    async def sync_image_turn(turn_id: str, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        turn = studio_service.get_turn(identity, turn_id)
        if turn is None:
            raise _not_found("turn not found")
        task_identity = _turn_task_identity(identity, turn)
        task = image_task_service.get_task(task_identity, str(turn.get("task_id") or ""))
        if task is None:
            raise _not_found("task not found")
        item = studio_service.sync_turn_from_task(identity, turn_id, task)
        if item is None:
            raise _not_found("turn not found")
        return {"item": item}

    @router.post("/api/image-turns/{turn_id}/retry")
    async def retry_image_turn(
        turn_id: str,
        body: TurnRetryRequest,
        request: Request,
        authorization: str | None = Header(default=None),
    ):
        identity = _identity(authorization)
        turn = studio_service.get_turn(identity, turn_id)
        if turn is None:
            raise _not_found("turn not found")
        task_identity = _turn_task_identity(identity, turn)
        try:
            retried = studio_service.mark_turn_retrying(identity, turn_id, body.client_task_id)
            if retried is None:
                raise _not_found("turn not found")
            try:
                task = await run_in_threadpool(
                    image_task_service.submit_generation,
                    task_identity,
                    client_task_id=body.client_task_id,
                    prompt=str(turn.get("prompt") or ""),
                    model=str(turn.get("model") or "gpt-image-2"),
                    size=str(turn.get("size") or "") or None,
                    base_url=resolve_image_base_url(request),
                )
            except ValueError as exc:
                studio_service.mark_turn_error(identity, turn_id, str(exc), task_id=body.client_task_id)
                raise
            except Exception as exc:
                studio_service.mark_turn_error(identity, turn_id, str(exc), task_id=body.client_task_id)
                raise _bad_gateway(exc) from exc
            item = studio_service.sync_turn_from_task(identity, turn_id, task)
        except ValueError as exc:
            raise _bad_request(exc) from exc
        if item is None:
            raise _not_found("turn not found")
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
            item = studio_service.update_prompt_template(identity, template_id, body.model_dump(exclude_unset=True, exclude_none=True))
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

    @router.get("/api/image-recipes")
    async def list_image_recipes(authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        return {"items": studio_service.list_recipes(identity)}

    @router.post("/api/image-recipes")
    async def create_image_recipe(body: RecipeCreateRequest, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        try:
            item = studio_service.create_recipe(
                identity,
                name=body.name,
                prompt=body.prompt,
                model=body.model,
                size=body.size,
                source_image_path=body.source_image_path,
                source_turn_id=body.source_turn_id,
                project_id=body.project_id,
                tags=body.tags,
            )
        except ValueError as exc:
            raise _bad_request(exc) from exc
        return {"item": item}

    @router.delete("/api/image-recipes/{recipe_id}")
    async def delete_image_recipe(recipe_id: str, authorization: str | None = Header(default=None)):
        identity = _identity(authorization)
        if not studio_service.delete_recipe(identity, recipe_id):
            raise _not_found("recipe not found")
        return {"ok": True}

    @router.post("/api/image-prompt-drafts")
    async def create_image_prompt_draft(
        authorization: str | None = Header(default=None),
        image: list[UploadFile] | None = File(default=None),
        image_list: list[UploadFile] | None = File(default=None, alias="image[]"),
    ):
        _identity(authorization)
        uploads = [*(image or []), *(image_list or [])]
        if not uploads:
            raise HTTPException(status_code=400, detail={"error": "image file is required"})
        images: list[tuple[bytes, str, str]] = []
        for upload in uploads:
            image_data = await upload.read()
            if not image_data:
                raise HTTPException(status_code=400, detail={"error": "image file is empty"})
            images.append((
                image_data,
                upload.filename or "image.png",
                upload.content_type or "image/png",
            ))
        try:
            draft_prompt = await run_in_threadpool(draft_prompt_from_images, images)
        except ValueError as exc:
            raise _bad_request(exc) from exc
        except Exception as exc:
            raise _bad_gateway(exc) from exc
        return {"item": {"draft_prompt": draft_prompt}}

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
