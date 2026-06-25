#!/bin/bash
# ralph-research setup-loop.sh
# Initializes the Ralph Wiggum self-referential loop for the WebSearch research harness.
#
# Usage:
#   bash setup-loop.sh --seed "<original seed>" --goal <goal.md> --stem <stem> \
#                       [--max-iterations N] [--completion-promise TEXT] [--auto-mode on|off]
#
# State is written to: .claude/ralph-research.local.md
# The stop hook (hooks/ralph-stop.sh) intercepts exit and feeds the prompt back
# until <promise>...</promise> is emitted AND AC verifier passes.

set -euo pipefail

# Detect skill root from this script's own location.
# setup-loop.sh is at <skill_root>/scripts/setup-loop.sh → dirname x2 = skill_root.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_ROOT="$( dirname "$SCRIPT_DIR" )"

# Allow override via env var.
SKILL_ROOT="${RALPH_RESEARCH_SKILL_ROOT:-$SKILL_ROOT}"

SEED=""
GOAL_PATH=""
STEM=""
MAX_ITERATIONS=10
COMPLETION_PROMISE="RESEARCH COMPLETE"
AUTO_MODE="off"

usage() {
  cat <<'EOF'
ralph-research setup-loop — start a RALPH iteration loop for WebSearch research.

USAGE:
  setup-loop.sh --seed "<seed>" --goal <path.md> --stem <stem> \
                [--max-iterations N] [--completion-promise TEXT] [--auto-mode on|off]

OPTIONS:
  --seed <text>            Original research seed (string).
  --goal <path>            Path to scratch/goal.md (already converged).
  --stem <name>            Output stem (used for research_output/<stem>.md etc).
  --max-iterations <N>     Max iterations before auto-stop (default: 10).
  --completion-promise <T> Promise phrase to honor (default: "RESEARCH COMPLETE").
  --auto-mode <on|off>     Whether interview was bypassed (default: off).
  -h, --help               Show this help.

EXIT CODES:
  0  Loop started.
  2  Bad arguments.
  3  Goal file not found.

DESCRIPTION:
  Writes .claude/ralph-research.local.md (YAML frontmatter + initial prompt).
  The stop hook (hooks/ralph-stop.sh) intercepts every Claude Code exit attempt
  and re-feeds the prompt until either:
    (a) Claude outputs <promise>RESEARCH COMPLETE</promise> AND verify-ac.sh passes, or
    (b) max iterations reached.

EXAMPLES:
  # Start a 10-iteration research loop on AI agent memory.
  setup-loop.sh --seed "AI agent memory architectures" \
                --goal scratch/goal-ai-memory.md \
                --stem ai-memory \
                --max-iterations 8

  # Auto mode (interview was already bypassed).
  setup-loop.sh --seed "fastapi vs flask 2026" \
                --goal scratch/goal-fastapi.md \
                --stem fastapi-2026 \
                --auto-mode on \
                --max-iterations 6

MONITORING:
  # Current iteration:
  grep '^iteration:' .claude/ralph-research.local.md
  # Full state:
  head -15 .claude/ralph-research.local.md

STOPPING:
  Cannot be stopped manually from inside the loop.
  Use --max-iterations as the safety net, or set --completion-promise and have
  Claude emit it after verify-ac.sh passes.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --seed)
      [[ -z "${2:-}" ]] && { echo "❌ --seed requires value" >&2; exit 2; }
      SEED="$2"; shift 2 ;;
    --goal)
      [[ -z "${2:-}" ]] && { echo "❌ --goal requires value" >&2; exit 2; }
      GOAL_PATH="$2"; shift 2 ;;
    --stem)
      [[ -z "${2:-}" ]] && { echo "❌ --stem requires value" >&2; exit 2; }
      STEM="$2"; shift 2 ;;
    --max-iterations)
      [[ -z "${2:-}" ]] && { echo "❌ --max-iterations requires value" >&2; exit 2; }
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ --max-iterations must be a non-negative integer (got: $2)" >&2; exit 2
      fi
      MAX_ITERATIONS="$2"; shift 2 ;;
    --completion-promise)
      [[ -z "${2:-}" ]] && { echo "❌ --completion-promise requires value" >&2; exit 2; }
      COMPLETION_PROMISE="$2"; shift 2 ;;
    --auto-mode)
      [[ -z "${2:-}" ]] && { echo "❌ --auto-mode requires on|off" >&2; exit 2; }
      [[ "$2" != "on" && "$2" != "off" ]] && { echo "❌ --auto-mode must be on or off (got: $2)" >&2; exit 2; }
      AUTO_MODE="$2"; shift 2 ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      usage; exit 2 ;;
  esac
done

# Validate.
if [[ -z "$SEED" ]]; then echo "❌ --seed required" >&2; usage; exit 2; fi
if [[ -z "$GOAL_PATH" ]]; then echo "❌ --goal required" >&2; usage; exit 2; fi
if [[ -z "$STEM" ]]; then echo "❌ --stem required" >&2; usage; exit 2; fi
if [[ ! -f "$GOAL_PATH" ]]; then echo "❌ goal file not found: $GOAL_PATH" >&2; exit 3; fi

# Ensure directories exist.
mkdir -p .claude research_output

# Auto-register Stop hook in .claude/settings.local.json (idempotent).
HOOK_CMD="bash ${SKILL_ROOT}/hooks/ralph-stop.sh"
SETTINGS_FILE=".claude/settings.local.json"
if [[ -f "$SETTINGS_FILE" ]]; then
  if ! grep -q "ralph-stop.sh" "$SETTINGS_FILE" 2>/dev/null; then
    # Append the hook entry. We merge into existing JSON minimally — using jq if available.
    if command -v jq >/dev/null 2>&1; then
      TMP_SETTINGS="${SETTINGS_FILE}.tmp.$$"
      jq --arg cmd "$HOOK_CMD" '
        .hooks.Stop = ((.hooks.Stop // []) + [{hooks: [{type: "command", command: $cmd}]}])
      ' "$SETTINGS_FILE" > "$TMP_SETTINGS" && mv "$TMP_SETTINGS" "$SETTINGS_FILE"
      echo "ℹ️  registered ralph-research Stop hook in ${SETTINGS_FILE}"
    else
      echo "⚠️  jq not found — please manually register Stop hook in ${SETTINGS_FILE}:" >&2
      echo "    { \"hooks\": { \"Stop\": [{ \"hooks\": [{ \"type\": \"command\", \"command\": \"${HOOK_CMD}\" }] }] } }" >&2
    fi
  fi
else
  # Create fresh settings.local.json with the hook.
  cat > "$SETTINGS_FILE" <<JSON
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${HOOK_CMD}"
          }
        ]
      }
    ]
  }
}
JSON
  echo "ℹ️  created ${SETTINGS_FILE} with ralph-research Stop hook"
fi

# Initial prompt — this is what gets re-fed each iteration.
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
INITIAL_PROMPT=$(cat <<EOF
You are running inside a ralph-research self-referential loop.
Original seed: ${SEED}
Goal spec:     ${GOAL_PATH}
Output stem:   ${STEM}
Iteration:     1 / ${MAX_ITERATIONS}

DO EACH ITERATION:
1. Read ${GOAL_PATH} to recall the goal and AC.
2. Read research_output/${STEM}.sources.json (if exists) — what sources do you already have?
3. Read research_output/${STEM}.md (if exists) — what have you written?
4. Identify the GAPS: which ACs are unmet, which sub-questions are still open?
5. For each gap, design 1-3 focused WebSearch queries (NOT broad restatements).
6. Use the WebSearch tool. Then WebFetch each promising URL.
7. Update research_output/${STEM}.sources.json with new cards (title, url, snippet, fetched_at, reliability_tier, ac_satisfied[]).
8. Update research_output/${STEM}.md with new findings + inline citations [n].
9. Run: bash ${SKILL_ROOT}/scripts/verify-ac.sh \\
       --goal ${GOAL_PATH} \\
       --report research_output/${STEM}.md \\
       --sources research_output/${STEM}.sources.json
10. If verify-ac.sh exits 0 (all AC PASS): output <promise>${COMPLETION_PROMISE}</promise> on its own line. The hook will verify before exiting.
11. If verify-ac.sh exits non-zero: print a brief "Next iteration plan: <gap> → <query>" line and stop. The hook will re-feed this prompt.

STRICT RULES:
- Do NOT output a false <promise>. The hook runs verify-ac.sh; a lie is detected and the loop continues.
- Do NOT repeat queries that already returned results in earlier iterations (check sources.json).
- Do NOT pad the report with content unrelated to the ACs.
- Do NOT exceed 1 fetch per URL per iteration.
EOF
)

# Quote strings that may contain colons for YAML.
quote_yaml() {
  local s="$1"
  if [[ "$s" == *":"* ]] || [[ "$s" == *"#"* ]] || [[ "$s" == "\""* ]]; then
    printf '"%s"' "$(printf '%s' "$s" | sed 's/"/\\"/g')"
  else
    printf '%s' "$s"
  fi
}

cat > .claude/ralph-research.local.md <<EOF
---
active: true
iteration: 1
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: ${MAX_ITERATIONS}
completion_promise: "$(printf '%s' "$COMPLETION_PROMISE" | sed 's/"/\\"/g')"
seed: $(quote_yaml "$SEED")
goal_path: $(quote_yaml "$GOAL_PATH")
stem: $(quote_yaml "$STEM")
auto_mode: "${AUTO_MODE}"
started_at: "${TIMESTAMP}"
---

${INITIAL_PROMPT}
EOF

cat <<EOF
🔄 ralph-research loop activated.

  seed:           ${SEED}
  goal:           ${GOAL_PATH}
  stem:           ${STEM}
  iteration:      1 / ${MAX_ITERATIONS}
  auto_mode:      ${AUTO_MODE}
  completion:     <promise>${COMPLETION_PROMISE}</promise> (only honored after verify-ac.sh passes)

Monitor:
  grep '^iteration:' .claude/ralph-research.local.md

Stop safely:
  Wait for verify-ac.sh to pass (auto) or ${MAX_ITERATIONS} iterations (auto).
  Manual escape: rm .claude/ralph-research.local.md  (next exit succeeds immediately)

🔄
EOF