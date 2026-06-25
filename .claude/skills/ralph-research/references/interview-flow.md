# Interview Flow — Wonder / Reflect / Refine / Restate

이 문서는 ralph-research 스킬의 **대화 루프**(Phase 1-4)에서 모델이 따라야 할 의사결정 규칙을 정의한다. 작업 루프(RALPH Wiggum)는 별도.

## 사이클 한눈에

```
seed
 ↓
Wonder   ─ 발산: 3-6 해석 후보
 ↓
Reflect  ─ 비교: 사용자 의도 vs 후보 → kept / pruned / new
 ↓
Refine   ─ 질문: 사용자 1명에게 결정적 질문 1개
 ↓  (답변 → ②)
Restate  ─ 수렴: goal + AC를 한 문장으로
 ↓
Rubric   ─ 자체 검증 (specific / scoped / actionable / AC-measurable)
 ↓ not ready → ②로
 ↓ ready
→ Phase 5 (검색 루프 시작)
```

## 1. Wonder — 발산

### 원칙
- **후보는 3-6개**. 그 이상은 사용자 인지 부하.
- 각 후보는 **다른 각도**여야 함 (같은 주제라도: 시장/기술/역사/윤리 등).
- 후보에 "이게 제일 좋다"는 순위를 매기지 않는다 — 사용자가 선택하게 둠.

### JSON 스키마
```json
{
  "label": "2-5 단어 라벨",
  "claim": "이 해석이 뜻하는 바 (한 문장)",
  "signal": "사용자 seed의 어떤 단어가 이 방향을 가리켰는지",
  "research_angle": "이 해석으로 검색한다면 어떤 쿼리/소스를 추적할지"
}
```

### 프롬프트 (Opus에 전달)
> "You are a Socratic research strategist. Given a research seed, surface 3-6 distinct interpretations. Each: label, claim, signal, research_angle. Respond ONLY with JSON array."

### 종료 조건
- 3-6개 후보 생성 완료.
- 사용자 응답 대기.

## 2. Reflect — 비교

### 원칙
- 사용자의 **가장 최근 답변**을 기준으로 비교.
- 분류는 보수적으로: 애매하면 kept에 두고 Refine에서 다시 확인.
- 사용자가 명시적으로 거절하지 않은 후보는 pruned로 가지 않는다.

### JSON 스키마
```json
{
  "kept": [/* 사용자 의도와 일치하는 후보 */],
  "pruned": [/* 사용자 답변으로 기각된 후보 */],
  "new": [/* 사용자 답변에서 새로 발견된 후보 */],
  "reasoning": "왜 그렇게 분류했는지 한 문장"
}
```

### 종료 조건
- 분류 완료, 다음 단계(Refine) 진행.

## 3. Refine — 질문

### 원칙
- **질문은 정확히 1개**. 두 개 이상은 사용자 인지 부하.
- **옵션 나열 금지**. "A 또는 B?" 형태도 가능하지만, 더 좋은 건 "어떤 결정을 내리면 이 리서치가 끝났다고 느끼겠어?" 형태.
- 답변이 **goal을 1차원 좁히는** 질문만. 답해도 같은 자리면 잘못된 질문.

### 좋은 질문 예
- "이 리서치의 독자는 누구야? — 엔지니어 / 의사결정자 / 일반인"
- "반대 입론을 얼마나 깊게 다룰까? — 1줄 언급 / 섹션 1개 / 리포트의 30%"
- "시점은? — 최신 6개월 / 1년 / 무제한"
- "산출물 형태는? — 읽기용 브리핑 / 발표용 슬라이드 / 데이터셋"
- "한국 시장 한정으로 볼까, 글로벌?"

### 나쁜 질문 예
- "어떤 주제가 좋아?" (모호, 옵션 없음)
- "색깔은 빨강, 파랑, 초록 중 뭐가 좋아?" (trivial)
- "리서치를 왜 하고 싶어?" (이미 알고 있는 정보 재요구)
- "더 알려줄 거 있어?" (yes/no로 끝나면 정보 없음)

### 종료 조건
- 사용자 답변 → kept 갱신 → Phase 2로 복귀.

### 루프 종료 트리거 (Refine 단계에서 사용자 발화)
- `/done`, `done`, `stop`, `충분해`, `이걸로` → Phase 4 (Restate)
- `/refine` → Wonder부터 다시
- `/auto` → 자동 모드
- 빈 답변 / "?" → 같은 질문을 더 구체화해서 재질문

## 4. Restate — 수렴

### 원칙
- 4가지 메타데이터를 **모두** 한 번에 확정.
- goal은 **행동 동사 + 대상 + 제약** 한 문장. 두 문장이면 너무 김.
- AC는 모두 **true/false로 판정 가능**해야 함. "잘" "충분히" 같은 모호한 단어 금지.
- scope_in/out은 사용자 답변에서 명시적으로 등장한 것만. 추측하지 않음.

### JSON 스키마 (machine-readable)
```json
{
  "goal": "Compare X for Y, focusing on Z.",
  "scope_in": ["...", "..."],
  "scope_out": ["...", "..."],
  "deliverables": ["research_output/<stem>.md", "research_output/<stem>.goal.json", "..."],
  "success_criteria": [
    "sources>=8 with >=4 authoritative",
    "report >=1200 words with >=10 citations",
    "includes counter-argument section"
  ],
  "suggested_queries": ["...", "...", "..."]
}
```

### Markdown (사람이 보는 형태 — templates/goal.md)
templates/goal.md를 그대로 사용.

### 종료 조건
- Rubric 모두 pass → Phase 5 (검색 루프 시작)
- 1개라도 fail → missing 항목 1개를 묻고 Refine으로 복귀

### 최대 라운드
- `MAX_INTERVIEW_ROUNDS=5` (default)
- 5라운드 후에도 ready가 아니면 강제 Restate (가장 넓은 scope + 표준 AC) 후 검색 루프로

## 5. Rubric — 자체 검증

### 4가지 질문

1. **specific**: goal이 구체적 타깃을 명시하는가? (기술명 / 대상 / 시점)
   - ❌ "AI에 대해 조사"
   - ✅ "2026년 기준으로 production RAG 시스템에서 pgvector vs Qdrant의 latency-throughput trade-off"

2. **scoped**: in/out 경계가 있는가?
   - ❌ "무엇이든 OK"
   - ✅ "in: production RAG, 2025-2026, latency-p95; out: 학계 only, batch processing"

3. **actionable**: WebSearch 쿼리로 환원 가능한가?
   - ❌ "사용자 경험 비교" (검색 결과로 검증 어려움)
   - ✅ "Qdrant benchmark 2025 latency p95" → 명확한 검색어

4. **AC-measurable**: AC 각각이 true/false 판정 가능한가?
   - ❌ "리포트가 충분히 자세할 것"
   - ✅ "report.md >= 1200 단어 AND >= 10 unique [n] citations"

### 한 가지라도 no → Refine으로 복귀
가장 결정적인 missing 1개만 묻는다 (동시에 다 묻지 않음).

## 자동 모드 (`--auto`)

- 인터뷰는 1라운드만 진행.
- 이후 Reflect 결정 / Refine 답변 / Restate 모두 모델이 합성.
- 합성 답변에는 `[AUTO-SYNTHESIZED]` 마커를 답 안에 포함시켜 사용자가 인지 가능하게.
- 자동 합성 결정에 사용자가 이의제기 가능 (`중단`, `인터뷰로 전환` 입력 시).

## 빠른 모드 (`--quick`)

- 인터뷰 생략.
- Wonder → 즉시 Restate (가장 넓은 scope, 표준 AC).
- 표준 AC: sources>=5 / citations>=5 / has_counter_argument / min_words=800 / files=md+goal+sources.

## 톤

- 한국어 / 영어 모두 OK. seed 언어를 따른다.
- 옵션 나열 질문 금지 — 질문 자체가 결정을 유도.
- 한 번에 한 가지 결정만. "그리고" / "또한" 사용 자제.