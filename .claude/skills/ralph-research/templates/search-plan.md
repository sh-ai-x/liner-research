# Search Plan

> Goal: <goal.md 한 줄>
> Stem: <stem>
> Iterations: <N>

## Queries (초안)

| # | Query | Target AC | Expected source type |
|---|---|---|---|
| 1 | <query> | AC-1, AC-2 | academic / industry report |
| 2 | <query> | AC-4 | counter-argument source |
| 3 | <query> | AC-2 | authoritative domain |
| 4 | <query> | AC-3 | empirical data |
| 5 | <query> | AC-1 | 2026 trend |

## Iteration History

### Iteration 1 — YYYY-MM-DD HH:MM

queries used:
- "..."
- "..."

sources added: 4 (2 academic, 1 news, 1 blog)
gap analysis:
- AC-2 still short (2/4 authoritative)
- AC-4 not yet addressed

next plan:
- query for "limitations of X" → AC-4
- query for "<topic> IEEE/Nature 2025 2026" → AC-2

### Iteration 2 — ...

(append each iteration)

## Reliability Tiers

- **primary**: peer-reviewed papers, official docs, .gov/.edu/.ac
- **secondary**: established industry (IEEE Spectrum, ACM TechNews, Nature News, Reuters, AP, 공식 블로그 of major vendors)
- **tertiary**: blog posts, Medium, personal sites — only as supporting evidence

## Failure Handlers

- 0 WebSearch results → query paraphrase 3x, then synthesize with explicit "no live source" tag
- WebFetch timeout → skip URL, try next
- Duplicate source detected (same URL) → increment relevance_count, do NOT add new card