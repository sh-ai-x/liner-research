---
name: liner-visualize
description: Generate an interactive Liner Atlas visualization for a research topic. Streams the Liner /api/v1/tools/visualization SSE endpoint, captures the rendered HTML atlas, references, and raw event stream, and saves them to research_output/. Use when the user says "/liner-visualize", "visualize this", "atlas로 보여줘", "시각화해줘", or after a /liner-research run to produce a browsable visual artifact.
---

# Liner Visualize Skill

Streams Liner's `/api/v1/tools/visualization` endpoint (SSE) and saves:
- `*.atlas.html` — the interactive atlas HTML artifact
- `*.references.json` — cited references surfaced during generation
- `*.stream.jsonl` — raw SSE events for debugging / replay

## Trigger phrases
- `/liner-visualize [query]`
- "visualize this", "atlas로 보여줘", "시각화"
- After `/liner-research`, "이거 시각화해줘"

## When to use
- The user wants a visual / browsable artifact rather than Markdown bullets.
- A `LINER_API_KEY` exists in `.env`.
- An existing goal JSON is preferred so the visualization reuses the converged query.

## Environment

Same as the `liner-research` skill:
```bash
source /Users/sanghee/dev/research/.venv/bin/activate
```

## Workflow

### 1 — Pick the query

Prefer the `--goal-json` route so the visualization reuses the converged query (first `suggested_queries[0]` or `goal`). Otherwise accept a free-text `--query`.

### 2 — Run the visualization

```bash
python /Users/sanghee/dev/research/.claude/skills/liner-research/scripts/research.py visualize \
  --goal-json /tmp/liner-goal.json \
  --out-dir /Users/sanghee/dev/research/research_output
```

or with a free-text query:
```bash
python /Users/sanghee/dev/research/.claude/skills/liner-research/scripts/research.py visualize \
  --query "salicylic acid comedone RCT" \
  --max-results 10 \
  --out-dir /Users/sanghee/dev/research/research_output
```

Flags:
- `--max-results` (1–50, default 10)
- `--search-context` / `--no-search-context` (default on — Liner pulls live references to ground the atlas)
- `--timeout` seconds (default 120)
- `--stem` filename prefix

### 3 — Open the result

```bash
open /Users/sanghee/dev/research/research_output/<stem>.atlas.html
```

The atlas is self-contained HTML — open in any browser.

## Reusing after /liner-research

Once `/liner-research` has produced a goal JSON at `/tmp/liner-goal.json` (or any path), this skill can render the atlas in one command without re-running the Socratic loop.

## Failure modes

- 401 / Invalid token → same as `liner-research`: re-check `.env` and key activation.
- Empty events → endpoint returned only pings; check `--max-results` and try a different query.
- Network timeout → bump `--timeout`; the visualization endpoint is a streamed generation job.

## Style

- Keep the response short: which file was generated, the event count, and an `open` suggestion.
- Korean is fine.

## Files

```
.claude/skills/liner-visualize/
└── SKILL.md                          (this file)

# Reuses code from the sibling skill:
.claude/skills/liner-research/scripts/
├── research.py                       (CLI: visualize subcommand)
└── liner_research/
    └── visualizer.py                 (SSE parser + writer)
```