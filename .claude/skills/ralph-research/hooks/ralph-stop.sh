#!/bin/bash
# ralph-research stop hook
# Self-referential iteration loop for WebSearch research harness.
# Blocks exit until <promise>RESEARCH COMPLETE</promise> is emitted (and true)
# OR max_iterations reached.
#
# State file: .claude/ralph-research.local.md (project-scoped YAML frontmatter + prompt)
# Completion check: parse last assistant text for <promise>RESEARCH COMPLETE</promise>
#                   AND run AC verifier — only succeed if AC verifier also returns PASS.

set -euo pipefail

HOOK_INPUT=$(cat)

# Detect skill root from this script's own location.
# ralph-stop.sh is at <skill_root>/hooks/ralph-stop.sh → dirname x2 = skill_root.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_ROOT="$( dirname "$SCRIPT_DIR" )"
SKILL_ROOT="${CLAUDE_SKILL_ROOT:-$SKILL_ROOT}"

STATE_FILE=".claude/ralph-research.local.md"

# 1. State file must exist.
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# 2. Parse frontmatter.
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
GOAL_PATH=$(echo "$FRONTMATTER" | grep '^goal_path:' | sed 's/goal_path: *//' | sed 's/^"\(.*\)"$/\1/')
STEM=$(echo "$FRONTMATTER" | grep '^stem:' | sed 's/stem: *//' | sed 's/^"\(.*\)"$/\1/')
AUTO_MODE=$(echo "$FRONTMATTER" | grep '^auto_mode:' | sed 's/auto_mode: *//' | sed 's/^"\(.*\)"$/\1/')

# 3. Session isolation.
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# 4. Numeric guards.
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  ralph-research: state file corrupted — stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

# 5. Max iterations reached.
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 ralph-research: max iterations ($MAX_ITERATIONS) reached. Best-effort report saved." >&2
  rm "$STATE_FILE"
  exit 0
fi

# 6. Get last assistant text.
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  ralph-research: transcript_path missing — stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  LAST_OUTPUT=""
else
  LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
  set +e
  LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
    map(.message.content[]? | select(.type == "text") | .text) | last // ""
  ' 2>&1)
  set -e
fi

# 7. Completion-promise detection (only if exact match).
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    # Promise emitted — but VERIFY AC before honoring it.
    # The skill explicitly says: do NOT honor a false promise. Run AC check.
    VERIFY_OUT=""
    VERIFY_RC=1
    if [[ -x "$SKILL_ROOT/scripts/verify-ac.sh" ]] && [[ -n "$GOAL_PATH" ]] && [[ -n "$STEM" ]]; then
      set +e
      VERIFY_OUT=$(bash "$SKILL_ROOT/scripts/verify-ac.sh" \
        --goal "$GOAL_PATH" \
        --report "research_output/${STEM}.md" \
        --sources "research_output/${STEM}.sources.json" 2>&1)
      VERIFY_RC=$?
      set -e
    fi

    # verify-ac.sh returns 0 only if ALL AC PASS.
    if [[ $VERIFY_RC -eq 0 ]]; then
      echo "✅ ralph-research: promise + AC verified ($VERIFY_OUT)" >&2
      rm "$STATE_FILE"
      exit 0
    else
      # Promise was a lie (or AC not yet satisfied). Feed the prompt back.
      echo "⚠️  ralph-research: <promise> emitted but AC verifier returned $VERIFY_RC" >&2
      echo "    verifier output: $VERIFY_OUT" >&2
      echo "    ⛔ Treating as FALSE PROMISE — continuing loop. Do not lie to exit." >&2
      # DO NOT honor the promise; fall through to re-feed.
    fi
  fi
fi

# 8. Not complete (or false promise) — feed prompt back.
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt text (everything after closing --- of frontmatter).
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  ralph-research: state file has no prompt — stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Append iteration-aware guidance so Claude self-corrects instead of looping blindly.
ITERATION_GUIDANCE=""
if [[ $NEXT_ITERATION -ge 3 ]]; then
  REMAINING=$((MAX_ITERATIONS - NEXT_ITERATION + 1))
  ITERATION_GUIDANCE="
---
[iteration $NEXT_ITERATION / max $MAX_ITERATIONS — $REMAINING remaining]

Self-correction checklist (must complete each iteration):
1. Read scratch/goal.md — what AC are still unmet?
2. Re-read research_output/${STEM}.sources.json — what sources do you already have? Do NOT re-fetch duplicates.
3. Identify the GAPS and design queries that target the gaps directly (not broad restatements).
4. Use WebSearch with focused, gap-filling queries. Use WebFetch for each promising URL.
5. If a previous iteration's query returned 0 useful results, try a fundamentally different angle.
6. Update research_output/${STEM}.md and research_output/${STEM}.sources.json.
7. Run: bash ${SKILL_ROOT}/scripts/verify-ac.sh --goal scratch/goal.md --report research_output/${STEM}.md --sources research_output/${STEM}.sources.json
8. ONLY when verify-ac.sh returns 0 (all AC PASS), output <promise>RESEARCH COMPLETE</promise>.
9. Otherwise output a brief plan for the next iteration (which gap, which query)."
fi

# Update iteration counter atomically.
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

SYSTEM_MSG="🔄 ralph-research iteration $NEXT_ITERATION | Auto-mode: ${AUTO_MODE:-off} | To stop: ALL AC must PASS, then output <promise>${COMPLETION_PROMISE}</promise>"

jq -n \
  --arg prompt "${PROMPT_TEXT}${ITERATION_GUIDANCE}" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0