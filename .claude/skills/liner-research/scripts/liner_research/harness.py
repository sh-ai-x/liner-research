"""End-to-end orchestration: Ralph loop → Liner research → summarize → save.

For Liner we now expose two real tool paths:
  - tool="scholar" → /api/v1/tools/search/scholar  (academic / dermatology RCTs)
  - tool="web"     → /api/v1/tools/search/web      (general web)

The harness runs scholar for the primary query and web for follow-ups.
"""
from __future__ import annotations

from pathlib import Path

from rich.console import Console
from rich.panel import Panel

from .config import CONFIG
from .liner_client import LinerClient, LinerError
from .ralph_loop import RalphState, run as ralph_run
from .summarizer import summarize, write_outputs

console = Console()


def run_harness(
    *,
    seed: str,
    depth: int = 5,
    out_dir: Path | None = None,
    stem: str | None = None,
    visualize: bool = True,
    skip_ralph: bool = False,
    goal_override: dict | None = None,
) -> dict:
    """Drive the full pipeline and return the artifact paths plus the goal.

    Args:
        seed: original research seed (for logging).
        depth: 1-10; mapped to `max_results = depth * 5` (capped 50).
        out_dir: directory to write the artifacts (default: project root/research_output).
        stem: filename stem override.
        visualize: also write a Mermaid mind-map.
        skip_ralph: skip the Socratic loop (requires goal_override).
        goal_override: pre-built goal dict to bypass Ralph.
    """
    out_dir = out_dir or CONFIG.output_dir
    if skip_ralph and goal_override is None:
        raise ValueError("skip_ralph=True requires goal_override")

    if goal_override is not None:
        goal = goal_override
        console.print(Panel.fit("[cyan]Using supplied goal[/cyan]", border_style="cyan"))
    else:
        state = RalphState(seed=seed)
        goal = ralph_run(
            state,
            max_wonder=CONFIG.max_wonder_rounds,
            max_refine=CONFIG.max_refine_rounds,
        )

    client = LinerClient()
    max_results = max(1, min(50, depth * 5))
    queries = list(goal.get("suggested_queries") or [])
    primary_query = queries[0] if queries else goal.get("goal") or seed
    console.print(
        Panel.fit(
            f"[bold green]Liner scholar[/bold green]\nquery: {primary_query}",
            border_style="green",
        )
    )

    raw: dict = {}
    per_query: list[dict] = []
    try:
        raw = client.search(primary_query, tool="scholar", max_results=max_results)
        per_query.append({"query": primary_query, "tool": "scholar", "result": raw})
        # Follow-up queries use web search for breadth.
        for q in queries[1:3]:
            try:
                r = client.search(q, tool="web", max_results=max(5, max_results // 2))
                per_query.append({"query": q, "tool": "web", "result": r})
            except LinerError as exc:
                console.print(f"[yellow]follow-up query failed:[/yellow] {exc}")
    except LinerError as exc:
        console.print(f"[red]Liner error:[/red] {exc}")
        console.print(
            "[yellow]Continuing with empty result set so the harness can still "
            "produce a scaffolded report and goal.json.[/yellow]"
        )

    summary = summarize(goal, raw if raw else {"results": []})
    paths = write_outputs(
        goal,
        summary,
        mode="scholar+web",
        depth=depth,
        out_dir=out_dir,
        stem=stem,
        visualize=visualize,
    )

    console.print("[bold green]Saved:[/bold green]")
    for label, p in paths.items():
        console.print(f"  • {label}: {p}")
    return {
        "goal": goal,
        "paths": {k: str(v) for k, v in paths.items()},
        "queries": per_query,
    }