"""Pipeline entry point used by the liner-research skill.

The skill itself drives the Wonder -> Refine -> Discussing loop with the user.
Once the goal converges, the skill writes a goal JSON file and invokes:

    python research.py run-pipeline --goal-json <path> --mode <search|deep> --depth N

This script reads that goal JSON, calls Liner, summarizes, and writes the artifacts.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from liner_research.config import CONFIG
from liner_research.harness import run_harness


def _cmd_run_pipeline(args: argparse.Namespace) -> int:
    if not args.goal_json.exists():
        print(f"goal JSON not found: {args.goal_json}", file=sys.stderr)
        return 2
    goal = json.loads(args.goal_json.read_text(encoding="utf-8"))
    result = run_harness(
        seed=args.seed or goal.get("goal", ""),
        depth=args.depth,
        out_dir=args.out_dir,
        stem=args.stem,
        visualize=not args.no_visualize,
        skip_ralph=True,
        goal_override=goal,
    )
    print(json.dumps({"paths": result["paths"], "goal": result["goal"]}, ensure_ascii=False, indent=2))
    return 0


def _cmd_wonder(args: argparse.Namespace) -> int:
    """Single-shot Wonder pass — used by the skill to bootstrap candidate interpretations."""
    from liner_research.ralph_loop import _wonder

    candidates = _wonder(args.seed)
    print(json.dumps(candidates, ensure_ascii=False, indent=2))
    return 0


def _cmd_restate(args: argparse.Namespace) -> int:
    """Single-shot restate — used by the skill once the Socratic dialog converges."""
    from liner_research.ralph_loop import _restate, _rubric, RalphState

    state = RalphState(
        seed=args.seed,
        user_context=json.loads(args.user_context or "[]"),
        candidates=json.loads(args.candidates or "[]"),
    )
    goal = _restate(state)
    rubric = _rubric(goal)
    print(json.dumps({"goal": goal, "rubric": rubric}, ensure_ascii=False, indent=2))
    return 0


def _cmd_visualize(args: argparse.Namespace) -> int:
    """Stream Liner visualization and persist the atlas HTML + raw events."""
    from liner_research.visualizer import LinerVisualizer, write_outputs
    from datetime import datetime, timezone

    if args.goal_json:
        goal = json.loads(args.goal_json.read_text(encoding="utf-8"))
        query = args.query or (goal.get("suggested_queries") or [goal.get("goal")])[0]
    else:
        query = args.query
        goal = None

    if not query:
        print("--query or --goal-json required", file=sys.stderr)
        return 2

    out_dir = args.out_dir or CONFIG.output_dir
    stem = args.stem or f"atlas-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}"

    client = LinerVisualizer()
    print(f"[visualize] query={query!r}  is_search_context={args.search_context}  max_results={args.max_results}")
    with client.stream(
        query,
        is_search_context=args.search_context,
        max_results=args.max_results,
        timeout_s=args.timeout,
    ) as stream:
        events = stream.events()
    paths = write_outputs(events, query=query, out_dir=out_dir, stem=stem)
    print(json.dumps({"query": query, "events": len(events), "paths": {k: str(v) for k, v in paths.items()}}, ensure_ascii=False, indent=2))
    return 0


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(prog="liner-research")
    sub = p.add_subparsers(dest="cmd", required=True)

    rp = sub.add_parser("run-pipeline", help="Run Liner + summarize + save from a goal JSON.")
    rp.add_argument("--goal-json", type=Path, required=True)
    rp.add_argument("--seed", help="Original seed (for logging only).")
    rp.add_argument("--depth", type=int, default=5, help="1-10, mapped to Liner max_results = depth*5.")
    rp.add_argument("--out-dir", type=Path)
    rp.add_argument("--stem")
    rp.add_argument("--no-visualize", action="store_true")
    rp.set_defaults(func=_cmd_run_pipeline)

    wp = sub.add_parser("wonder", help="Bootstrap candidate interpretations for a seed.")
    wp.add_argument("--seed", required=True)
    wp.set_defaults(func=_cmd_wonder)

    rs = sub.add_parser("restate", help="Restate scope into a goal + rubric.")
    rs.add_argument("--seed", required=True)
    rs.add_argument("--user-context", help="JSON list of user replies.")
    rs.add_argument("--candidates", help="JSON list of current candidates.")
    rs.set_defaults(func=_cmd_restate)

    vz = sub.add_parser("visualize", help="Stream Liner visualization (SSE) and save the atlas HTML.")
    vz.add_argument("--query", help="Visualization query. Defaults to first suggested_query of --goal-json.")
    vz.add_argument("--goal-json", type=Path, help="Reuse the query from a saved goal JSON.")
    vz.add_argument("--max-results", type=int, default=10)
    vz.add_argument("--search-context", dest="search_context", action="store_true", default=True)
    vz.add_argument("--no-search-context", dest="search_context", action="store_false")
    vz.add_argument("--timeout", type=float, default=120.0)
    vz.add_argument("--out-dir", type=Path)
    vz.add_argument("--stem")
    vz.set_defaults(func=_cmd_visualize)

    return p.parse_args()


def main() -> int:
    return _parse_args().func(_parse_args())


if __name__ == "__main__":
    raise SystemExit(main())