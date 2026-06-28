# liner-research

Liner(liner.com) 기반 리서치 자동화 스킬. Claude-driven **Wonder → Refine → Discussing** Socratic 루프로 연구 목표를 수렴하고, Liner 검색 API를 호출해 Markdown 브리핑 + Mermaid 마인드맵을 생성한다.

## 트리거

```
/liner-research [seed]
"research X", "조사해줘", "Liner로 리서치", "deep research on …"
```

## 파이프라인

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

## 환경 설정

`.env` (프로젝트 루트):

```
LINER_API_KEY=sk_live_...
ANTHROPIC_API_KEY=...
```

virtualenv 활성화:

```bash
source /Users/sanghee/dev/research/.venv/bin/activate
```

## CLI

모든 명령은 `scripts/` 디렉토리에서 실행:

```bash
# Phase 0 — Wonder (해석 후보 생성)
python research.py wonder --seed "your topic"

# Phase 2 — Restate (goal + rubric 수렴)
python research.py restate --seed "your topic" \
  --user-context '["reply 1", "reply 2"]' \
  --candidates '[{"label":"...","claim":"..."}]'

# Phase 3 — Pipeline (Liner 검색 + 요약 + 저장)
python research.py run-pipeline --goal-json /tmp/goal.json --depth 5

# Visualize (Atlas HTML)
python research.py visualize --query "your topic"
python research.py visualize --goal-json /tmp/goal.json
```

## 파일 구조

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

## 연관 스킬

- `/liner-visualize` — 수렴된 goal JSON 또는 자유 텍스트 쿼리로 Liner Atlas HTML 생성
