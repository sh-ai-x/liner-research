#!/bin/bash
# ralph-research verify-ac.sh
# Acceptance Criteria verifier — exits 0 only if ALL AC PASS.
# Used by:
#   (a) the stop hook (to gate the <promise>), and
#   (b) each iteration (to decide whether to continue or emit the promise).
#
# Usage:
#   verify-ac.sh --goal <goal.md> --report <report.md> --sources <sources.json>
#
# AC types supported (parsed from goal.md by line):
#   - sources>=N                  : sources.json has >= N entries
#   - sources_authoritative>=N    : >= N entries with reliability_tier in {primary, secondary, tertiary} by heuristic
#   - citations>=N                : >= N [n] markers in report.md
#   - references>=N               : >= N entries in the References section
#   - has_counter_argument        : report.md mentions "반대" OR "counter" OR "limitation" OR "한계" section
#   - min_words=N                 : report.md has >= N words
#   - max_words=N                 : report.md has <= N words
#   - files_exist=<list,csv>      : all listed files exist
#   - all_5_artifacts             : goal.json, plan.json, sources.json, md, raw.jsonl all exist
#
# Default quick-mode AC (if no explicit AC in goal.md, applied automatically):
#   sources>=5, citations>=5, has_counter_argument, min_words=800, files=md+goal+sources

set -euo pipefail

GOAL=""
REPORT=""
SOURCES=""

usage() {
  cat <<'EOF'
verify-ac.sh — verify Acceptance Criteria for a ralph-research run.

USAGE:
  verify-ac.sh --goal <goal.md> --report <report.md> --sources <sources.json>

EXIT CODES:
  0  All AC PASS.
  1  At least one AC failed (printed to stdout as "AC-N name: FAIL (reason)").
  2  Bad arguments / missing files.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --goal) GOAL="${2:-}"; shift 2 ;;
    --report) REPORT="${2:-}"; shift 2 ;;
    --sources) SOURCES="${2:-}"; shift 2 ;;
    *) echo "❌ unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$GOAL" ]] || [[ -z "$REPORT" ]] || [[ -z "$SOURCES" ]]; then
  echo "❌ --goal, --report, --sources all required" >&2; usage; exit 2
fi
if [[ ! -f "$GOAL" ]]; then echo "❌ goal file missing: $GOAL" >&2; exit 2; fi
if [[ ! -f "$REPORT" ]]; then echo "❌ report file missing: $REPORT" >&2; exit 2; fi
if [[ ! -f "$SOURCES" ]]; then echo "❌ sources file missing: $SOURCES" >&2; exit 2; fi

# ----- helpers ---------------------------------------------------------------

word_count() {
  wc -w < "$1" | tr -d ' '
}

citation_count() {
  # Count [n] markers — only those in body, not the References section.
  perl -0777 -ne 'while (/\[(\d+)\]/g) { print "$1\n" }' "$1" \
    | sort -u | wc -l | tr -d ' '
}

# Extract explicit AC list from goal.md.
# Format expected:
#   ## Acceptance Criteria
#   - [ ] AC-1: <description>
#   - [ ] AC-2: <description>
#   ...
# Description patterns (heuristic — first matching wins):
#   "출처 >= N" / "sources >= N"        → sources>=N
#   "권위 소스 >= N"                     → sources_authoritative>=N
#   "인용 >= N" / "citations >= N"       → citations>=N
#   "분량 >= N" / "min_words >= N"       → min_words=N
#   "분량 <= N" / "max_words <= N"       → max_words=N
#   "반대 입론" / "counter"              → has_counter_argument
#   "산출물" / "artifacts" / "files"     → files_exist=<list>
extract_ac() {
  local goal="$1"
  # Pull out lines starting with "- [ ]" under any heading.
  grep -E '^- \[ \] ' "$goal" || true
}

# ----- extract sources.json --------------------------------------------------

SOURCES_JSON="$SOURCES"
SOURCE_COUNT=$(jq 'length' "$SOURCES_JSON" 2>/dev/null || echo 0)

# Reliability tier inference: primary = .gov/.edu/.org/academic/arXiv/peer-reviewed
#                            secondary = major news/established industry
#                            tertiary = blog/forums/unknown
AUTH_COUNT=$(jq '[.[] | select(
  (.url // "" | test("(\\.gov|\\.edu|\\.ac\\.|arxiv\\.org|nature\\.com|science\\.org|ieee\\.org|acm\\.org|pubmed|ncbi\\.nih\\.gov|jstor\\.org|springer\\.com|wiley\\.com|cell\\.com|thelancet\\.com|bmj\\.com|nejm\\.org)")) or
  (.tier // "" | . == "primary")
)] | length' "$SOURCES_JSON" 2>/dev/null || echo 0)

REPORT_WORDS=$(word_count "$REPORT")
CITATION_COUNT=$(citation_count "$REPORT")

# Counter-argument detection.
if grep -qiE '반대|counter[ -]argument|limitation|한계|opposing view|반박' "$REPORT"; then
  HAS_COUNTER=1
else
  HAS_COUNTER=0
fi

# ----- evaluate ACs ----------------------------------------------------------

passed=0
failed=0
ac_lines=$(extract_ac "$GOAL")

# Default ACs if none specified.
if [[ -z "$ac_lines" ]]; then
  ac_lines="- [ ] sources>=5
- [ ] citations>=5
- [ ] has_counter_argument
- [ ] min_words=800
- [ ] files_exist=md+goal+sources"
fi

eval_one() {
  local label="$1"; shift
  local rule="$1"; shift
  local detail=""
  case "$rule" in
    sources=*)
      local n="${rule#sources=}"; n="${n// /}"
      if [[ $SOURCE_COUNT -ge $n ]]; then
        echo "PASS|$label|sources=$SOURCE_COUNT >= $n"
      else
        echo "FAIL|$label|sources=$SOURCE_COUNT < $n"
      fi
      ;;
    sources_authoritative=*)
      local n="${rule#sources_authoritative=}"; n="${n// /}"
      if [[ $AUTH_COUNT -ge $n ]]; then
        echo "PASS|$label|authoritative=$AUTH_COUNT >= $n"
      else
        echo "FAIL|$label|authoritative=$AUTH_COUNT < $n"
      fi
      ;;
    citations=*)
      local n="${rule#citations=}"; n="${n// /}"
      if [[ $CITATION_COUNT -ge $n ]]; then
        echo "PASS|$label|citations=$CITATION_COUNT >= $n"
      else
        echo "FAIL|$label|citations=$CITATION_COUNT < $n"
      fi
      ;;
    min_words=*)
      local n="${rule#min_words=}"; n="${n// /}"
      if [[ $REPORT_WORDS -ge $n ]]; then
        echo "PASS|$label|words=$REPORT_WORDS >= $n"
      else
        echo "FAIL|$label|words=$REPORT_WORDS < $n"
      fi
      ;;
    max_words=*)
      local n="${rule#max_words=}"; n="${n// /}"
      if [[ $REPORT_WORDS -le $n ]]; then
        echo "PASS|$label|words=$REPORT_WORDS <= $n"
      else
        echo "FAIL|$label|words=$REPORT_WORDS > $n"
      fi
      ;;
    has_counter_argument)
      if [[ $HAS_COUNTER -eq 1 ]]; then
        echo "PASS|$label|counter_argument section present"
      else
        echo "FAIL|$label|no counter-argument/limitation section"
      fi
      ;;
    files_exist=*)
      local list="${rule#files_exist=}"
      local missing=""
      IFS=',' read -ra parts <<< "$list"
      for p in "${parts[@]}"; do
        # Resolve relative to project root (cwd).
        if [[ ! -f "$p" ]] && [[ ! -f "research_output/$p" ]] && [[ ! -f "scratch/$p" ]]; then
          # Special tokens.
          case "$p" in
            md) [[ -f "$REPORT" ]] || missing="$missing md" ;;
            goal) [[ -f "$GOAL" ]] || missing="$missing goal" ;;
            sources) [[ -f "$SOURCES_JSON" ]] || missing="$missing sources" ;;
            plan) [[ -f "research_output/$(basename "$SOURCES_JSON" .sources.json).plan.json" ]] || missing="$missing plan" ;;
            raw) [[ -f "research_output/$(basename "$SOURCES_JSON" .sources.json).raw.jsonl" ]] || missing="$missing raw" ;;
            *) missing="$missing $p" ;;
          esac
        fi
      done
      if [[ -z "$missing" ]]; then
        echo "PASS|$label|files_exist ok"
      else
        echo "FAIL|$label|missing files:$missing"
      fi
      ;;
    all_5_artifacts)
      local stem
      stem=$(basename "$SOURCES_JSON" .sources.json)
      local miss=""
      [[ ! -f "$GOAL" ]] && miss="$miss goal"
      [[ ! -f "research_output/${stem}.plan.json" ]] && miss="$miss plan"
      [[ ! -f "$SOURCES_JSON" ]] && miss="$miss sources"
      [[ ! -f "$REPORT" ]] && miss="$miss md"
      [[ ! -f "research_output/${stem}.raw.jsonl" ]] && miss="$miss raw"
      if [[ -z "$miss" ]]; then
        echo "PASS|$label|all 5 artifacts present"
      else
        echo "FAIL|$label|missing:$miss"
      fi
      ;;
    project_slots_min=*)
      # report.md must have a markdown table with at least N rows where each row
      # has 5+ columns (title, description, tech stack, README, differentiation).
      local n="${rule#project_slots_min=}"; n="${n// /}"
      # Count table rows: lines starting with "| " that have ≥5 "|" separators.
      local count
      count=$(awk -F'|' '
        /^[[:space:]]*\|.*\|/ && NF >= 6 { c++ }
        END { print c+0 }
      ' "$REPORT")
      if [[ $count -ge $n ]]; then
        echo "PASS|$label|project_slot_rows=$count >= $n"
      else
        echo "FAIL|$label|project_slot_rows=$count < $n"
      fi
      ;;
    skill_matrix_rows=*)
      # report.md must have a markdown table with exactly N rows of skill matrix
      # (header + separator + N data rows). The matrix table should have
      # ≥5 columns (직군 + Hard + Soft + Tool + 인증).
      local n="${rule#skill_matrix_rows=}"; n="${n// /}"
      local count
      count=$(awk -F'|' '
        /^[[:space:]]*\|.*\|.*\|.*\|.*\|.*\|/ { c++ }
        END { print c+0 }
      ' "$REPORT")
      if [[ $count -ge $((n + 2)) ]]; then
        # +2 for header row + separator row
        echo "PASS|$label|skill_matrix_rows=$((count - 2)) >= $n"
      else
        echo "FAIL|$label|skill_matrix_rows=$((count - 2)) < $n"
      fi
      ;;
    cluster_keywords=*)
      # All keywords (comma-separated) must appear in the report at least once.
      local list="${rule#cluster_keywords=}"
      local missing=""
      IFS=',' read -ra kws <<< "$list"
      for kw in "${kws[@]}"; do
        kw_trimmed="${kw// /}"
        if ! grep -qF "$kw_trimmed" "$REPORT" 2>/dev/null; then
          missing="$missing [$kw_trimmed]"
        fi
      done
      if [[ -z "$missing" ]]; then
        echo "PASS|$label|all cluster keywords present: $list"
      else
        echo "FAIL|$label|missing cluster keywords:$missing"
      fi
      ;;
    new_role_count=*)
      # At least N of the 6 new AI-era roles must appear in the report.
      local n="${rule#new_role_count=}"; n="${n// /}"
      local role_names=("AI Engineer" "FDE" "Agent Orchestrator" "AI Native Developer" "AX 전문가" "AX 기획자")
      local found=0
      local missing=""
      for r in "${role_names[@]}"; do
        if grep -qF "$r" "$REPORT" 2>/dev/null; then
          found=$((found+1))
        else
          missing="$missing [$r]"
        fi
      done
      if [[ $found -ge $n ]]; then
        echo "PASS|$label|new_roles_found=$found >= $n"
      else
        echo "FAIL|$label|new_roles_found=$found < $n (missing:$missing)"
      fi
      ;;
    *)
      echo "UNKNOWN|$label|rule=$rule" ;;
  esac
}

# Parse AC lines: "- [ ] AC-N: <rule> [| description]"
output=""
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  # Strip "- [ ] " prefix.
  body="${line#- \[ \] }"
  # Split first colon.
  label="${body%%:*}"
  rest="${body#*:}"
  rest="${rest# }"

  # If rest looks like a free-text description, try to detect a rule.
  rule=""
  case "$rest" in
    *"sources_authoritative>=*"*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="sources_authoritative=$n" ;;
    *"sources>="*|*"출처>="*|*"출원수>="*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="sources=$n" ;;
    *"citations>="*|*"인용>="*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="citations=$n" ;;
    *"references>="*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="citations=$n" ;;
    *"분량>="*|*"min_words>="*|*"단어>="*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="min_words=$n" ;;
    *"분량<="*|*"max_words<="*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="max_words=$n" ;;
    *"반대 입론"*|*"counter"*|*"limitation"*) rule="has_counter_argument" ;;
    *"산출물"*|*"artifacts"*) rule="all_5_artifacts" ;;
    *"files"*) rule="files_exist=md,goal,sources" ;;
    *"프로젝트 슬롯"*|*"project_slot"*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="project_slots_min=$n" ;;
    *"skill matrix"*|*"skill_matrix"*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="skill_matrix_rows=$n" ;;
    *"4클러스터"*|*"cluster_keywords"*) rule="cluster_keywords=전통데이터,AI-builder,AI-deployer,AI-strategist" ;;
    *"신규 6직군"*|*"new_role"*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="new_role_count=$n" ;;
    *"4클러스터"*|*"cluster_keywords"*) rule="cluster_keywords=전통데이터,AI-builder,AI-deployer,AI-strategist" ;;
    *"신규 6직군"*|*"new_role"*) n=$(echo "$rest" | grep -oE '[0-9]+' | head -1); rule="new_role_count=$n" ;;
  esac

  if [[ -z "$rule" ]]; then
    # Try to use rest verbatim as a known rule (handle both = and >= notation).
    case "$rest" in
      has_counter_argument|sources_authoritative=*|sources_authoritative\>*|sources=*|sources\>*|citations=*|citations\>*|min_words=*|min_words\>*|max_words=*|max_words\<*|files_exist=*|all_5_artifacts|project_slots_min=*|skill_matrix_rows=*|cluster_keywords=*|new_role_count=*)
        # Normalize >= to =, <= to = for the verifier.
        # IMPORTANT: extract ONLY the rule portion (everything before the first
        # description separator: em-dash, hyphen with spaces, or common list separators).
        # Otherwise n="${rule#sources_authoritative=}" would include Korean/English
        # description text and the numeric comparison would fail.
        normalized=$(echo "$rest" | sed -E '
          s/(>=|=>)/=/g
          s/(<=|=<=)/=/g
          s/[ ]*[—–-][ ].*$//
          s/[ ][(].*$//
        ')
        rule="$normalized" ;;
      *)
        output+="$line"$'\t'"UNPARSED|$label|free-text: $rest"$'\n'
        failed=$((failed+1))
        continue ;;
    esac
  fi

  result=$(eval_one "$label" "$rule")
  output+="$line"$'\t'"$result"$'\n'
  case "$result" in
    PASS*) passed=$((passed+1)) ;;
    FAIL*) failed=$((failed+1)) ;;
    UNKNOWN*) failed=$((failed+1)) ;;
  esac
done <<< "$ac_lines"

# ----- summary ---------------------------------------------------------------

total=$((passed + failed))
echo "=== AC verification ==="
echo "sources=$SOURCE_COUNT (authoritative=$AUTH_COUNT)  report_words=$REPORT_WORDS  citations=$CITATION_COUNT  counter=$HAS_COUNTER"
echo ""
echo "$output"
echo "---"
echo "PASS: $passed / $total"
if [[ $failed -eq 0 ]]; then
  echo "Overall: ALL_AC_PASS"
  exit 0
else
  echo "Overall: $failed FAILED — continue iteration"
  exit 1
fi