"""Liner API client.

Real Liner Platform API (verified against `tools/search/web` and
`tools/search/scholar`):
  - Base URL : https://platform.liner.com
  - Auth     : `x-api-key: <key>`  header (NOT Bearer)
  - Body     : {query: str, max_results: int, ...}
  - Tool paths (selectable via `tool` arg):
      * "web"     → /api/v1/tools/search/web
      * "scholar" → /api/v1/tools/search/scholar
  - Response : {requestId, results: [{title, url, hostname, description, date,
                                       citationCount, authors, journal}]}
"""
from __future__ import annotations

from typing import Any

import httpx

from .config import CONFIG


class LinerError(RuntimeError):
    """Raised when the Liner endpoint returns a non-2xx response."""


_TOOL_PATHS = {
    "web": "/api/v1/tools/search/web",
    "scholar": "/api/v1/tools/search/scholar",
}


class LinerClient:
    def __init__(self, *, api_key: str | None = None, base_url: str | None = None) -> None:
        self.api_key = api_key or CONFIG.liner_api_key
        self.base_url = (base_url or CONFIG.liner_base_url).rstrip("/")

    def _headers(self) -> dict[str, str]:
        if not self.api_key:
            raise LinerError(
                "LINER_APIKEY / LINER_API_KEY is not set. Add it to .env."
            )
        return {
            "x-api-key": self.api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def search(
        self,
        query: str,
        *,
        tool: str = "scholar",
        max_results: int = 10,
        extra: dict[str, Any] | None = None,
    ) -> dict:
        """Single tool call.

        Args:
            query: search query string.
            tool: "scholar" (academic) or "web" (general). Default scholar.
            max_results: 1-50; Liner caps at 50.
            extra: additional JSON fields merged into the payload
                   (e.g., year_range, language).
        """
        if tool not in _TOOL_PATHS:
            raise ValueError(f"Unknown tool {tool!r}; choose from {list(_TOOL_PATHS)}")
        payload: dict[str, Any] = {
            "query": query,
            "max_results": max(1, min(50, int(max_results))),
        }
        if extra:
            payload.update(extra)
        url = f"{self.base_url}{_TOOL_PATHS[tool]}"
        with httpx.Client(timeout=httpx.Timeout(60.0, connect=10.0)) as client:
            resp = client.post(url, headers=self._headers(), json=payload)
        if resp.status_code >= 400:
            raise LinerError(f"Liner {resp.status_code} {_TOOL_PATHS[tool]}: {resp.text[:500]}")
        return resp.json()


def normalize_results(raw: dict, *, default_tool: str = "scholar") -> dict:
    """Reshape a Liner response into a stable internal shape:
      {query, tool, requestId, items: [...], raw}
    """
    items: list[dict] = []
    for entry in raw.get("results") or raw.get("items") or []:
        items.append(
            {
                "title": entry.get("title") or "(untitled)",
                "url": entry.get("url") or "",
                "hostname": entry.get("hostname") or "",
                "snippet": entry.get("description") or entry.get("snippet") or "",
                "date": entry.get("date"),
                "authors": entry.get("authors") or [],
                "journal": entry.get("journal"),
                "citation_count": entry.get("citationCount"),
            }
        )
    return {
        "query": raw.get("query") or "",
        "tool": default_tool,
        "request_id": raw.get("requestId"),
        "items": items,
        "raw": raw,
    }