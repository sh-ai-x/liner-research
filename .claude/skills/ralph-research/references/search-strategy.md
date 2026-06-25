# Search Strategy — WebSearch / WebFetch 활용 가이드

ralph-research 스킬의 **작업 루프**(Phase 5)에서 모델이 따라야 할 검색 전략.

## 핵심 원칙

1. **쿼리는 gap을 정확히 메꿔야 한다.** 이미 sources.json에 있는 정보를 다시 묻지 않는다.
2. **WebFetch는 promising URL에만.** 결과 페이지의 모든 링크를 fetch하지 않는다.
3. **권위 등급을 먼저 본다.** primary > secondary > tertiary. 같은 AC를 채울 수 있으면 항상 primary를 우선.

## Query 디자인 패턴

### 패턴 1 — 학술/기술 비교
- `<A> vs <B> benchmark <year>`
- `<technology> performance evaluation site:arxiv.org`
- `<technology> comparison <metric> site:nature.com OR site:ieee.org`

### 패턴 2 — 최신 동향 (2026)
- `<topic> 2026 trends`
- `<topic> latest research <year>`
- `<topic> state of the art <year>`
- ⚠️ 단, 너무 broad한 쿼리는 noise. <topic>에 구체적 키워드 2-3개 결합.

### 패턴 3 — 반대 입론 / 한계
- `<topic> limitations`
- `<topic> criticism`
- `<topic> counter argument`
- `<topic> failed cases`
- `<technology> real-world failures production`

### 패턴 4 — 권위 소스 추적
- `<topic> site:arxiv.org`
- `<topic> site:nature.com`
- `<topic> site:ieee.org`
- `<topic> site:acm.org`
- `<topic> site:.gov OR site:.edu`

### 패턴 5 — 한국 시장/맥락 (해당 시)
- `<topic> 한국`
- `<topic> 한국 시장`
- `<topic> 국내 도입 사례`
- `<topic> 한국어`

## WebFetch 활용

### 언제 fetch하나
- WebSearch 결과에서 **title + snippet이 AC와 직접 매치**될 때만.
- 1 iteration에 같은 URL을 2번 fetch하지 않는다.
- 1 iteration에 fetch는 **최대 10-15개**로 제한 (그 이상은 시간 낭비).

### 추출할 내용
- 본문 핵심 단락 1-3개 (200-500 단어).
- 수치/인용/표는 정확히 보존.
- 신뢰도 평가에 필요한 정보 (저자, 소속, 출판사, 날짜).

### 추출 형식 — sources.json 카드 스키마
```json
{
  "id": 1,
  "title": "Title as it appears on page",
  "url": "https://...",
  "fetched_at": "2026-06-25T12:34:56Z",
  "snippet": "1-3 sentence excerpt relevant to AC",
  "tier": "primary | secondary | tertiary",
  "reliability": 0.0-1.0,  // 모델이 자체 평가
  "ac_satisfied": ["AC-1", "AC-3"],
  "key_facts": ["fact 1", "fact 2", "fact 3"],
  "quote": "exact 1-sentence quote that supports the finding (with attribution)"
}
```

### Reliability tier 추론 (verify-ac.sh와 일치)
- **primary**: peer-reviewed papers, official docs, .gov/.edu/.ac 도메인
- **secondary**: ACM TechNews, IEEE Spectrum, Nature News, Reuters, AP, NYT, WSJ, 공식 vendor blog (Google, Microsoft, Meta, AWS, OpenAI 등)
- **tertiary**: 그 외 — Medium, 개인 블로그, Reddit 등

## 검색 실패 대응

| 상황 | 대응 |
|---|---|
| 0 results | query paraphrase (동의어, 다른 각도), 3회까지. 그래도 0이면 explicit "no live source" 태그 후 모델 자체 합성. |
| Fetch 404 / timeout | 해당 URL 버림, 다음 URL. 1 iteration 내 3회 실패 시 그 소스는 사용 불가. |
| Duplicate (같은 URL) | 새 카드 추가 안 함. 기존 카드의 `ac_satisfied`만 확장. |
| Snippet만 보고 본문은 fetch 못 함 | 카드에 `incomplete: true` 표시. AC 채우지 않음. |
| 1차 쿼리는 광범위 → 후속 쿼리는 좁힘 | 1차: "<topic> 2026", 2차: "<topic> latency benchmark", 3차: "<topic> case study" |

## Iteration 설계

### 매 iteration 시작 시
1. `research_output/<stem>.sources.json` 읽기 → 현재 카드 수, 이미 채운 AC 목록.
2. `research_output/<stem>.md` 읽기 → 현재 인용 [n] 카운트, 분량.
3. `scratch/goal.md` 읽기 → AC 미충족 항목.
4. **Gap → Query** 매핑:
   - AC-1 미충족 (sources 부족) → 더 broad한 query
   - AC-2 미충족 (authoritative 부족) → `site:arxiv.org` / `site:nature.com` 등
   - AC-3 미충족 (citations 부족) → 이미 fetch한 카드 중 활용 안 한 fact가 있는지 먼저 확인, 그 후 추가 fetch
   - AC-4 미충족 (counter 없음) → "limitations / criticism / 실패 사례" query
   - AC-5 미충족 (분량 부족) → 더 넓은 topic 커버리지 또는 더 깊은 본문

### 매 iteration 종료 시
1. sources.json append.
2. md 초안 append / 갱신.
3. `bash verify-ac.sh` 실행.
4. PASS → `<promise>RESEARCH COMPLETE</promise>` (자신 있게만).
5. FAIL → 다음 iteration plan 출력.

### Iteration budget
- 기본 10회. 그 이상은 비효율 — 사용자에게 명시적 확인 요청.
- 5회 안에 AC-1, AC-3 충족 못 하면 query 전략 재검토 (broad → narrow 또는 그 반대).

## Citation 패턴

### Markdown 본문
- 인용은 `[n]` 형식. (n은 References 번호)
- 한 문장 끝에 `[1, 2]` 처럼 여러 출처 가능.

### References 섹션
```markdown
[1] Title — https://... (접속일: 2026-06-25, tier: primary)
[2] ...
```

### 인용 가능한 claim의 기준
- ✅ 수치/통계 (출처의 표/그래프에서 직접 인용)
- ✅ 권위 있는 정의/분류
- ✅ 실증 결과/사례 연구
- ❌ 일반 상식 / 모델 자체 추론 (인용 없이 단정)

## 작업 종료 직전 체크리스트

- [ ] AC 모두 PASS (verify-ac.sh exit 0)
- [ ] sources.json에 모든 카드의 tier 명시
- [ ] References 섹션이 본문의 [n]과 1:1 매치
- [ ] "반대 입론" 섹션이 실제로 존재 (헤딩 + 본문 1개 단락 이상)
- [ ] Appendix의 Search Trail에 모든 iteration 기록
- [ ] 5개 산출물(.md / .goal.json / .plan.json / .sources.json / .raw.jsonl) 모두 존재