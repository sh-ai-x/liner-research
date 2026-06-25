# Goal

> Date: 2026-06-25 | Status: pending-approval | Stem: data-ai-portfolio-2026 (기존 파일 확장)

기존 5직군 리포트(`data-ai-portfolio-2026.md`)를 **6개 신규 2026-era 직군** (AI Engineer · FDE · Agent Orchestrator · AI Native Developer · AX 전문가 · AX 기획자)을 통합하여 **11직군 통합 포트폴리오 가이드**로 확장한다. 4클러스터 분류 (전통데이터 / AI-builder / AI-deployer / AI-strategist)로 재구성. 신입/주니어 × 한국 채용 시장 × 컴공 전공 (no portfolio) 컨텍스트 유지.

## Acceptance Criteria

- [ ] **AC-1**: sources>=25
- [ ] **AC-2**: sources_authoritative>=10
- [ ] **AC-3**: citations>=28
- [ ] **AC-4**: has_counter_argument
- [ ] **AC-5**: min_words=5000
- [ ] **AC-6**: max_words=10000
- [ ] **AC-7**: all_5_artifacts
- [ ] **AC-8**: project_slots_min=44 — 11직군 × 4경로 (Kaggle/사이드/OSS/인턴)
- [ ] **AC-9**: 한국 시장 JD 인용>=5 (DACON + Kakao tech blog + 추가 한국 사례)
- [ ] **AC-10**: skill_matrix_rows=11 — 11직군 × 4분면 (Hard/Soft/Tool/인증) skill matrix
- [ ] **AC-11**: cluster_keywords=전통데이터,AI-builder,AI-deployer,AI-strategist — 4클러스터 모두 본문에 등장
- [ ] **AC-12**: new_role_count=6 — 신규 6직군 (AI Engineer, FDE, Agent Orchestrator, AI Native Developer, AX 전문가, AX 기획자) 모두 본문에 등장

## 4클러스터 (Cluster) 분류

| 클러스터 | 직군 (5개 + 6개 = 11개) | 핵심 산출물 |
|---|---|---|
| **전통 데이터 (Traditional Data)** | 데이터 분석가, 데이터 과학자, 데이터 엔지니어 | 대시보드, 모델, 파이프라인 |
| **AI-builder** | LLM/RAG 활용 전문가, AI Engineer, AI Native Developer | LLM 앱, agent demo, AI-first 제품 |
| **AI-deployer** | AI 자동화 전문가, FDE (Forward Deployed Engineer), Agent Orchestrator | 워크플로우 자동화, 고객 배포형 agent |
| **AI-strategist** | AX 전문가, AX 기획자 | AI 전환 로드맵, ROI 모델, 거버넌스 |

## Scope

in:
- 11개 직군 (5 기존 + 6 신규)
- 4클러스터 분류 체계
- 신입/주니어 (0-2년) 포지션
- 한국 채용 시장 (DACON + Kakao tech blog + 국내 대기업 사례)
- 4개 포트폴리오 경로 (Kaggle/DACON, 사이드 프로젝트, 오픈소스, 인턴)
- 컴공 전공 baseline
- GitHub README / 포트폴리오 사이트 구성 가이드

out:
- 미드/시니어 (3년+) 전략
- 해외/원격 시장
- 대학원 진학 / 석박사 연구직
- 비전공자/부트캠퍼 전용 가이드
- 특정 클라우드 vendor 과도한 락인
- AI Ethics / Regulation 별도 가이드 (skill matrix에 통합 표기만)

## Search Plan (queries 초안)

queries:
  - "AI Engineer job description 2026"
  - "Forward Deployed Engineer FDE AI 2026 hiring"
  - "Agent Orchestrator job role 2026"
  - "AI Native Developer skills"
  - "AX 전문가 AI Transformation job Korea"
  - "AX 기획자 직무 JD"
  - "Palantir FDE career path"
  - "LangChain AI Engineer certification"
  - "Anthropic Claude AI Engineer hiring"
  - "OpenAI Forward Deployed Engineer"
  - "AWS AgentCore announcement 2026"
  - "DACON AI Agent 해커톤 수상작"
  - "Naver HyperCLOVA AX 사례"
  - "Kakao AX 조직"
  - "당근 AX 사례"
  - "Toss AI transformation 2026"

## Constraints

- 인용은 primary/secondary 출처에서만.
- 2025-2026 자료 우선 (구직 시장은 빠르게 변함).
- 신규 6직군은 일부 신생 직군이므로 "JD 사례 + 채용공고 + 산업 보고서" cross-verify 필수.
- 기존 5직군 내용은 보존하면서 확장 (덮어쓰기 X).