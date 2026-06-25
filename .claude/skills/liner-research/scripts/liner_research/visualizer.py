"""Liner Visualization endpoint client (SSE).

Endpoint:
  POST https://platform.liner.com/api/v1/tools/visualization
  Headers: x-api-key, Accept: text/event-stream, Content-Type: application/json
  Body  : {query, is_search_context, max_results}

Response is an SSE stream of `event:data` / `data:{json}` pairs plus `:ping`
keepalives. Each `data:` payload has a `type` field we care about:
  - "start" / "start-step" / "finish-step" : lifecycle markers
  - "data-search-references"               : cited references for the visualization
  - "data-atlas"                           : the final atlas artifact (HTML)
  - "data-text" / "data-reasoning"         : optional supporting narrative
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import httpx

from .config import CONFIG


class LinerVisualizerError(RuntimeError):
    """Raised when the visualization endpoint fails or is misconfigured."""


VISUALIZATION_PATH = "/api/v1/tools/visualization"


class LinerVisualizer:
    def __init__(self, *, api_key: str | None = None, base_url: str | None = None) -> None:
        self.api_key = api_key or CONFIG.liner_api_key
        self.base_url = (base_url or CONFIG.liner_base_url).rstrip("/")

    def _headers(self) -> dict[str, str]:
        if not self.api_key:
            raise LinerVisualizerError(
                "LINER_API_KEY / LINER_APIKEY is not set. Add it to .env."
            )
        return {
            "x-api-key": self.api_key,
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
        }

    def stream(
        self,
        query: str,
        *,
        is_search_context: bool = True,
        max_results: int = 10,
        timeout_s: float = 120.0,
    ) -> "VisualizationStream":
        """Open an SSE stream to the visualization endpoint.

        Returns a VisualizationStream context manager that yields parsed events.
        """
        payload = {
            "query": query,
            "is_search_context": is_search_context,
            "max_results": max(1, min(50, int(max_results))),
        }
        url = f"{self.base_url}{VISUALIZATION_PATH}"
        client = httpx.Client(timeout=httpx.Timeout(timeout_s, connect=10.0))
        req = client.build_request("POST", url, headers=self._headers(), json=payload)
        resp = client.send(req, stream=True)
        if resp.status_code >= 400:
            body = resp.read().decode("utf-8", errors="replace")[:500]
            resp.close()
            client.close()
            raise LinerVisualizerError(
                f"Liner {resp.status_code} {VISUALIZATION_PATH}: {body}"
            )
        return VisualizationStream(client, resp, query=query)


class VisualizationStream:
    """Context manager wrapping the SSE response. Iterate via `.events()`."""

    def __init__(self, client: httpx.Client, resp: httpx.Response, *, query: str) -> None:
        self.client = client
        self.resp = resp
        self.query = query

    def __enter__(self) -> "VisualizationStream":
        return self

    def __exit__(self, *exc: Any) -> None:
        self.close()

    def close(self) -> None:
        try:
            self.resp.close()
        finally:
            self.client.close()

    def events(self) -> "list[dict]":
        """Consume the SSE stream and return the parsed `data:` payloads."""
        out: list[dict] = []
        event_name: str | None = None
        for raw in self.resp.iter_lines():
            if raw is None:
                continue
            line = raw.decode("utf-8", errors="replace") if isinstance(raw, bytes) else raw
            if not line:
                event_name = None
                continue
            if line.startswith(":"):
                # SSE comment / keepalive.
                continue
            if line.startswith("event:"):
                event_name = line.split(":", 1)[1].strip()
                continue
            if line.startswith("data:"):
                payload = line.split(":", 1)[1].strip()
                try:
                    parsed = json.loads(payload)
                except json.JSONDecodeError:
                    parsed = {"raw": payload}
                parsed["_event"] = event_name
                out.append(parsed)
        return out


def write_outputs(
    events: list[dict],
    *,
    query: str,
    out_dir: Path,
    stem: str,
) -> dict[str, Path]:
    """Persist the visualization artifacts: HTML atlas, raw JSONL stream, references."""
    out_dir.mkdir(parents=True, exist_ok=True)

    html_path = out_dir / f"{stem}.atlas.html"
    stream_path = out_dir / f"{stem}.stream.jsonl"
    refs_path = out_dir / f"{stem}.references.json"

    # Raw stream.
    stream_path.write_text(
        "\n".join(json.dumps(e, ensure_ascii=False) for e in events) + "\n",
        encoding="utf-8",
    )

    # References.
    refs: list[dict] = []
    for e in events:
        if e.get("type") == "data-search-references":
            data = e.get("data") or {}
            for r in data.get("references") or []:
                refs.append(
                    {
                        "title": r.get("title"),
                        "url": r.get("url"),
                        "snippet": r.get("description") or r.get("snippet"),
                    }
                )

    # Final HTML atlas.
    atlas_html: str | None = None
    for e in reversed(events):
        if e.get("type") == "data-atlas":
            data = e.get("data") or {}
            artifact = data.get("atlasArtifact") or {}
            html = artifact.get("html")
            if html:
                atlas_html = html
                break

    if atlas_html:
        html_doc = (
            f"<!doctype html><html lang='en'><head><meta charset='utf-8'>"
            f"<title>Liner Atlas — {query}</title></head>"
            f"<body><h1>Liner Atlas: {query}</h1>{atlas_html}</body></html>"
        )
        html_path.write_text(html_doc, encoding="utf-8")

    refs_path.write_text(
        json.dumps(
            {"query": query, "count": len(refs), "references": refs},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    return {
        **({"html": html_path} if atlas_html else {}),
        "stream": stream_path,
        "references": refs_path,
    }