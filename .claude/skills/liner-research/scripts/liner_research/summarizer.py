"""Summarize Liner results and emit a Markdown report + optional Mermaid diagram."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from . import llm
from .liner_client import normalize_results


SUMMARY_SYSTEM = """\
You are a research analyst.
Given the user's research goal and the Liner API's raw response, write a concise, \
fact-grounded Markdown brief that:
  - opens with a 1-2 sentence headline finding
  - lists 4-7 bullet findings, each citing a source title + URL inline as [title](url)
  - ends with a "Open questions" section (2-4 bullets)
  - avoids speculation not supported by the sources
Do not invent sources. Only cite items provided in the payload.
"""


def summarize(goal: dict, raw_liner: dict) -> dict:
    normalized = normalize_results(raw_liner)
    user = (
        "Research goal:\n"
        + json.dumps(goal, ensure_ascii=False, indent=2)
        + "\n\nLiner response (normalized):\n"
        + json.dumps(
            {k: v for k, v in normalized.items() if k != "raw"},
            ensure_ascii=False,
            indent=2,
        )
    )
    md = llm.messages(
        system=SUMMARY_SYSTEM,
        messages=[{"role": "user", "content": user}],
        max_tokens=2500,
        temperature=0.2,
    )
    return {"normalized": normalized, "summary_md": md}


def render_report(goal: dict, summary: dict, *, mode: str, depth: int) -> str:
    norm = summary["normalized"]
    items = norm["items"]
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    md: list[str] = []
    md.append(f"# {goal.get('goal', 'Research Brief').strip()}")
    md.append("")
    md.append(f"_Generated {now} · mode=`{mode}` · depth={depth}_")
    md.append("")
    md.append("## Goal")
    md.append("")
    md.append(f"> {goal.get('goal', '')}")
    if goal.get("scope_in"):
        md.append("\n**Scope in**")
        md.extend(f"- {s}" for s in goal["scope_in"])
    if goal.get("scope_out"):
        md.append("\n**Scope out**")
        md.extend(f"- {s}" for s in goal["scope_out"])
    if goal.get("success_criteria"):
        md.append("\n**Success criteria**")
        md.extend(f"- {s}" for s in goal["success_criteria"])

    md.append("\n## Findings")
    md.append("")
    md.append(summary["summary_md"].strip())

    md.append("\n## Sources")
    md.append("")
    if not items:
        md.append("_No items returned by Liner._")
    for i, it in enumerate(items, start=1):
        title = it["title"] or "(untitled)"
        url = it["url"] or "(no url)"
        snippet = (it.get("snippet") or "").strip().replace("\n", " ")
        if len(snippet) > 240:
            snippet = snippet[:237] + "..."
        md.append(f"{i}. [{title}]({url})")
        if snippet:
            md.append(f"   - {snippet}")

    md.append("\n## Suggested follow-ups")
    md.append("")
    for q in goal.get("suggested_queries") or []:
        md.append(f"- `{q}`")

    md.append("")
    return "\n".join(md)


def render_mermaid(goal: dict, summary: dict) -> str:
    """Optional visualization: a Mermaid mind-map of goal → themes → sources."""
    norm = summary["normalized"]
    items = norm["items"][:8]
    lines: list[str] = ["```mermaid", "mindmap", "  root((Research Goal))"]
    label = (goal.get("goal") or "Research").replace("(", "[").replace(")", "]")[:60]
    lines.append(f"    {label}")
    # Group sources by URL host (cheap theme extraction).
    groups: dict[str, list[dict]] = {}
    for it in items:
        host = _host_of(it["url"]) or "misc"
        groups.setdefault(host, []).append(it)
    for host, group in list(groups.items())[:6]:
        host_clean = host.replace(".", "_").replace("-", "_")
        lines.append(f"    {host_clean}[{host}]")
        for it in group[:3]:
            t = (it["title"] or "untitled").replace("(", "[").replace(")", "]")[:40]
            lines.append(f"      {host_clean}{abs(hash(it['url']))%1000}[{t}]")
    lines.append("```")
    return "\n".join(lines)


def _host_of(url: str) -> str | None:
    if not url:
        return None
    try:
        return urlparse(url).netloc or None
    except Exception:
        return None


def write_outputs(
    goal: dict,
    summary: dict,
    *,
    mode: str,
    depth: int,
    out_dir: Path,
    stem: str | None = None,
    visualize: bool = True,
) -> dict[str, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    stem = stem or f"research-{stamp}"

    md_path = out_dir / f"{stem}.md"
    mermaid_path = out_dir / f"{stem}.mermaid.md"
    raw_path = out_dir / f"{stem}.liner.json"
    goal_path = out_dir / f"{stem}.goal.json"

    md_path.write_text(render_report(goal, summary, mode=mode, depth=depth), encoding="utf-8")
    goal_path.write_text(json.dumps(goal, ensure_ascii=False, indent=2), encoding="utf-8")
    raw_path.write_text(
        json.dumps(summary["normalized"], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    if visualize:
        mermaid_path.write_text(
            f"# Mind map — {goal.get('goal', '')}\n\n" + render_mermaid(goal, summary),
            encoding="utf-8",
        )
    return {
        "md": md_path,
        "goal": goal_path,
        "raw": raw_path,
        **({"mermaid": mermaid_path} if visualize else {}),
    }