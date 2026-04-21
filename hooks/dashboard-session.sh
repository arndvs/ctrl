#!/usr/bin/env bash
# dashboard-session.sh — SessionStart / Stop hook: emit dashboard events.
#
# Receives Claude Code hook JSON on stdin containing session lifecycle data.
# Writes a JSONL event to ~/dotfiles/working/events.jsonl for the dashboard
# daemon to pick up. Zero tool-call cost — fires automatically.
#
# Hook events:
#   SessionStart → {session_id, cwd}
#   Stop         → {session_id, transcript_path}

set -euo pipefail

EVENTS_FILE="$HOME/dotfiles/working/events.jsonl"
mkdir -p "$(dirname "$EVENTS_FILE")"

# Read hook JSON from stdin
INPUT=$(cat)

# Extract fields (graceful fallback if jq is missing)
if command -v jq &>/dev/null; then
    HOOK_EVENT=$(echo "$INPUT" | jq -r '.hookEventName // .event // "unknown"')
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // .sessionId // "unknown"')
    CWD=$(echo "$INPUT" | jq -r '.cwd // .workingDirectory // empty')
    TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // .transcriptPath // empty')
else
    # Minimal extraction without jq
    HOOK_EVENT="unknown"
    SESSION_ID="unknown"
    CWD=""
    TRANSCRIPT=""
fi

# Derive project name from cwd (last path segment)
if [[ -n "$CWD" ]]; then
    PROJECT=$(basename "$CWD")
    PROJECT_PATH="$CWD"
else
    PROJECT=$(basename "$PWD")
    PROJECT_PATH="$PWD"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIME_DISPLAY=$(date +"%H:%M:%S")

case "$HOOK_EVENT" in
    SessionStart)
        EVENT_TYPE="info"
        MESSAGE="Session started (hook) — $SESSION_ID"
        ;;
    Stop)
        EVENT_TYPE="info"
        if [[ -n "$TRANSCRIPT" ]]; then
            MESSAGE="Session ended (hook) — transcript: $TRANSCRIPT"
        else
            MESSAGE="Session ended (hook) — $SESSION_ID"
        fi
        ;;
    *)
        EVENT_TYPE="info"
        MESSAGE="Hook event: $HOOK_EVENT — $SESSION_ID"
        ;;
esac

# Write JSONL event (daemon picks this up via its JSONL watcher)
printf '{"type":"%s","project":"%s","projectPath":"%s","message":"%s","timestamp":"%s","time":"%s","source":"hook","hookEvent":"%s","sessionId":"%s"}\n' \
    "$EVENT_TYPE" \
    "$PROJECT" \
    "$PROJECT_PATH" \
    "$MESSAGE" \
    "$TIMESTAMP" \
    "$TIME_DISPLAY" \
    "$HOOK_EVENT" \
    "$SESSION_ID" \
    >> "$EVENTS_FILE"

# Allow the session to proceed
exit 0
