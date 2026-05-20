from __future__ import annotations

from services.protocol.conversation import (
    ConversationRequest,
    stream_text_deltas,
    text_backend,
)


_SYSTEM_PROMPT = (
    "You are an expert image-generation prompt engineer. "
    "Given the uploaded image, reverse-engineer one polished English prompt "
    "that can recreate a similar image. Include subject, composition, lighting, "
    "materials, color palette, background, camera or lens details when useful, "
    "and style cues. Return only the prompt text, with no preface."
)

_USER_PROMPT = (
    "Analyze the attached image and write a concise, production-ready image "
    "generation prompt. Keep it under 120 words."
)


def _clean_prompt(text: str) -> str:
    prompt = str(text or "").strip()
    if prompt.startswith("```"):
        prompt = prompt.strip("`").strip()
    lowered = prompt.lower()
    for prefix in ("prompt:", "image prompt:", "draft prompt:"):
        if lowered.startswith(prefix):
            prompt = prompt[len(prefix) :].strip()
            break
    return prompt.strip().strip('"')


def draft_prompt_from_images(images: list[tuple[bytes, str, str]]) -> str:
    cleaned = [
        (data, filename or "image.png", content_type or "image/png")
        for data, filename, content_type in images
        if data
    ]
    if not cleaned:
        raise ValueError("image file is required")

    content: list[dict[str, object]] = [{"type": "text", "text": _USER_PROMPT}]
    for data, _, content_type in cleaned:
        content.append({"type": "image", "data": data, "mime": content_type})

    request = ConversationRequest(
        model="auto",
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": content},
        ],
    )
    text = "".join(
        stream_text_deltas(
            text_backend(),
            request,
        )
    )

    draft = _clean_prompt(text)
    if not draft:
        raise RuntimeError("image prompt draft failed")
    return draft
