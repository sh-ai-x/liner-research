"""Socratic goal-convergence loop: Wonder → Refine → Discussing.

- Wonder    : Claude expands the seed into multiple meaning candidates.
- Refine    : Claude narrows candidates by comparing them against the user's last reply.
- Discussing: Claude rephrases the converged intent as an executable research goal.

The loop terminates when:
  * the goal passes an internal LLM rubric (specific, scoped, actionable), OR
  * the user types `/done`, OR
  * max rounds are exhausted.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel

from . import llm

console = Console()


WONDER_SYSTEM = """\
You are a Socratic research strategist.
Given a user's research seed, surface 3-6 distinct interpretations of what they \
might mean. Each interpretation must include:
  - "label": 2-5 word short name
  - "claim": one-sentence statement of that interpretation
  - "signal": what user wording pointed you there
  - "research_angle": a concrete angle a researcher would pursue

Respond ONLY with a JSON array of objects. No prose, no markdown fences.
"""

REFINE_SYSTEM = """\
You are a Socratic research strategist.
You are narrowing down interpretations of a research goal.

User wording so far:
---
{user_context}
---

Candidate interpretations:
---
{candidates}
---

Compare each candidate against the user's most recent reply. Decide:
  - "kept": interpretations still consistent
  - "pruned": interpretations the user implicitly rejected
  - "new": new interpretations born from the user's reply

Then ask EXACTLY ONE short Socratic question (under 20 words) that surfaces the \
most decision-relevant ambiguity. Do not offer options. Ask a question whose \
answer materially narrows the goal.

Respond ONLY with JSON:
{{"kept": [...], "pruned": [...], "new": [...], "question": "..."}}
Keep the SAME shape as the original interpretation objects.
"""

DISCUSSING_SYSTEM = """\
You are restating a converged research intent as an executable goal.
The user has iterated through several Socratic rounds; the current narrowed scope is:

{scope}

Write:
  - "goal": one sentence, action verb + target + constraint
  - "scope_in": list of strings, what is in scope
  - "scope_out": list of strings, what is explicitly out of scope
  - "deliverables": list of strings, concrete outputs the research must produce
  - "success_criteria": list of strings, how we know the research succeeded
  - "suggested_queries": list of 2-4 search queries that would surface evidence

Respond ONLY with JSON.
"""


RUBRIC_SYSTEM = """\
You evaluate a research goal against three criteria:
  1. specific — names a concrete target (technology, audience, time window, etc.)
  2. scoped   — has explicit in/out boundaries
  3. actionable — can be executed as a web search with clear deliverables

Goal:
---
{goal}
---

Reply with JSON: {{"specific": bool, "scoped": bool, "actionable": bool, \
"missing": [str], "verdict": "ready" | "needs_more"}}
"""


@dataclass
class RalphState:
    seed: str
    user_context: list[str] = field(default_factory=list)
    candidates: list[dict] = field(default_factory=list)
    rounds: int = 0
    converged_goal: dict | None = None

    def add_user(self, text: str) -> None:
        self.user_context.append(text)


def _extract_json(text: str) -> object:
    text = text.strip()
    fence = re.search(r"```(?:json)?\s*(\[[\s\S]*?\]|\{[\s\S]*?\})\s*```", text)
    if fence:
        text = fence.group(1)
    else:
        match = re.search(r"(\[[\s\S]*\]|\{[\s\S]*\})", text)
        if match:
            text = match.group(1)
    return json.loads(text)


def _wonder(seed: str) -> list[dict]:
    raw = llm.messages(system=WONDER_SYSTEM, messages=[{"role": "user", "content": seed}])
    parsed = _extract_json(raw)
    if not isinstance(parsed, list):
        raise ValueError("Wonder did not return a JSON array")
    return parsed


def _refine(state: RalphState) -> tuple[list[dict], list[dict], list[dict], str]:
    user_ctx = "\n".join(f"- {u}" for u in state.user_context) or "(initial seed only)"
    cands = json.dumps(state.candidates, ensure_ascii=False, indent=2)
    raw = llm.messages(
        system=REFINE_SYSTEM.format(user_context=user_ctx, candidates=cands),
        messages=[{"role": "user", "content": state.user_context[-1] or state.seed}],
    )
    parsed = _extract_json(raw)
    if not isinstance(parsed, dict):
        raise ValueError("Refine did not return a JSON object")
    return (
        parsed.get("kept") or [],
        parsed.get("pruned") or [],
        parsed.get("new") or [],
        parsed.get("question") or "What outcome would make this research feel complete?",
    )


def _restate(state: RalphState) -> dict:
    scope = {
        "seed": state.seed,
        "user_replies": state.user_context,
        "candidates": state.candidates,
    }
    raw = llm.messages(
        system=DISCUSSING_SYSTEM.format(scope=json.dumps(scope, ensure_ascii=False, indent=2)),
        messages=[{"role": "user", "content": "Restate the goal now."}],
    )
    parsed = _extract_json(raw)
    if not isinstance(parsed, dict):
        raise ValueError("Discussing did not return a JSON object")
    return parsed


def _rubric(goal: dict) -> dict:
    raw = llm.messages(
        system=RUBRIC_SYSTEM.format(goal=json.dumps(goal, ensure_ascii=False, indent=2)),
        messages=[{"role": "user", "content": "Evaluate."}],
        temperature=0.0,
    )
    parsed = _extract_json(raw)
    if not isinstance(parsed, dict):
        return {"specific": False, "scoped": False, "actionable": False, "verdict": "needs_more"}
    return parsed


def run(state: RalphState, *, max_wonder: int, max_refine: int) -> dict:
    """Run the Wonder → Refine → Discussing loop interactively. Returns the converged goal."""
    console.print(
        Panel.fit(
            f"[bold cyan]Wonder → Refine → Discussing[/bold cyan]\n[dim]seed:[/dim] {state.seed}",
            border_style="cyan",
        )
    )

    # Wonder pass.
    state.candidates = _wonder(state.seed)
    state.rounds = 1
    console.print(f"\n[bold]Round {state.rounds} — Wonder[/bold]")
    console.print(_render_candidates(state.candidates))

    # Refine / Discussing passes.
    while state.rounds <= max_wonder + max_refine:
        # Refine.
        kept, pruned, newly, question = _refine(state)
        # Merge: kept replaces current; new are appended.
        state.candidates = list(kept) + list(newly)
        console.print(f"\n[bold]Refine[/bold]")
        if pruned:
            console.print(
                f"[dim]pruned:[/dim] " + ", ".join(p.get("label", "?") for p in pruned)
            )
        console.print(f"[yellow]Socratic Q:[/yellow] {question}")

        reply = console.input("\n[bold green]you >[/bold green] ").strip()
        if reply.lower() in {"/done", "done", "stop", "quit"}:
            break
        if reply:
            state.add_user(reply)

        # Discussing (restate + rubric).
        candidate_goal = _restate(state)
        verdict = _rubric(candidate_goal)
        console.print(
            Panel(
                Markdown(_render_goal_md(candidate_goal) + _render_verdict(verdict)),
                border_style="magenta",
            )
        )
        if verdict.get("verdict") == "ready":
            state.converged_goal = candidate_goal
            break

        # Seed refinement for the next round.
        if reply.lower() in {"/refine", "refine"}:
            state.candidates = _wonder(reply)
        state.rounds += 1

    if state.converged_goal is None:
        # Force a final restate even if rubric never said ready.
        state.converged_goal = _restate(state)
    return state.converged_goal


def _render_candidates(cands: list[dict]) -> str:
    lines = []
    for c in cands:
        lines.append(f"- **{c.get('label', '?')}** — {c.get('claim', '')}")
        if c.get("signal"):
            lines.append(f"  - signal: {c['signal']}")
        if c.get("research_angle"):
            lines.append(f"  - angle: {c['research_angle']}")
    return "\n".join(lines) if lines else "(no candidates)"


def _render_goal_md(goal: dict) -> str:
    md = [f"## {goal.get('goal', '(no goal)')}", ""]
    if goal.get("scope_in"):
        md.append("**Scope in**")
        md.extend(f"- {s}" for s in goal["scope_in"])
    if goal.get("scope_out"):
        md.append("\n**Scope out**")
        md.extend(f"- {s}" for s in goal["scope_out"])
    if goal.get("deliverables"):
        md.append("\n**Deliverables**")
        md.extend(f"- {s}" for s in goal["deliverables"])
    if goal.get("success_criteria"):
        md.append("\n**Success criteria**")
        md.extend(f"- {s}" for s in goal["success_criteria"])
    if goal.get("suggested_queries"):
        md.append("\n**Suggested queries**")
        for q in goal["suggested_queries"]:
            md.append(f"- `{q}`")
    return "\n".join(md)


def _render_verdict(verdict: dict) -> str:
    bits = [f"\n_verdict: **{verdict.get('verdict', '?')}**_"]
    if verdict.get("missing"):
        bits.append("\n_missing:_")
        bits.extend(f"- {m}" for m in verdict["missing"])
    return "\n".join(bits)