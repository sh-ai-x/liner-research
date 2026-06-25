---
name: ralph-research
description: |
  인터뷰 기반(WebSearch) 리서치 하네스 스킬. Liner API 없이 Claude Code의 WebSearch/ WebFetch 도구만으로 멀티소스 리서치 브리핑을 생성한다.
  RALPH Socratic 루프(Wonder → Reflect → Refine → Restate)로 goal/AC를 사용자 인터뷰로 수렴시키고, RALPH Wiggum 자기참조 루프로 검색·정제·리포트를 반복한다.
  Triggers (KO): ralph-research, /ralph-research, 웹서치 리서치, 리서치해줘 (with WebSearch), 조사해줘 (no Liner), 리서치 하네스, RALPH 리서치
  Triggers (EN): ralph-research, /ralph-research, web research, research harness, deep research without Liner
  Do NOT use when: 사용자가 명시적으로 Liner를 요청 → /liner-research. 데이터 분석 목표 → /harness-data-analysis:ralph.
---

# ralph-research — 인터뷰 기반 웹 리서치 하네스

## 한 줄 정의

> 사용자 인터뷰(Socratic)로 **goal + AC**를 수렴 → WebSearch/WebFetch로 소스 수집 → 정제·합성 → Markdown 리포트 → AC 충족 시 종료.
> 두 개의 루프: **대화 루프**(사람과 대화로 goal 확정) + **작업 루프**(Stop hook으로 리서치 자체를 자기참조 정제).

## 워크플로우 (한눈에)

```
[seed]
   ↓
① Wonder       (의미 후보 3-6개 발산)
   ↓
② Reflect      (사용자 의도와 비교 — kept / pruned / new)
   ↓
③ Refine       (사용자에게 Socratic 질문 1개)
   ↓
④ Restate      (goal + AC 한 문장으로 재진술)
   ↓
⑤ <AC ready?> ── no → ②로
   ↓ yes
⑥ 검색 루프 시작 (RALPH Wiggum)
   - search_plan.md 생성
   - WebSearch → WebFetch → 출처 카드 누적
   - report.md 초안 작성
   - AC 검증 → 미충족 → 보강 검색 (Stop hook이 같은 프롬프트를 재투입)
   ↓
⑦ AC 모두 충족 → <promise>RESEARCH COMPLETE</promise>
   ↓
⑧ research_output/<stem>.{md,goal.json,sources.json,plan.json} 저장
```

## 트리거

- `/ralph-research [seed]` — 인터랙티브 모드 (default)
- `/ralph-research --auto [seed]` — 자동 모드 (인터뷰 1라운드, 나머지 자동)
- `/ralph-research --quick [seed]` — 빠른 모드 (인터뷰 생략, 기본 AC 적용)

## Phase 0 — Bootstrap

1. `seed`가 비어 있으면 한 번 묻기: **"어떤 주제를 리서치할까요?"**
2. `research_output/`이 존재하는지 확인. 없으면 생성.
3. `scratch/ralph-research-<timestamp>.md` 파일을 만들고 현재 라운드 상태를 저장.
4. `goal.md` 템플릿을 `scratch/`로 복사하고 헤더만 채움 (사용자가 보고 수정할 수 있도록 노출).

## Phase 1 — Wonder (의미 발산)

목표: 사용자 seed 안에 숨어 있는 해석 후보 3-6개를 만든다.

**방법 (두 가지 중 택일)**:

- **A. 모델이 직접 Wonder** (권장, Opus로):
  `seed`를 받아 다음과 같은 JSON을 생성:

  ```json
  [
    {
      "label": "한 단어 라벨",
      "claim": "이 해석이 뜻하는 한 문장",
      "signal": "사용자 단어 중 무엇이 이 방향을 가리키는지",
      "research_angle": "실제로 검색해야 할 구체적 각도"
    },
    ...3-6개
  ]
  ```

- **B. 보조 스크립트 사용** (재현 가능성 필요 시):
  ```bash
  bash .claude/skills/ralph-research/scripts/wonder.sh "<seed>" > scratch/wonder.json
  ```

사용자에게 3-6개 후보를 짧게 보여준다 (`label — claim` 형식, 1-2줄).

## Phase 2 — Reflect (의미 비교)

목표: 후보 각각을 사용자의 최신 답변과 비교해서 **kept / pruned / new**로 분류한다.

```json
{
  "kept":   [ /* 사용자 의도와 일치 */ ],
  "pruned": [ /* 사용자 답변으로 기각 */ ],
  "new":    [ /* 사용자 답변에서 새로 발견된 해석 */ ],
  "reasoning": "왜 그렇게 분류했는지 한 문장"
}
```

**판단 규칙**:
- 사용자가 "그거" "맞아" 식으로 답하면 → kept 강하게.
- "아니 그게 아니라" → 그 후보는 pruned.
- "사실은 ~도 같이 알고 싶어" → new 추가.

## Phase 3 — Refine (Socratic 질문)

목표: 다음 라운드의 **decision-relevant**한 질문 **딱 1개** (< 25 단어).

**좋은 질문의 특징**:
- 옵션을 나열하지 않음 (질문 자체가 선택을 강제).
- 답변이 goal을 1차원 좁힘 (예: "시작 연도?", "주 사용 시나리오?", "반대 입론을 포함할까?").
- 답할 수 없는 모호한 추상 질문 금지.

**사용자 답변 → Phase 2로 복귀**.

**루프 종료 트리거** (사용자 발화):
- `/done`, `done`, `stop`, `충분해`, `이걸로` → Phase 4로.
- `/refine` → Wonder부터 다시 (seed 변경).
- `/auto` → 자동 모드로 전환 (Synthesizer가 대신 결정).

**최대 라운드**: `MAX_INTERVIEW_ROUNDS=5` (default). 초과 시 강제 Restate.

## Phase 4 — Restate (Goal + AC 확정)

목표: 현재까지의 대화를 **누가 봐도 실행 가능한 goal + AC**로 재진술.

`scratch/goal.md` 파일을 다음 구조로 채운다 (Opus가 작성):

```markdown
# Goal
[action verb] + [target] + [constraint] 한 문장.

# Acceptance Criteria
- [ ] AC-1: [측정 가능 조건 — 예: "5개 이상의 권위 소스(공식 문서/논문/대형 매체)에서 동일 결론"]
- [ ] AC-2: [인용 가능한 출처 N개 이상]
- [ ] AC-3: [반대 입론 최소 1개 포함]
- [ ] AC-4: [리포트 분량 ≥ N 단어 / ≤ M 단어]
- [ ] AC-5: [산출물 파일: .md + .goal.json + .sources.json]

# Scope
in: [포함]
out: [제외]

# Search Plan (초안)
queries:
  - "<검색어 1>"
  - "<검색어 2>"
  ...
```

**Rubric (자체 검증)**:
1. **specific** — 구체적 타깃(기술/대상/시점)이 있는가?
2. **scoped** — in/out 경계가 있는가?
3. **actionable** — WebSearch 쿼리로 환원 가능한가?
4. **AC-measurable** — AC 각각이 true/false로 판정 가능한가?

모두 yes → Phase 5로. 하나라도 no → 가장 결정적인 missing 1개를 묻고 Phase 2로 복귀.

**저장**:
- `scratch/goal.md` (사람이 보는 형태)
- `research_output/<stem>.goal.json` (기계가 읽는 형태, search/reporting이 참조)

## Phase 5 — 검색 루프 시작 (RALPH Wiggum)

Restate가 AC-ready가 되면, **자동으로 Ralph Wiggum 자기참조 루프를 켠다**.

### 5-1. Setup

```bash
bash .claude/skills/ralph-research/scripts/setup-loop.sh \
  --seed "<원래 seed>" \
  --goal scratch/goal.md \
  --max-iterations 10 \
  --completion-promise "RESEARCH COMPLETE"
```

이 스크립트는:
1. `.claude/ralph-research.local.md`에 state 파일 생성.
2. Stop hook을 통해 매 iteration마다 동일 goal을 재투입.

### 5-2. 매 iteration에서 할 일

```
1. research_output/<stem>.sources.json 읽기 → 이미 수집된 출처 확인
2. AC 중 미충족 항목 식별
3. 미충족 AC별로 WebSearch 쿼리 1-3개 도출
4. WebSearch 실행 → 결과 URL 5-10개
5. 각 URL에 대해 WebFetch로 본문 추출
6. 출처 카드 누적 (title, url, snippet, fetched_at, relevance, reliability_tier)
7. report.md 초안 작성/갱신
8. AC 검증 스크립트 실행
9. AC 모두 충족 → <promise>RESEARCH COMPLETE</promise> 출력 → 루프 자동 종료
10. 미충족 → 다음 iteration에서 보강
```

### 5-3. AC 검증 자동화

```bash
bash .claude/skills/ralph-research/scripts/verify-ac.sh \
  --goal scratch/goal.md \
  --report research_output/<stem>.md \
  --sources research_output/<stem>.sources.json
```

출력:
```
AC-1 sources>=5 authoritative: PASS (7 found, 5 authoritative)
AC-2 citations>=N: FAIL (4 found, need 8)
AC-3 counter-argument present: PASS
...
Overall: 2/5 PASS — continue iteration
```

### 5-4. Stop hook 동작

`hooks/ralph-stop.sh`가 매 Stop 시점에서:
1. 마지막 어시스턴트 출력에서 `<promise>RESEARCH COMPLETE</promise>` 검사.
2. 발견 시 state 파일 삭제 → 정상 종료.
3. 미발견 시 iteration++ 후 동일 goal을 reason으로 block.

## Phase 6 — Report 작성 (산출물)

**파일 위치**: `research_output/<stem>.<ext>`

| 파일 | 내용 |
|---|---|
| `<stem>.goal.json` | 확정된 goal + AC (machine-readable) |
| `<stem>.plan.json` | search_plan (queries, iteration_history) |
| `<stem>.sources.json` | 출처 카드 배열 |
| `<stem>.md` | 최종 리포트 (Markdown, 인용 포함) |
| `<stem>.raw.jsonl` | WebSearch/WebFetch raw 응답 (audit용) |

**리포트 구조** (templates/report.md 참조):

```markdown
# <Title>

> Date: YYYY-MM-DD | Goal: ... | AC: 5/5 PASS

## TL;DR (3-5 bullets)
- 핵심 결론 1
- 핵심 결론 2
- 핵심 결론 3

## 본문
### Section 1
... (출처 인용 [1], [2])

### Section 2
...

## 반대 입론 / 한계
- 입론 1 + 출처 [N]
- 입론 2 + 출처 [N]

## References
[1] Title — URL (접속일: YYYY-MM-DD)
[2] ...

## Appendix: Search Trail
- Iteration 1: <queries used> → <N sources added>
- Iteration 2: ...
```

## 자동 모드 (`--auto`)

인터뷰를 1라운드만 진행하고, 이후는 모델이 자체적으로:
- Reflect 결정
- Refine 질문 생성 → 즉시 답변 (합성 답변, "I assume ...") 후 계속
- Restate 후 AC-ready 즉시 검색 루프 진입

**합성 답변 규칙**:
- 모호함이 적은 일반 지식 영역: 합성 OK.
- 사용자 의도가 강하게 좌우하는 결정(예: "한국 시장 한정", "반대 입론 포함 여부"): 합성 답변에 주석 달고 사용자에게 알림.

## 빠른 모드 (`--quick`)

인터뷰 생략. Wonder → 즉시 Restate (가장 넓은 scope) → 검색 → 리포트.
AC는 자동 적용: `출처 ≥ 5 / 분량 ≥ 800 단어 / 인용 ≥ 5 / 반대입론 1 / 파일 4종`.

## 실패 모드 / 안전망

| 상황 | 대응 |
|---|---|
| WebSearch가 0 결과 | 쿼리 재작성 → 다른 표현 → 마지막엔 명시적 합성 표시 후 진행 |
| WebFetch 실패 (404/timeout) | 해당 URL 버림, 다른 URL 시도 (3회 실패 시 제외) |
| 같은 소스 중복 인용 | reliability_tier 낮춤 + dedup |
| 사용자가 "중단" 입력 | state 파일 삭제 + 요약 출력 후 종료 |
| max_iterations 도달 | 현재까지의 best-effort 리포트 저장 + 다음 iteration에서 마무리 프롬프트 |
| AC 자동 검증 false negative | 사람이 명시적으로 `<promise>RESEARCH COMPLETE</promise>` 입력하면 강제 종료 |

## Style

- Opus: SKILL.md 작성, Restate/Goal 결정, Rubric 평가.
- Sonnet: 매 iteration의 WebSearch query 생성, 출처 추출, 리포트 작성.
- 한국어/영어 모두 OK. seed 언어를 따라간다.
- 인용은 `[n]` 형식 + References 섹션에 풀 URL.
- emoji·장식 금지. 헤딩은 4단계까지.

## 파일 구조

```
.claude/skills/ralph-research/
├── SKILL.md                          (이 파일)
├── README.md                         (사용자 가이드)
├── hooks/
│   ├── hooks.json                    (Stop hook 등록)
│   └── ralph-stop.sh                 (iteration loop + AC verify)
├── scripts/
│   ├── setup-loop.sh                 (Ralph state 파일 생성)
│   ├── verify-ac.sh                  (AC 자동 검증)
│   ├── wonder.sh                     (Wonder 후보 생성 helper)
│   └── restate.sh                    (Restate helper)
├── references/
│   ├── interview-flow.md             (Wonder/Reflect/Refine/Restate 상세)
│   ├── search-strategy.md            (WebSearch 쿼리 디자인)
│   └── ac-rubric.md                  (AC 측정 규칙)
├── templates/
│   ├── goal.md                       (goal + AC 템플릿)
│   ├── search-plan.md                (검색 계획 템플릿)
│   └── report.md                     (리포트 템플릿)
└── scratch/                          (작업 중 임시 파일 — git ignore 가능)
```

## 동반 스킬

- `/liner-research` — Liner API 기반 (학술 검색에 강함). 이 스킬은 Liner 없이 WebSearch만.
- `/liner-visualize` — Atlas 시각화 (이 스킬과 별도).
- `/deep-research` (외장) — 더 단순한 인터랙티브 리서치. ralph-research는 self-referential iteration을 자동으로 돌린다는 점이 다름.