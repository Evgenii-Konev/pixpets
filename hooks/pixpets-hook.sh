#!/bin/bash
# Universal pixpets hook for all supported agents
# Writes session status to ~/.pixpets/sessions/<session_id>.json
# Receives JSON on stdin with agent-specific fields
#
# Usage:
#   pixpets-hook.sh --agent claude   (from ~/.claude/settings.json)
#   pixpets-hook.sh --agent cursor   (from ~/.cursor/hooks.json)
#   pixpets-hook.sh --agent codex    (from ~/.codex/hooks.json)
#   pixpets-hook.sh                  (defaults to claude for backwards compat)

SESSIONS_DIR="$HOME/.pixpets/sessions"
mkdir -p "$SESSIONS_DIR"

# Parse --agent argument
AGENT="claude"
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

INPUT=$(cat)

# --- Extract task info from tool_name/tool_input ---

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TASK=""

case "$TOOL_NAME" in
  TaskCreate|TaskUpdate)
    TASK=$(echo "$INPUT" | jq -r '.tool_input.activeForm // .tool_input.subject // empty')
    ;;
  TodoWrite)
    TASK=$(echo "$INPUT" | jq -r '
      [.tool_input.todos[]? | select(.status == "in_progress")]
      | first
      | (.activeForm // .content // empty)' 2>/dev/null)
    ;;
esac

# --- Extract fields based on agent type ---

case "$AGENT" in
  claude)
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
    EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
    ;;
  cursor)
    SESSION_ID=$(echo "$INPUT" | jq -r '.conversation_id // .session_id // empty')
    CWD=$(echo "$INPUT" | jq -r '.workspace_roots[0] // .cwd // empty')
    EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
    ;;
  codex)
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
    EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
    ;;
  *)
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
    EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
    ;;
esac

[ -z "$SESSION_ID" ] && exit 0

FILE="$SESSIONS_DIR/$SESSION_ID.json"

# --- Find agent PID by walking parent process tree ---

find_agent_pid() {
  local target="$1"
  local p=$PPID
  for _ in 1 2 3 4 5 6 7 8; do
    local comm
    comm=$(ps -p "$p" -o comm= 2>/dev/null)
    case "$(basename "$comm" 2>/dev/null)" in
      $target) echo "$p"; return ;;
    esac
    p=$(ps -p "$p" -o ppid= 2>/dev/null | tr -d ' ')
    [ -z "$p" ] || [ "$p" = "1" ] && break
  done
  echo "$PPID"
}

case "$AGENT" in
  claude) AGENT_PID=$(find_agent_pid "claude") ;;
  cursor) AGENT_PID=$(find_agent_pid "cursor") ;;
  codex)  AGENT_PID=$(find_agent_pid "codex") ;;
  *)      AGENT_PID="$PPID" ;;
esac

# --- Handle sub-agent / team member registration ---
# The main agent's hook fires for Agent/TeamCreate tool calls.
# Sub-agents run inside the same process and don't fire their own hooks,
# so we register them here from the parent's PreToolUse/PostToolUse events.

PROJECT_NAME=$(basename "$CWD")

case "$TOOL_NAME" in
  Agent)
    SUB_NAME=$(echo "$INPUT" | jq -r '.tool_input.name // empty')
    SUB_DESC=$(echo "$INPUT" | jq -r '.tool_input.description // empty')
    SUB_BG=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false')
    SUB_TEAM=$(echo "$INPUT" | jq -r '.tool_input.team_name // empty')

    if [ -n "$SUB_NAME" ] || [ -n "$SUB_DESC" ]; then
      SUB_LABEL="${SUB_NAME:-$SUB_DESC}"
      # Sanitize for use in filename
      SUB_ID=$(printf '%s' "$SUB_LABEL" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-' | cut -c1-40)
      SUB_FILE="$SESSIONS_DIR/${SESSION_ID}-sub-${SUB_ID}.json"

      case "$EVENT" in
        PreToolUse)
          # Also set parent's task to show sub-agent spawn activity
          TASK="⛏ ${SUB_DESC:-$SUB_NAME}"
          SUB_TASK_JSON=$(printf '%s' "${SUB_DESC:-$SUB_NAME}" | jq -Rs .)
          cat > "$SUB_FILE" <<SUBEOF
{
  "pid": $AGENT_PID,
  "parent_pid": $AGENT_PID,
  "status": "working",
  "project": "$CWD",
  "project_name": "$PROJECT_NAME",
  "agent": "$AGENT",
  "session_id": "${SESSION_ID}-sub-${SUB_ID}",
  "interactive": false,
  "task": $SUB_TASK_JSON,
  "updated_at": $(date +%s)
}
SUBEOF
          touch "$SESSIONS_DIR"
          ;;
        PostToolUse)
          # Foreground agents: PostToolUse fires after completion → remove
          # Background agents: PostToolUse fires immediately after launch → keep
          if [ "$SUB_BG" != "true" ] && [ -z "$SUB_TEAM" ]; then
            rm -f "$SUB_FILE"
            touch "$SESSIONS_DIR"
          fi
          ;;
      esac
    fi
    ;;
esac

# --- Map events to status ---

case "$AGENT" in
  claude)
    case "$EVENT" in
      SessionEnd)
        rm -f "$FILE"
        # Clean up all sub-agent sessions for this parent
        for sf in "$SESSIONS_DIR/${SESSION_ID}-sub-"*.json; do
          [ -f "$sf" ] && rm -f "$sf"
        done
        touch "$SESSIONS_DIR"
        exit 0
        ;;
      PreToolUse)        STATUS="waiting" ;;
      PostToolUse)       STATUS="working" ;;
      Stop)
        STATUS="idle"
        # Clean up sub-agent sessions older than 60s (likely completed)
        NOW=$(date +%s)
        for sf in "$SESSIONS_DIR/${SESSION_ID}-sub-"*.json; do
          [ -f "$sf" ] || continue
          SUB_UPDATED=$(jq -r '.updated_at // 0' "$sf" 2>/dev/null)
          AGE=$((NOW - SUB_UPDATED))
          [ "$AGE" -gt 60 ] && rm -f "$sf"
        done
        ;;
      UserPromptSubmit)  STATUS="working" ;;
      SessionStart)      STATUS="idle" ;;
      *)                 STATUS="idle" ;;
    esac
    ;;
  cursor)
    case "$EVENT" in
      sessionEnd)          rm -f "$FILE"; exit 0 ;;
      preToolUse)          STATUS="waiting" ;;
      postToolUse)         STATUS="working" ;;
      stop)                STATUS="idle" ;;
      sessionStart)        STATUS="idle" ;;
      beforeSubmitPrompt)  STATUS="working" ;;
      *)                   STATUS="idle" ;;
    esac
    ;;
  codex)
    case "$EVENT" in
      SessionStart) STATUS="working" ;;
      Stop)         STATUS="idle" ;;
      *)            STATUS="idle" ;;
    esac
    ;;
  *)
    STATUS="idle"
    ;;
esac

# --- Resolve task: preserve previous if not set, clear on Stop ---

if [ "$STATUS" = "idle" ]; then
  TASK=""
elif [ -z "$TASK" ] && [ -f "$FILE" ]; then
  TASK=$(jq -r '.task // empty' "$FILE" 2>/dev/null)
fi

# --- Detect non-interactive sessions (Claude-specific -p flag) ---

INTERACTIVE=true
if [ "$AGENT" = "claude" ]; then
  CLAUDE_ARGS=$(ps -p "$AGENT_PID" -o args= 2>/dev/null)
  if echo "$CLAUDE_ARGS" | grep -qE '(^| )-p( |$)'; then
    INTERACTIVE=false
    PROJECT_DIR=""
    MCP_PATH=$(echo "$CLAUDE_ARGS" | grep -oE '\-\-mcp-config [^ ]+' | head -1 | sed 's/--mcp-config //')
    if [ -n "$MCP_PATH" ]; then
      PROJECT_DIR=$(cd "$(dirname "$MCP_PATH")/.." 2>/dev/null && pwd)
    fi
    if [ -z "$PROJECT_DIR" ] || [ "$PROJECT_DIR" = "/" ]; then
      PROJECT_DIR=$(lsof -a -p "$AGENT_PID" -d cwd -Fn 2>/dev/null | grep '^n/' | head -1 | sed 's/^n//')
    fi
    if [ -n "$PROJECT_DIR" ] && [ "$PROJECT_DIR" != "/" ] && [ "$PROJECT_DIR" != "/private/tmp" ]; then
      CWD="$PROJECT_DIR"
      PROJECT_NAME=$(basename "$CWD")
    fi
  fi
fi

# --- Write session file ---

TASK_JSON="null"
if [ -n "$TASK" ]; then
  TASK_JSON=$(printf '%s' "$TASK" | jq -Rs .)
fi

cat > "$FILE" <<EOF
{
  "pid": $AGENT_PID,
  "status": "$STATUS",
  "project": "$CWD",
  "project_name": "$PROJECT_NAME",
  "agent": "$AGENT",
  "session_id": "$SESSION_ID",
  "interactive": $INTERACTIVE,
  "task": $TASK_JSON,
  "updated_at": $(date +%s)
}
EOF

# Touch directory to ensure FSEvents fires for file watcher
touch "$SESSIONS_DIR"

exit 0
