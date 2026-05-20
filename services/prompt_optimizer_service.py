from __future__ import annotations

from services.protocol.conversation import (
    ConversationRequest,
    stream_text_deltas,
    text_backend,
)


_SYSTEM_PROMPT = (
    "You are an expert prompt engineer for image generation. Expand short, "
    "possibly Chinese user ideas into one polished English prompt. Preserve the "
    "user's intent, avoid adding unsafe or irrelevant content, and include "
    "visual details such as composition, lighting, materials, color palette, "
    "camera view, and style. Return only the optimized prompt text."
)


def _clean_prompt(text: str) -> str:
    prompt = str(text or "").strip()
    if prompt.startswith("```"):
        prompt = prompt.strip("`").strip()
    lowered = prompt.lower()
    for prefix in ("prompt:", "optimized prompt:", "image prompt:"):
        if lowered.startswith(prefix):
            prompt = prompt[len(prefix) :].strip()
            break
    return prompt.strip().strip('"')


def optimize_image_prompt(prompt: str) -> str:
    source = str(prompt or "").strip()
    if not source:
        raise ValueError("prompt is required")

    request = ConversationRequest(
        model="auto",
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Optimize this idea into a concise production-ready image "
                    f"generation prompt under 120 words:\n\n{source}"
                ),
            },
        ],
    )
    text = "".join(
        stream_text_deltas(
            text_backend(),
            request,
        )
    )
    optimized = _clean_prompt(text)
    if not optimized:
        raise RuntimeError("prompt optimization failed")
    return optimized
