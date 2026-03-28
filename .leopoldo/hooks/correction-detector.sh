#!/usr/bin/env bash
# correction-detector.sh — UserPromptSubmit hook for Leopoldo.
# Detects correction signals and ENFORCES postmortem before any fix.
# Sets postmortem gate in gates.json so gate-enforcer can block.
# Never blocks directly (always exits 0) — enforcement via gate-enforcer.

set -euo pipefail
trap 'exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

# Read user prompt from stdin
INPUT="$(cat)"

# Extract prompt text
PROMPT=""
if command -v jq &>/dev/null; then
  PROMPT="$(echo "$INPUT" | jq -r '.prompt // .message // ""' 2>/dev/null || echo "$INPUT")"
else
  PROMPT="$INPUT"
fi

# Empty prompt — nothing to check
if [[ -z "$PROMPT" ]]; then
  exit 0
fi

# Correction signal patterns (case-insensitive, word boundaries)
# Italian signals
IT_PATTERN='\b(sbagliato|rifai|non funziona|non è corretto|non e'\'' corretto|correggi|è sbagliato|e'\'' sbagliato|errore|non va)\b'
# English signals
EN_PATTERN='\b(wrong|redo|that'\''s not right|thats not right|try again|not what I asked|incorrect|fix this|not correct|broken)\b'
# Implicit correction signals (user provides corrected version or rejects output)
REJECT_PATTERN='\b(no[, ] (intendevo|volevo|doveva)|I meant|should have been|dovrebbe essere)\b'

DETECTED=false
if echo "$PROMPT" | grep -iEq "$IT_PATTERN" 2>/dev/null || \
   echo "$PROMPT" | grep -iEq "$EN_PATTERN" 2>/dev/null || \
   echo "$PROMPT" | grep -iEq "$REJECT_PATTERN" 2>/dev/null; then
  DETECTED=true
fi

if [[ "$DETECTED" == "true" ]]; then
  ROOT="$(find_project_root)"
  TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Set postmortem gate in gates.json — this is ENFORCED by gate-enforcer
  read_gate_state
  if _has_jq && [[ -n "$GATE_STATE_RAW" ]]; then
    update_gate_field "
      .postmortem.required = true
      | .postmortem.detected_at = \"$TIMESTAMP\"
      | .postmortem.completed = false
      | .postmortem.user_signal = \"$(echo "$PROMPT" | head -c 200 | jq -Rs '.' | sed 's/^"//;s/"$//')\"
    "
  fi

  # Log correction detection to journal
  journal_append "{\"event\":\"correction.detected\",\"session_id\":\"$GATE_SESSION_ID\",\"timestamp\":\"$TIMESTAMP\"}"

  # Strong enforcement context — not a suggestion, an obligation
  cat <<'EOF'
{"additionalContext": "🔴 CORRECTION DETECTED — POSTMORTEM MANDATORY. You MUST run the skill-postmortem workflow (Phases 1-3 minimum) BEFORE attempting any fix. This is mechanically enforced: gate-enforcer will BLOCK your response if postmortem is not completed. After completing the postmortem, log the event: append {\"event\":\"postmortem.completed\",...} to the journal via Bash. Only then proceed to fix. If Imprint is enabled, also append an observation to .leopoldo/imprint/observations.jsonl."}
EOF
fi

exit 0
