#!/bin/bash
#
# Claude Code Hook: Waiting for input
# Called when Claude asks a question or needs user input
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to extract the question from stdin
QUESTION=""
if [[ ! -t 0 ]]; then
    INPUT=$(cat)
    if command -v jq >/dev/null 2>&1; then
        QUESTION=$(echo "$INPUT" | jq -r '.question // .message // "Needs input"' 2>/dev/null | head -c 50)
    fi
    [[ -z "$QUESTION" || "$QUESTION" == "null" ]] && QUESTION="Needs input"
fi

"$SCRIPT_DIR/update-status.sh" "waiting" "$QUESTION"
