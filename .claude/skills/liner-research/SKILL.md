---
name: liner-research
description: Research automation using Liner (liner.com) search/deep-research with a Claude-driven Wonder→Refine→Discussing Socratic loop. Converges a research goal with the user, calls Liner's tools-search endpoint, summarizes findings into a Markdown brief + Mermaid mind-map. Use when the user says "/liner-research", "research X with Liner", "조사해줘 (with Liner)", or asks for a deep, sourced briefing.
---

# Liner Research Skill

End-to-end research harness:

```
[seed] → Wonder → Refine → Discussing → goal.json
                                              ↓
                          python research.py run-pipeline
                                              ↓
                              Liner search / deep-research
                                              ↓
                          summarize → research_output/*.md
                                      *.mermaid.md
                                      *.liner.json
                                      *.goal.json
```

## Trigger phrases
- `/liner-research [seed]`
- "research X", "조사해줘", "Liner로 리서치"
- "deep research on …"

## When to invoke this skill

- User wants a multi-source research brief with citations.
- User is willing to answer 1–3 Socratic questions before the search runs.
- A `LINER_APIKEY` exists in `.env`.

If the user wants only the Socratic loop without calling Liner, run phases 1–3 only.

## Environment

The skill assumes `.env` in the project root contains:
```
LINER_API_KEY=sk_live_...
ANTHROPIC_API_KEY=...        # or ANTHROPIC_AUTH_TOKEN
ANTHROPIC_BASE_URL=...       # optional, default api.anthropic.com
```

A virtualenv is required (httpx, rich, python-dotenv). Use the project's `.venv`:
```bash
source /Users/sanghee/dev/research/.venv/bin/activate
```

All `python` commands in this skill MUST run from the `scripts/` directory so the
`liner_research` package resolves. Use absolute paths from CWD:
```
.claude/skills/liner-research/scripts/research.py
```

## Workflow

### Phase 0 — Bootstrap (skill entry)

1. If `--seed` is missing, ask the user: "What topic should we research?"
2. Run the Wonder bootstrap:
   ```bash
   python .claude/skills/liner-research/scripts/research.py wonder --seed "<seed>"
   ```
   This returns a JSON array of 3–6 interpretations.
3. Render them to the user as a brief bullet list (label + claim + angle).

### Phase 1 — Refine (Socratic loop)

For up to `MAX_REFINE_ROUNDS` (default 3):

1. Look at the user's latest reply (or the seed if first iteration).
2. Use `AskUserQuestion` to ask **exactly one** short Socratic question
   (< 20 words, no enumerated options — the question itself must do the work).
3. When the user answers, decide:
   - If their reply materially narrows the goal → continue.
   - If they type `/done` or `stop` → jump to Phase 2.
   - If their reply is empty / "?" → ask a more concrete question.

Track `user_context` (list of replies) and `candidates` (current kept list) across
rounds in your working memory; the goal JSON will need them.

### Phase 2 — Discussing (restate + rubric)

Once the dialog converges, restate and evaluate:

```bash
python .claude/skills/liner-research/scripts/research.py restate \
  --seed "<original seed>" \
  --user-context '<JSON list of replies>' \
  --candidates '<JSON list of current candidates>'
```

The output is `{goal: {...}, rubric: {specific, scoped, actionable, verdict}}`.

- If `rubric.verdict == "ready"` → proceed to Phase 3.
- Otherwise surface `rubric.missing` to the user and loop back to Phase 1
  (ask one more question targeted at the missing field).

### Phase 3 — Pipeline (Liner call + save)

1. Write the goal to `/tmp/liner-goal.json` using the Write tool.
2. Invoke the pipeline:
   ```bash
   python .claude/skills/liner-research/scripts/research.py run-pipeline \
     --goal-json /tmp/liner-goal.json \
     --depth 5        # 1-10; mapped to Liner max_results = depth*5
     --out-dir research_output
   ```
3. The script prints `{paths: {...}}` — read them and tell the user where the
   artifacts live (md / mermaid / raw / goal JSON).

The pipeline uses two Liner tool paths:
- `/api/v1/tools/search/scholar` — primary academic search
- `/api/v1/tools/search/web` — follow-up breadth searches

Both use the `x-api-key` header.

### Phase 4 — Report

Summarize back to the user:
- The converged goal in one sentence
- The mode + depth used
- The 4 artifact paths
- The headline finding from the generated `.md` (read it before reporting)

## Quick mode (no Socratic dialog)

If the user asks for a quick run (`/liner-research --auto <seed>` or "바로 해줘"):
1. Skip Phases 1–2.
2. Run restate with empty user-context to bootstrap a goal.
3. If rubric != ready, refine with one synthetic "broad scope" reply and re-restate.
4. Proceed to Phase 3.

## Failure modes

- `LINER_API_KEY` missing or invalid → the pipeline script still produces
  scaffolded artifacts (empty sources, "No source material was returned"
  finding). Surface this to the user and ask whether to retry with a valid key.
- `ANTHROPIC_API_KEY` missing → fail fast at Phase 0 with a clear message.
- Liner error on the search endpoint → the harness catches it, prints the
  message, and proceeds with an empty result set so the goal.json is preserved.

## Style

- Default to **Opus** for SKILL.md / goal-restate decisions, **Sonnet** for
  per-round Socratic questions (per user's `~/.claude/CLAUDE.md` model rules).
- Keep Socratic questions short and decision-relevant. Never offer enumerated
  options in the question — the question itself should force a choice.
- Korean is fine if the user writes in Korean.

## Files

```
.claude/skills/liner-research/
├── SKILL.md                          (this file)
└── scripts/
    ├── research.py                   (CLI: wonder | restate | run-pipeline | visualize)
    └── liner_research/               (Python package)
        ├── config.py                 (.env loader, find_dotenv-based)
        ├── llm.py                    (Anthropic Messages client)
        ├── ralph_loop.py             (Socratic primitives)
        ├── liner_client.py           (Liner /api/v1/tools/search/{scholar,web})
        ├── visualizer.py             (Liner /api/v1/tools/visualization SSE)
        ├── summarizer.py             (Markdown + Mermaid)
        └── harness.py                (orchestration)
```

## Companion skills

- `/liner-visualize` — reuses a converged goal JSON (or accepts a free-text
  query) to produce an interactive Liner Atlas HTML.