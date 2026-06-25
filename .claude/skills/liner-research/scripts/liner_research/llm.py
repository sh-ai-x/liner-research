"""Thin Anthropic Messages-API client.

Respects `ANTHROPIC_BASE_URL` so it works against api.anthropic.com or any
compatible gateway (e.g., the project's `ANTHROPIC_BASE_URL`).
"""
from __future__ import annotations

import os

import httpx

from .config import CONFIG


class LLMError(RuntimeError):
    """Raised when the LLM endpoint returns a non-2xx or malformed payload."""


def _headers() -> dict[str, str]:
    api_key = CONFIG.anthropic_api_key or os.getenv("ANTHROPIC_AUTH_TOKEN")
    if not api_key:
        raise LLMError(
            "ANTHROPIC_API_KEY (or ANTHROPIC_AUTH_TOKEN) is not set. "
            "Add it to .env before running the harness."
        )
    return {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }


def messages(
    *,
    system: str,
    messages: list[dict],
    model: str | None = None,
    max_tokens: int = 2048,
    temperature: float = 0.7,
) -> str:
    """Call the Messages API and return the concatenated text content."""
    payload = {
        "model": model or CONFIG.anthropic_model,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "system": system,
        "messages": messages,
    }
    url = f"{(CONFIG.anthropic_base_url or 'https://api.anthropic.com').rstrip('/')}/v1/messages"
    with httpx.Client(timeout=httpx.Timeout(60.0, connect=10.0)) as client:
        resp = client.post(url, headers=_headers(), json=payload)
    if resp.status_code >= 400:
        raise LLMError(f"LLM {resp.status_code}: {resp.text[:500]}")
    parts: list[str] = []
    for block in (resp.json().get("content") or []):
        if block.get("type") == "text":
            parts.append(block.get("text", ""))
    return "".join(parts).strip()