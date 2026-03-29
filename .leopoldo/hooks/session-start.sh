#!/usr/bin/env bash
# session-start.sh — SessionStart hook for Leopoldo.
# Initializes session state, resets gate counters, loads Imprint profile,
# and triggers Imprint processing if there are pending observations.
# Always exits 0. Never blocks session start.

set -euo pipefail
trap 'exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

ROOT="$(find_project_root)"

# Ensure .state directories exist
mkdir -p "$ROOT/.state/journal"
mkdir -p "$ROOT/.state/snapshots"
mkdir -p "$ROOT/.state/evolution"

# Generate session ID
SESSION_ID="ses_$(date +%Y%m%d_%H%M%S)"

# Create or reset gates.json
GATES_FILE="$ROOT/.state/gates.json"

if [[ -f "$GATES_FILE" ]] && _has_jq && jq empty "$GATES_FILE" 2>/dev/null; then
  # Preserve enforcement levels, reset counters, ensure postmortem field exists
  UPDATED="$(jq \
    --arg sid "$SESSION_ID" \
    '.session_id = $sid
     | .checkpoint_threshold = 5
     | .gates["doc-gate"].soft_warnings = 0
     | .postmortem = {"required": false, "detected_at": null, "completed": false, "user_signal": null}
     | .overrides = []' \
    "$GATES_FILE")"
  write_gate_state "$UPDATED"
else
  # Create fresh gates.json with postmortem tracking
  write_gate_state "$(cat <<EOF
{
  "version": "2.0.0",
  "session_id": "$SESSION_ID",
  "task_count_since_checkpoint": 0,
  "checkpoint_threshold": 5,
  "current_phase": null,
  "gates": {
    "checkpoint": {"status": "clear", "enforcement": "soft", "soft_warnings": 0},
    "doc-gate": {"status": "clear", "enforcement": "soft", "soft_warnings": 0},
    "phase-gate": {"status": "clear", "enforcement": "hard", "skills_required": [], "skills_invoked": []},
    "security-gate": {"status": "clear", "enforcement": "hard"}
  },
  "postmortem": {
    "required": false,
    "detected_at": null,
    "completed": false,
    "user_signal": null
  },
  "overrides": []
}
EOF
)"
fi

# Log session start to journal
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
journal_append "{\"event\":\"session.start\",\"session_id\":\"$SESSION_ID\",\"timestamp\":\"$TIMESTAMP\"}"

# Build additional context
CONTEXT="Leopoldo session $SESSION_ID started. Gate enforcement active."

# Check for pending evolution tasks
STATE_FILE="$ROOT/.state/state.json"
if [[ -f "$STATE_FILE" ]] && _has_jq; then
  PENDING="$(jq -r '.evolution.pending_tasks // [] | length' "$STATE_FILE" 2>/dev/null || echo "0")"
  if [[ "$PENDING" -gt 0 ]]; then
    CONTEXT="$CONTEXT $PENDING pending evolution task(s)."
  fi
fi

# --- Imprint ---

IMPRINT_CONFIG="$ROOT/.leopoldo/imprint/config.json"
IMPRINT_PROFILE="$ROOT/.leopoldo/imprint/profile.json"
IMPRINT_OBS="$ROOT/.leopoldo/imprint/observations.jsonl"

# Check if Imprint is enabled
IMPRINT_ENABLED=false
if [[ -f "$IMPRINT_CONFIG" ]] && _has_jq; then
  IMPRINT_ENABLED="$(jq -r '.enabled // false' "$IMPRINT_CONFIG" 2>/dev/null || echo "false")"
fi

if [[ "$IMPRINT_ENABLED" == "true" ]]; then

  # FIX 1: Inject full profile JSON (not flattened string)
  if [[ -f "$IMPRINT_PROFILE" ]] && _has_jq; then
    PROFILE_CONTENT="$(jq -c '.calibrations // {}' "$IMPRINT_PROFILE" 2>/dev/null || echo "{}")"
    if [[ "$PROFILE_CONTENT" != "{}" ]]; then
      CONTEXT="$CONTEXT IMPRINT_ACTIVE. Apply these user calibrations to all outputs: $PROFILE_CONTENT"
    fi
  fi

  # FIX 3: Check for unprocessed observations from previous sessions
  if [[ -f "$IMPRINT_OBS" ]]; then
    OBS_COUNT="$(wc -l < "$IMPRINT_OBS" | tr -d ' ')"
    if [[ "$OBS_COUNT" -gt 0 ]]; then
      CONTEXT="$CONTEXT IMPRINT_PROCESS_REQUIRED: $OBS_COUNT unprocessed observations from previous sessions. Before handling the user request, silently process them: read .leopoldo/imprint/observations.jsonl and .leopoldo/imprint/profile.json, synthesize updated calibrations following the Imprint Processing Template, write updated profile.json, append processed lines to observations.processed.jsonl, then clear observations.jsonl. Do this silently without mentioning it to the user."
    fi
  fi

fi

# --- Environment Quick Check (conditional) ---
# Only scan when cache is stale (>24h) or MCP config changed since last scan.
# Sets ENV_SCAN_NEEDED flag for orchestrator to dispatch environment-agent.

MANIFEST="$ROOT/.leopoldo-manifest.json"
MCP_LOCAL="$ROOT/.mcp.json"
MCP_HOME="$HOME/.claude/mcp.json"

needs_env_scan=false

if [ ! -f "$MANIFEST" ]; then
  needs_env_scan=true
else
  # Check cache age (>24h = stale)
  if _has_jq; then
    last_scan=$(jq -r '.environment.last_scan // empty' "$MANIFEST" 2>/dev/null)
    if [ -z "$last_scan" ]; then
      needs_env_scan=true
    else
      manifest_mtime=$(stat -f %m "$MANIFEST" 2>/dev/null || stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)
      now=$(date +%s)
      age=$(( now - manifest_mtime ))
      if [ "$age" -gt 86400 ]; then
        needs_env_scan=true
      fi
    fi
  fi
  # Check MCP config changes (mtime newer than manifest)
  if [ -f "$MCP_LOCAL" ] && [ "$MCP_LOCAL" -nt "$MANIFEST" ]; then
    needs_env_scan=true
  fi
  if [ -f "$MCP_HOME" ] && [ "$MCP_HOME" -nt "$MANIFEST" ]; then
    needs_env_scan=true
  fi
fi

if $needs_env_scan; then
  CONTEXT="$CONTEXT ENV_SCAN_NEEDED: environment cache stale or missing. Dispatch environment-agent for quick MCP re-scan before handling user request."
fi

# Output JSON for Claude Code — use jq to properly escape the context string
if _has_jq; then
  jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
else
  # Fallback: basic escaping
  ESCAPED_CONTEXT="$(echo "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')"
  echo "{\"additionalContext\": \"$ESCAPED_CONTEXT\"}"
fi

exit 0
