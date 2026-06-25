# Goal

> Date: YYYY-MM-DD | Status: pending-approval
> Stem: <will be assigned by skill>

[Action verb] + [target] + [constraint] — 한 문장으로.

예: "Compare the architectural trade-offs of vector databases (Qdrant, Weaviate, Milvus, pgvector) for RAG pipelines serving <100ms latency at 10k QPS, focusing on 2025-2026 production deployments."

## Acceptance Criteria

각 AC는 verify-ac.sh가 true/false로 판정할 수 있어야 한다.

- [ ] **AC-1**: sources>=8 — research_output/<stem>.sources.json에 최소 8개 출처 카드
- [ ] **AC-2**: sources_authoritative>=4 — 그 중 권위 도메인(.gov/.edu/.org/academic/arXiv/Nature/IEEE/ACM/학회) 4개 이상
- [ ] **AC-3**: citations>=10 — 리포트 본문에 최소 10개 unique [n] 인용 마커
- [ ] **AC-4**: has_counter_argument — "반대 입론 / 한계 / Limitation / Counter-argument" 섹션이 존재
- [ ] **AC-5**: min_words=1200 — 리포트 본문 ≥ 1200 단어
- [ ] **AC-6**: all_5_artifacts — 5개 산출물(.md, .goal.json, .sources.json, .plan.json, .raw.jsonl) 모두 존재

## Scope

in:
- [포함 영역 1]
- [포함 영역 2]

out:
- [제외 영역 1]
- [제외 영역 2]

## Search Plan (초안)

queries:
  - "<검색어 1 — 가장 핵심>"
  - "<검색어 2 — 반대 입론>"
  - "<검색어 3 — 권위 소스>"
  - "<검색어 4 — 실증 데이터>"
  - "<검색어 5 — 최신 동향 2026>"
  - "<검색어 6 — 한국 시장/맥락 (해당 시)>"

## Constraints

- 인용은 primary/secondary 출처에서만.
- 광고/스팸성 도메인 제외.
- 1년 이상 오래된 자료는 (기술 동향 리서치인 경우) 보조로만 인용.