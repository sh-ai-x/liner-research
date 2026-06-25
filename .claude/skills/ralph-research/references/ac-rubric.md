# Acceptance Criteria — Rubric

ralph-research의 작업 결과물이 "완료"로 인정되려면 **모든 AC가 PASS**해야 한다. 이 문서는 AC 정의 규칙과 verify-ac.sh 판정 로직의 정본이다.

## AC 정의 규칙

### 좋은 AC
- **측정 가능**: true/false로 판정 가능해야 함.
- **산출물 기반**: 구체적 파일/필드/메트릭을 참조.
- **하나의 차원**: 두 가지가 섞이지 않아야 함 (예: "sources>=5 AND citations>=10" → 둘로 분할).
- **사용자 답변에 근거**: 추측이 아니라 인터뷰에서 나온 결정.

### 나쁜 AC
- ❌ "리포트가 자세할 것" (모호)
- ❌ "최신 정보를 포함할 것" (측정 불가)
- ❌ "여러 관점을 다룰 것" (몇 개? 어떤 관점?)
- ❌ "잘 정리되어 있을 것" (주관적)
- ❌ "사용자가 만족할 것" (외부 의존)

## 표준 AC 세트

### Default (quick mode에서 자동 적용)
```markdown
- [ ] sources>=5
- [ ] citations>=5
- [ ] has_counter_argument
- [ ] min_words=800
- [ ] files_exist=md+goal+sources
```

### 권장 (interactive mode에서 사용자 합의)
```markdown
- [ ] sources>=8
- [ ] sources_authoritative>=4
- [ ] citations>=10
- [ ] has_counter_argument
- [ ] min_words=1200
- [ ] all_5_artifacts
```

### 학술 리서치 (peer-review target)
```markdown
- [ ] sources>=20
- [ ] sources_authoritative>=12
- [ ] citations>=25
- [ ] has_counter_argument
- [ ] min_words=3000
- [ ] all_5_artifacts
- [ ] max_words=10000
```

### 빠른 의사결정 브리핑
```markdown
- [ ] sources>=3
- [ ] has_counter_argument
- [ ] min_words=400
- [ ] max_words=800
```

## 지원되는 AC 문법 (verify-ac.sh)

| 표현 | 의미 | 예시 |
|---|---|---|
| `sources>=N` | sources.json 카드 수 | `sources>=5` |
| `sources_authoritative>=N` | primary+secondary 카드 수 | `sources_authoritative>=4` |
| `citations>=N` | 보고서 내 unique [n] 마커 수 | `citations>=10` |
| `min_words=N` | 보고서 단어 수 최소 | `min_words=1200` |
| `max_words=N` | 보고서 단어 수 최대 | `max_words=3000` |
| `has_counter_argument` | "반대/limitation/counter" 키워드 존재 | — |
| `files_exist=<csv>` | 쉼표 구분 파일 존재 | `files_exist=md,goal,sources,plan,raw` |
| `all_5_artifacts` | stem의 5개 산출물 모두 존재 | — |

## 한국어 자유 텍스트 → AC 자동 변환

goal.md의 `- [ ] AC-N: <한글 자유 텍스트>`에서 verify-ac.sh가 자동으로 룰을 추출한다:

| 키워드 | 변환 |
|---|---|
| "출처 >= N" / "sources>=" / "N개 이상" | `sources=N` |
| "권위 소스 >= N" / "주요 출처" | `sources_authoritative=N` |
| "인용 >= N" / "참조 >= N" | `citations=N` |
| "분량 >= N" / "단어 >= N" / "길이 >= N" | `min_words=N` |
| "분량 <= N" / "단어 <= N" / "최대 N" | `max_words=N` |
| "반대 입론" / "한계" / "counter" / "limitation" | `has_counter_argument` |
| "산출물" / "artifacts" / "파일" | `all_5_artifacts` |

자동 변환이 안 되는 표현은 그대로 free-text로 두고 verifier 출력에 `UNPARSED`로 표시됨. 그 경우 명시적 룰로 다시 적는다.

## AC 추가/수정 방법

인터뷰 중(Phase 3 Refine)에서 사용자가 "AC-3을 5에서 8로 올려줘" 식으로 명시하면 즉시 goal.md에 반영.

수정 후 반드시 `verify-ac.sh`를 dry-run (goal만 주고) 해서 AC 형식이 올바른지 확인.

## 실패 시 fallback

verify-ac.sh가 FAIL을 반환했을 때 모델이 취할 행동:

1. **어떤 AC가 FAIL인지 정확히 식별** (verify 출력에서)
2. **왜 FAIL인지 분석**:
   - sources 부족 → 더 많은 query
   - authoritative 부족 → site:arxiv.org, site:.edu 등 권위 도메인 쿼리
   - citations 부족 → 이미 있는 카드를 활용 안 한 거면 활용, 부족하면 추가 fetch
   - counter 없음 → "limitations / criticism / 실패 사례" 쿼리
   - 분량 부족 → 더 넓은 커버리지
3. **다음 iteration plan 출력** (한 줄):
   `Next: AC-4 (counter) → "<topic> limitations site:arxiv.org"`
4. Stop hook이 동일 prompt를 재투입 → 다음 iteration 시작

## AC 강제 통과 (사용자 수동)

자동 검증 실패 시 사용자가 명시적으로 `<promise>RESEARCH COMPLETE</promise>`를 출력하면:
- stop hook이 verify-ac.sh를 다시 실행
- 여전히 FAIL이면 hook이 **false promise로 간주**하고 루프 계속
- 사용자가 정말 종료하고 싶다면 `rm .claude/ralph-research.local.md`로 state 파일 삭제 후 종료

이 메커니즘은 모델이 거짓 promise로 루프를 빠져나가는 것을 방지한다.