# research — Liner-powered research harness

End-to-end automation that takes a research seed and produces an evidence-backed
Markdown brief + interactive Liner Atlas, all driven from Claude Code skills.

```
[seed]  →  /liner-research  →  Socratic goal convergence (Claude)
                                       ↓
                              Liner /api/v1/tools/search/scholar
                              Liner /api/v1/tools/search/web
                                       ↓
                              Markdown brief + Mermaid mind-map

[goal]  →  /liner-visualize →  Liner /api/v1/tools/visualization (SSE)
                                       ↓
                              Interactive HTML atlas
```

## Layout

```
.
├── .env                  # secrets (real, gitignored) — copy .env.example
├── .env.example          # template
├── .venv/                # python virtualenv (anthropic, httpx, rich, python-dotenv)
└── .claude/skills/
    ├── liner-research/   # /liner-research skill
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── requirements.txt
    │   └── scripts/
    │       ├── research.py
    │       └── liner_research/
    │           ├── config.py
    │           ├── llm.py
    │           ├── ralph_loop.py
    │           ├── liner_client.py
    │           ├── visualizer.py
    │           ├── summarizer.py
    │           └── harness.py
    └── liner-visualize/  # /liner-visualize skill
        └── SKILL.md
```

## Quick start

```bash
# 1. Install deps (already done if .venv exists)
source .venv/bin/activate
pip install -r .claude/skills/liner-research/requirements.txt

# 2. Configure secrets
cp .env.example .env  # then edit

# 3. Inside Claude Code
/liner-research "your topic here"
/liner-visualize                       # reuses the most recent goal.json
```

Or run standalone without Claude:

```bash
cd .claude/skills/liner-research/scripts
python research.py wonder --seed "your topic"
python research.py restate --seed "your topic" --user-context '[]' --candidates '[]'
python research.py run-pipeline --goal-json /tmp/goal.json --depth 8
python research.py visualize --query "your topic"
```

## Outputs

Written to `research_output/` (overridable via `RESEARCH_OUTPUT_DIR`):

- `research-<ts>.md` — Markdown brief
- `research-<ts>.mermaid.md` — Mermaid mind-map of sources
- `research-<ts>.liner.json` — raw Liner response
- `research-<ts>.goal.json` — converged research goal
- `atlas-<ts>.atlas.html` — interactive Liner Atlas
- `atlas-<ts>.stream.jsonl` — raw SSE events
- `atlas-<ts>.references.json` — collected references

## Required env

| Var | Used by |
|---|---|
| `LINER_API_KEY` (or `LINER_APIKEY`) | Liner search + visualization |
| `ANTHROPIC_API_KEY` (or `ANTHROPIC_AUTH_TOKEN`) | Socratic loop + summarization |
| `ANTHROPIC_BASE_URL` (optional) | Override Anthropic endpoint |
| `ANTHROPIC_MODEL` (optional) | Override default model |

## Custom `/open` slash command

`~/.claude/commands/open.md` opens:
- `.html` / `.htm` → Google Chrome
- everything else → Visual Studio Code