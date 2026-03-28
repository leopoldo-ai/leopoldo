#!/usr/bin/env bash
# pre-edit-validator.sh — PreToolUse hook for Leopoldo.
# Blocks writes to protected directories (.state/, managed .leopoldo/ files).
# Exit 2 = block the edit. Exit 0 = allow.

set -euo pipefail
trap 'exit 0' ERR

# Read tool input from stdin
INPUT="$(cat)"

FILE_PATH=""
if command -v jq &>/dev/null; then
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .file_path // ""' 2>/dev/null || echo "")"
else
  FILE_PATH="$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' || echo "")"
fi

# No file path — allow (might be a non-file operation)
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Block writes to .state/ directory
if echo "$FILE_PATH" | grep -q '\.state/' 2>/dev/null; then
  echo "Protected directory: .state/ is managed by Leopoldo hooks. Use gate commands instead of editing directly." >&2
  exit 2
fi

# Block writes to .leopoldo/ (except hooks/ and imprint/ which need write access)
if echo "$FILE_PATH" | grep -q '\.leopoldo/' 2>/dev/null; then
  # Allow hooks (development) and imprint (learning data)
  if ! echo "$FILE_PATH" | grep -qE '\.leopoldo/(hooks|imprint)/' 2>/dev/null; then
    echo "Protected path: files in .leopoldo/ are managed by leopoldo-manager. Use /leopoldo commands to modify." >&2
    exit 2
  fi
fi

exit 0
