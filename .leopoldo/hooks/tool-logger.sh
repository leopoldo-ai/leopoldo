#!/usr/bin/env bash
# tool-logger.sh — PostToolUse hook for Leopoldo.
# Logs tool usage to journal. Tracks task_count_since_checkpoint in gates.json.
# Activates checkpoint gate when threshold reached (default: 3 Edit/Write bursts).
# Detects postmortem.completed signals from Bash tool output.
# Always exits 0 (PostToolUse cannot block).

set -euo pipefail
trap 'exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

ROOT="$(find_project_root)"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Read tool info from stdin
INPUT="$(cat)"

TOOL_NAME=""
FILE_PATH=""
TOOL_OUTPUT=""

if _has_jq; then
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // .tool // ""' 2>/dev/null || echo "")"
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .file_path // .tool_input.command // ""' 2>/dev/null || echo "")"
  TOOL_OUTPUT="$(echo "$INPUT" | jq -r '.tool_output // .output // ""' 2>/dev/null || echo "")"
else
  TOOL_NAME="$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null | head -1 | sed 's/.*"tool_name"[[:space:]]*:[[:space:]]*"//;s/"$//' || echo "")"
  FILE_PATH="$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' || echo "")"
fi

# Read gate state for session_id
read_gate_state

# Log tool.used event to journal
journal_append "{\"event\":\"tool.used\",\"tool\":\"$TOOL_NAME\",\"file\":\"$FILE_PATH\",\"session_id\":\"$GATE_SESSION_ID\",\"timestamp\":\"$TIMESTAMP\"}"

# ──────────────────────────────────────────────
# POSTMORTEM COMPLETION DETECTION
# If a Bash command wrote postmortem.completed to the journal, auto-clear the gate
# ──────────────────────────────────────────────
if [[ "$TOOL_NAME" == "Bash" ]] && _has_jq && [[ -n "$GATE_STATE_RAW" ]]; then
  PM_REQUIRED="$(echo "$GATE_STATE_RAW" | jq -r '.postmortem.required // false' 2>/dev/null)"
  if [[ "$PM_REQUIRED" == "true" ]]; then
    TODAY="$(date +%Y-%m-%d)"
    JOURNAL_FILE="$ROOT/.state/journal/$TODAY.jsonl"
    if [[ -f "$JOURNAL_FILE" ]] && grep -q '"postmortem.completed"' "$JOURNAL_FILE" 2>/dev/null; then
      update_gate_field '.postmortem.completed = true'
      journal_append "{\"event\":\"postmortem.gate_cleared\",\"session_id\":\"$GATE_SESSION_ID\",\"timestamp\":\"$TIMESTAMP\"}"
    fi
  fi
fi

# ──────────────────────────────────────────────
# CHECKPOINT COMPLETION DETECTION
# If checkpoint.completed was logged, auto-clear the gate
# ──────────────────────────────────────────────
if [[ "$TOOL_NAME" == "Bash" ]] && _has_jq && [[ -n "$GATE_STATE_RAW" ]]; then
  CP_STATUS="$(get_gate_status "checkpoint" 2>/dev/null || echo "clear")"
  if [[ "$CP_STATUS" == "pending" ]]; then
    TODAY="$(date +%Y-%m-%d)"
    JOURNAL_FILE="$ROOT/.state/journal/$TODAY.jsonl"
    if [[ -f "$JOURNAL_FILE" ]] && grep -q '"checkpoint.completed"' "$JOURNAL_FILE" 2>/dev/null; then
      update_gate_field '
        .gates.checkpoint.status = "clear"
        | .gates.checkpoint.soft_warnings = 0
        | .task_count_since_checkpoint = 0
      '
      journal_append "{\"event\":\"gate.auto_cleared\",\"gate\":\"checkpoint\",\"reason\":\"checkpoint.completed detected in tool-logger\",\"session_id\":\"$GATE_SESSION_ID\",\"timestamp\":\"$TIMESTAMP\"}"
    fi
  fi
fi

# ──────────────────────────────────────────────
# CHECKPOINT TRACKING (Edit/Write operations)
# ──────────────────────────────────────────────
if [[ "$TOOL_NAME" == "Edit" ]] || [[ "$TOOL_NAME" == "Write" ]]; then
  # Increment persistent task counter in gates.json
  if _has_jq && [[ -n "$GATE_STATE_RAW" ]]; then
    NEW_COUNT=$((GATE_TASK_COUNT + 1))
    update_gate_field ".task_count_since_checkpoint = $NEW_COUNT"
    GATE_TASK_COUNT=$NEW_COUNT
  fi

  TODAY="$(date +%Y-%m-%d)"
  JOURNAL_FILE="$ROOT/.state/journal/$TODAY.jsonl"

  if [[ -f "$JOURNAL_FILE" ]]; then
    # Count Edit/Write events since last checkpoint.passed or checkpoint.completed
    LAST_CP_LINE="$(grep -n '"checkpoint\.passed"\|"checkpoint\.completed"' "$JOURNAL_FILE" 2>/dev/null | tail -1 | cut -d: -f1 || echo "0")"

    if [[ "$LAST_CP_LINE" -gt 0 ]]; then
      EDIT_COUNT="$(tail -n +"$((LAST_CP_LINE + 1))" "$JOURNAL_FILE" | grep -c '"tool":"Edit"\|"tool":"Write"' 2>/dev/null || echo "0")"
    else
      EDIT_COUNT="$(grep -c '"tool":"Edit"\|"tool":"Write"' "$JOURNAL_FILE" 2>/dev/null || echo "0")"
    fi

    # Threshold: 20 edits = checkpoint warning territory
    THRESHOLD="$GATE_CHECKPOINT_THRESHOLD"
    if [[ "$EDIT_COUNT" -ge "$THRESHOLD" ]]; then
      if _has_jq && [[ -n "$GATE_STATE_RAW" ]]; then
        CURRENT_STATUS="$(get_gate_status "checkpoint")"
        if [[ "$CURRENT_STATUS" == "clear" ]] || [[ "$CURRENT_STATUS" == "passed" ]]; then
          update_gate_field '.gates.checkpoint.status = "pending"'
          journal_append "{\"event\":\"gate.activated\",\"gate\":\"checkpoint\",\"reason\":\"$EDIT_COUNT edits since last checkpoint (threshold: $THRESHOLD)\",\"session_id\":\"$GATE_SESSION_ID\",\"timestamp\":\"$TIMESTAMP\"}"
        fi
      fi
    fi
  fi
fi

exit 0
