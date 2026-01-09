#!/bin/bash
#
# Claude Code Hook: UserPromptSubmit
# Called when user submits a prompt - Claude is now working
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract the prompt from stdin (Claude sends context as JSON)
PROMPT=""
if [[ -t 0 ]]; then
    # No stdin
    PROMPT="Working..."
else
    # Try to extract prompt from JSON input
    INPUT=$(cat)
    if command -v jq >/dev/null 2>&1; then
        PROMPT=$(echo "$INPUT" | jq -r '.prompt // .message // "Working..."' 2>/dev/null | head -c 50)
    fi
    [[ -z "$PROMPT" || "$PROMPT" == "null" ]] && PROMPT="Working..."
fi

"$SCRIPT_DIR/update-status.sh" "working" "$PROMPT"
