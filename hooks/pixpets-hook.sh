#!/bin/bash
# pixpets hook for Claude Code
# Writes session status to ~/.pixpets/sessions/<session_id>.json
# Receives JSON on stdin with: session_id, cwd, hook_event_name, etc.

SESSIONS_DIR="$HOME/.pixpets/sessions"
mkdir -p "$SESSIONS_DIR"

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

[ -z "$SESSION_ID" ] && exit 0

FILE="$SESSIONS_DIR/$SESSION_ID.json"

# Find the claude process PID by walking up from our PPID
find_claude_pid() {
  local p=$PPID
  for _ in 1 2 3 4 5 6 7 8; do
    local comm
    comm=$(ps -p "$p" -o comm= 2>/dev/null)
    case "$(basename "$comm" 2>/dev/null)" in
      claude) echo "$p"; return ;;
    esac
    p=$(ps -p "$p" -o ppid= 2>/dev/null | tr -d ' ')
    [ -z "$p" ] || [ "$p" = "1" ] && break
  done
  echo "$PPID"
}

case "$EVENT" in
  SessionEnd)
    rm -f "$FILE"
    exit 0
    ;;
  PreToolUse)    STATUS="working" ;;
  PostToolUse)   STATUS="idle" ;;
  Stop)          STATUS="waiting" ;;
  *)             STATUS="idle" ;;
esac

CLAUDE_PID=$(find_claude_pid)
PROJECT_NAME=$(basename "$CWD")

cat > "$FILE" <<EOF
{
  "pid": $CLAUDE_PID,
  "status": "$STATUS",
  "project": "$CWD",
  "project_name": "$PROJECT_NAME",
  "agent": "claude",
  "session_id": "$SESSION_ID",
  "updated_at": $(date +%s)
}
EOF

exit 0
