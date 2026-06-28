# liner-research

Research automation skill powered by Liner (liner.com). Converges a research goal through a Claude-driven **Wonder → Refine → Discussing** Socratic loop, then calls the Liner search API to produce a Markdown brief and Mermaid mind-map.

## Triggers

```
/liner-research [seed]
"research X", "deep research on …"
```

## Pipeline

```
[seed] → Wonder → Refine → Discussing → goal.json
                                             ↓
                         python research.py run-pipeline
                                             ↓
                             Liner /api/v1/tools/search/scholar
                             Liner /api/v1/tools/search/web
                                             ↓
                         research_output/<stem>.md
                                         .mermaid.md
                                         .goal.json
                                         .liner.json
```

## Setup

`.env` (project root):

```
LINER_API_KEY=sk_live_...
ANTHROPIC_API_KEY=...
```

Activate virtualenv:

```bash
source /Users/sanghee/dev/research/.venv/bin/activate
```

## CLI

All commands run from the `scripts/` directory:

```bash
# Phase 0 — Wonder (generate interpretation candidates)
python research.py wonder --seed "your topic"

# Phase 2 — Restate (converge goal + rubric)
python research.py restate --seed "your topic" \
  --user-context '["reply 1", "reply 2"]' \
  --candidates '[{"label":"...","claim":"..."}]'

# Phase 3 — Pipeline (Liner search + summarize + save)
python research.py run-pipeline --goal-json /tmp/goal.json --depth 5

# Visualize (Atlas HTML)
python research.py visualize --query "your topic"
python research.py visualize --goal-json /tmp/goal.json
```

## File Structure

```
.claude/skills/liner-research/
├── SKILL.md
└── scripts/
    ├── research.py
    └── liner_research/
        ├── config.py
        ├── llm.py
        ├── ralph_loop.py
        ├── liner_client.py
        ├── visualizer.py
        ├── summarizer.py
        └── harness.py
```

## Related Skills

- `/liner-visualize` — generates an interactive Liner Atlas HTML from a converged goal JSON or a free-text query
