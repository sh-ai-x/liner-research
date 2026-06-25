#!/bin/bash
# ralph-research restate.sh — structured reminder for the Discussing phase.
# The skill itself calls Claude (Opus) with the DISCUSSING_SYSTEM prompt.
# This helper just packages the state for that call.
#
# Usage:
#   restate.sh --seed "<seed>" --user-context '<JSON list>' --candidates '<JSON list>' [--out <path>]

set -euo pipefail

SEED=""
USER_CTX="[]"
CANDS="[]"
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed) SEED="${2:-}"; shift 2 ;;
    --user-context) USER_CTX="${2:-[]}"; shift 2 ;;
    --candidates) CANDS="${2:-[]}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "❌ unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SEED" ]]; then echo "❌ --seed required" >&2; exit 2; fi

# Validate JSON.
echo "$USER_CTX" | jq . >/dev/null || { echo "❌ --user-context invalid JSON" >&2; exit 2; }
echo "$CANDS" | jq . >/dev/null || { echo "❌ --candidates invalid JSON" >&2; exit 2; }

SCOPE=$(jq -n \
  --arg seed "$SEED" \
  --argjson ctx "$USER_CTX" \
  --argjson cands "$CANDS" \
  '{seed: $seed, user_replies: $ctx, candidates: $cands}')

if [[ -n "$OUT" ]]; then
  echo "$SCOPE" > "$OUT"
  echo "wrote: $OUT"
else
  echo "$SCOPE"
fi