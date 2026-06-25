# ralph-research

> Liner API 없이 Claude Code의 WebSearch/ WebFetch만으로 동작하는 인터뷰 기반 리서치 하네스.
> RALPH Socratic 루프(Wonder → Reflect → Refine → Restate)로 goal/AC를 사용자 인터뷰로 수렴시키고,
> RALPH Wiggum 자기참조 루프로 검색·정제·리포트를 자동 반복한다.

## 한 줄 사용

```
/ralph-research Compare pgvector vs Qdrant for RAG 2026
```

인터뷰가 시작되고, 3-5 라운드 Socratic 질문 후 goal이 확정되면 자동으로 검색 루프가 돈다. AC 모두 PASS 시 자동 종료.

## 모드

| 모드 | 트리거 | 동작 |
|---|---|---|
| **interactive** (default) | `/ralph-research <seed>` | 매 라운드마다 사용자 답변 받음 |
| **auto** | `/ralph-research --auto <seed>` | 인터뷰 1라운드 + 이후 모델이 합성 답변으로 진행 |
| **quick** | `/ralph-research --quick <seed>` | 인터뷰 생략, 표준 AC 적용, 즉시 검색 루프 |

## 워크플로우

```
[seed]
   ↓
① Wonder       (의미 후보 3-6개 발산)
   ↓
② Reflect      (사용자 의도와 비교)
   ↓
③ Refine       (Socratic 질문 1개)
   ↓ (답변 → ②)
④ Restate      (goal + AC 한 문장)
   ↓
⑤ <AC ready?> ── no → ②로 / yes
   ↓
⑥ RALPH Wiggum 검색 루프
   - WebSearch/WebFetch로 출처 수집
   - sources.json 누적
   - report.md 갱신
   - verify-ac.sh 실행
   - PASS → <promise>RESEARCH COMPLETE</promise> → 자동 종료
   - FAIL → 같은 goal 재투입 (Stop hook)
   ↓
⑦ research_output/<stem>.{md,goal.json,sources.json,plan.json,raw.jsonl} 저장
```

## 산출물

`<stem>`은 seed 기반으로 자동 생성 (예: `ai-memory-2026`).

| 파일 | 내용 |
|---|---|
| `research_output/<stem>.md` | 최종 리포트 (Markdown, 인용 포함) |
| `research_output/<stem>.goal.json` | 확정된 goal + AC (machine-readable) |
| `research_output/<stem>.sources.json` | 출처 카드 배열 |
| `research_output/<stem>.plan.json` | 검색 계획 + iteration history |
| `research_output/<stem>.raw.jsonl` | WebSearch/WebFetch raw 응답 (audit) |
| `scratch/goal.md` | 사람이 보고 수정한 goal 초안 |

## AC (Acceptance Criteria) 기본값

### Interactive / Auto 모드 (권장)
- sources>=8, sources_authoritative>=4
- citations>=10
- has_counter_argument
- min_words=1200
- all_5_artifacts

### Quick 모드
- sources>=5, citations>=5
- has_counter_argument
- min_words=800
- files_exist=md+goal+sources

사용자가 인터뷰에서 다른 AC를 원할 수 있음 — 자유롭게 수정.

## 설치 / 설정

이 스킬은 `~/.claude/skills/ralph-research/`에 위치하거나 프로젝트의 `.claude/skills/ralph-research/`에 위치하면 된다. SKILL.md의 frontmatter가 자동 인식된다.

### Stop hook 자동 등록
`setup-loop.sh`가 **최초 1회** `.claude/settings.local.json`에 Stop hook을 등록한다. 이후는 idempotent.

수동 등록을 원한다면:
```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "bash /Users/sanghee/dev/research/.claude/skills/ralph-research/hooks/ralph-stop.sh"
      }]
    }]
  }
}
```

## 파일 구조

```
.claude/skills/ralph-research/
├── SKILL.md                          ← 스킬 정의 (frontmatter + 워크플로우)
├── README.md                         ← 이 파일
├── hooks/
│   ├── hooks.json                    ← Stop hook 정의 (참고용)
│   └── ralph-stop.sh                 ← 자기참조 루프 + AC 검증
├── scripts/
│   ├── setup-loop.sh                 ← RALPH state 파일 생성 + hook 등록
│   ├── verify-ac.sh                  ← AC 자동 검증 (exit 0 only if all PASS)
│   ├── wonder.sh                     ← Wonder 후보 생성 helper
│   └── restate.sh                    ← Restate helper
├── references/
│   ├── interview-flow.md             ← Wonder/Reflect/Refine/Restate 의사결정 규칙
│   ├── search-strategy.md            ← WebSearch 쿼리 디자인 / fetch 전략
│   └── ac-rubric.md                  ← AC 정의 + verify-ac.sh 룰 매핑
├── templates/
│   ├── goal.md                       ← goal + AC 템플릿
│   ├── search-plan.md                ← 검색 계획 템플릿
│   └── report.md                     ← 리포트 템플릿
└── scratch/                          ← 작업 중 임시 (git ignore 가능)
```

## 사용 예시

### 예 1 — 기술 비교 리서치

```
> /ralph-research Compare pgvector vs Qdrant for RAG 2026
```

인터뷰:
- "Wonder 결과: 6개 후보..."
- "Q: latency-p95 vs throughput vs DX 중 우선순위는?"
- 사용자: "latency-p95"
- ...
- "Restate: Compare pgvector vs Qdrant for RAG production deployments with p95 < 100ms at 10k QPS, 2025-2026."
- "AC: 8 sources (4 authoritative), 10 citations, counter-argument, 1200 words."
- "OK, 검색 루프 시작."

8 iteration 후 AC 모두 PASS → `<promise>RESEARCH COMPLETE</promise>` → 자동 종료.

### 예 2 — 빠른 의사결정 브리핑

```
> /ralph-research --quick Should I use FastAPI or Flask for a new microservice in 2026
```

인터뷰 생략, 표준 quick AC 적용, 5-7 iteration 안에 종료.

### 예 3 — 자동 모드 (인터뷰 최소화)

```
> /ralph-research --auto "PostgreSQL 17 features for analytics"
```

1라운드 인터뷰 → 자동 합성 답변 → 검색 루프. 사용자가 중간에 끼어들 수 있음.

## 안전망

| 사용자 발화 / 상황 | 동작 |
|---|---|
| `/done`, `done`, `stop`, `충분해` (인터뷰 중) | 즉시 Restate 후 검색 루프 |
| `/refine` (인터뷰 중) | Wonder부터 다시 |
| `중단`, `cancel`, `quit` | state 파일 삭제, 요약 출력 후 종료 |
| `rm .claude/ralph-research.local.md` (수동) | 다음 Stop에서 즉시 정상 종료 |
| max_iterations 도달 | best-effort 리포트 저장 후 종료 |
| 거짓 `<promise>` 출력 | verify-ac.sh FAIL → hook이 false promise로 간주, 루프 계속 |

## 동반 스킬 비교

| 스킬 | 도구 | 인터랙티브 | 자동 루프 | AC 게이트 |
|---|---|---|---|---|
| **ralph-research** (이것) | WebSearch/ WebFetch | ✅ | ✅ (RALPH Wiggum) | ✅ verify-ac.sh |
| `/liner-research` | Liner API (학술) | ✅ | ❌ (1-shot) | ❌ |
| `/deep-research` (외장) | WebSearch | ✅ | ❌ | ❌ |

**ralph-research의 차별점**:
1. **Liner 불필요** — WebSearch만으로 동작.
2. **자기참조 정제 루프** — AC 미충족 시 Stop hook이 같은 goal을 재투입.
3. **AC 강제 게이트** — `<promise>` 출력해도 verify-ac.sh 통과 전엔 종료 안 됨.

## 트러블슈팅

### "Stop hook이 안 걸려요"
- `.claude/settings.local.json`에 Stop hook이 등록됐는지 확인.
- 또는 setup-loop.sh를 한 번 실행해서 자동 등록시키기.

### "verify-ac.sh가 항상 FAIL이에요"
- goal.md의 AC 형식이 맞는지 확인 (`- [ ] AC-N: <표현>`).
- 한국어 자유 텍스트는 자동 변환되지만, 모호하면 명시적 룰(`sources>=5`)로 적기.

### "루프가 끝없이 돌아요"
- max_iterations를 너무 크게 잡았거나, AC가 너무 빡셈.
- `rm .claude/ralph-research.local.md`로 강제 종료 후 AC를 완화해서 재시도.

### "WebSearch가 0 결과만 줘요"
- 쿼리를 더 specific하게 (broad → narrow 또는 그 반대).
- 다른 동의어로 paraphrase.

### "리포트가 너무 짧아요"
- AC `min_words`를 늘리거나, 추가 query로 더 많은 fact 수집 후 본문 확장.