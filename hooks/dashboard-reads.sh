#!/usr/bin/env bash
# dashboard-reads.sh — Emit "read" events to the dashboard daemon.
#
# Handles two Claude Code hook events:
#   PostToolUse(Read)    → fires after every file read
#   InstructionsLoaded   → fires when CLAUDE.md / rules / @-includes load
#
# Filters to only emit for files inside ~/dotfiles/ (instructions, skills,
# rules, agents). Exits 0 immediately for all other files.

set -euo pipefail

INPUT=$(cat)

# jq required — bail without it
command -v jq &>/dev/null || exit 0

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"')

# Extract file path based on hook type
case "$HOOK_EVENT" in
    PostToolUse)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        ;;
    InstructionsLoaded)
        FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty')
        ;;
    *)
        exit 0
        ;;
esac

[[ -z "$FILE_PATH" ]] && exit 0

# ── Normalize paths (Windows/MSYS compat) ────────────────────────────────────
normalize() {
    local p="$1"
    p="${p//\\//}"
    # C:/Users/... → /c/Users/...
    if [[ "$p" =~ ^([A-Za-z]):/ ]]; then
        p="/${BASH_REMATCH[1],,}/${p:3}"
    fi
    echo "$p"
}

FILE_PATH=$(normalize "$FILE_PATH")
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
DOTFILES_N=$(normalize "$DOTFILES")

# Only emit for files inside dotfiles
[[ "$FILE_PATH" != "$DOTFILES_N"/* ]] && exit 0

# Relative path from dotfiles root
REL_PATH="${FILE_PATH#$DOTFILES_N/}"

# Filter: only dashboard-relevant files
case "$REL_PATH" in
    *.instructions.md|CLAUDE.md|CLAUDE.base.md) ;;
    instructions/*)                              ;;
    skills/*)                                    ;;
    rules/*)                                     ;;
    agents/*)                                    ;;
    *)                                           exit 0 ;;
esac

# Emit via write-dashboard-state.sh CLI mode
bash "$DOTFILES/bin/write-dashboard-state.sh" read "Read $REL_PATH"

exit 0
