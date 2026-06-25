# liner-research skill

Inside Claude Code, invoke with `/liner-research [seed]`.

## Pipeline

```
seed → Wonder → Refine → Discussing (rubric) → goal.json
                                              ↓
                            Liner /api/v1/tools/search/scholar
                            Liner /api/v1/tools/search/web
                                              ↓
                            research_output/<stem>.md
                                            .mermaid.md
                                            .goal.json
                                            .liner.json
```

## Standalone CLI

All commands run from `scripts/` (so the `liner_research` package resolves):

```bash
source /Users/sanghee/dev/research/.venv/bin/activate
cd /Users/sanghee/dev/research/.claude/skills/liner-research/scripts

# Phase 0 — bootstrap candidate interpretations
python research.py wonder --seed "your topic"

# Phase 2 — restate scope into a goal + rubric
python research.py restate --seed "your topic" \
  --user-context '["reply 1", "reply 2"]' \
  --candidates '[{"label":"...","claim":"..."}]'

# Phase 3 — run Liner + summarize + save (requires converged goal.json)
python research.py run-pipeline --goal-json /tmp/goal.json --depth 8

# Visualize (separate SSE endpoint, atlas HTML output)
python research.py visualize --query "your topic"
python research.py visualize --goal-json /tmp/goal.json
```

## Flags

| Subcommand | Flag | Default | Note |
|---|---|---|---|
| `wonder` | `--seed` | (required) | Research seed |
| `restate` | `--seed` | (required) | Original seed |
| `restate` | `--user-context` | `[]` | JSON list of replies |
| `restate` | `--candidates` | `[]` | JSON list of current candidates |
| `run-pipeline` | `--goal-json` | (required) | Path to goal JSON |
| `run-pipeline` | `--depth` | `5` | 1–10, mapped to `max_results = depth*5` |
| `run-pipeline` | `--out-dir` | `research_output/` | |
| `run-pipeline` | `--no-visualize` | (off) | Skip Mermaid mind-map |
| `visualize` | `--query` | – | Free-text query |
| `visualize` | `--goal-json` | – | Reuse first suggested_query |
| `visualize` | `--max-results` | `10` | 1–50 |
| `visualize` | `--search-context` / `--no-search-context` | on | Whether Liner grounds the atlas in live references |
| `visualize` | `--timeout` | `120.0` | Seconds |

## Endpoints used

- `POST /api/v1/tools/search/scholar` — primary academic search
- `POST /api/v1/tools/search/web` — follow-up general web search
- `POST /api/v1/tools/visualization` — SSE stream producing the atlas

All three use `x-api-key: <key>` header and JSON bodies.