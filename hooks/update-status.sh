#!/bin/bash
#
# Claude Code Hook: Update dashboard status
#
# This script is called by Claude Code hooks to update the mission control dashboard.
# It updates both the status file and the tmux pane appearance.
#
# Usage: ./update-status.sh <status> [message]
#   status: working|waiting|idle|error
#   message: optional status message
#
# Environment variables:
#   DASHBOARD_SESSION: tmux session name (defaults to current session)
#   DASHBOARD_STATUS_FILE: path to status file (defaults to /tmp/dashboard-status.json)
#

STATUS="${1:-idle}"
MESSAGE="${2:-}"
SESSION="${DASHBOARD_SESSION:-$(tmux display-message -p '#S' 2>/dev/null || echo 'unknown')}"
STATUS_FILE="${DASHBOARD_STATUS_FILE:-/tmp/dashboard-status.json}"
TIMESTAMP=$(date -Iseconds)

# Color mappings
case "$STATUS" in
    working)
        COLOR="green"
        ICON="🟢"
        ;;
    waiting)
        COLOR="yellow"
        ICON="🟡"
        ;;
    idle)
        COLOR="white"
        ICON="⚪"
        ;;
    error)
        COLOR="red"
        ICON="🔴"
        ;;
    *)
        COLOR="white"
        ICON="⚪"
        ;;
esac

# Update status file (JSON)
if command -v jq >/dev/null 2>&1; then
    # Create file if doesn't exist
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo '{}' > "$STATUS_FILE"
    fi

    # Update the session's status
    jq --arg session "$SESSION" \
       --arg status "$STATUS" \
       --arg message "$MESSAGE" \
       --arg timestamp "$TIMESTAMP" \
       --arg icon "$ICON" \
       '.[$session] = {status: $status, message: $message, timestamp: $timestamp, icon: $icon}' \
       "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
fi

# Update tmux pane title if we're in tmux
if [[ -n "$TMUX" ]]; then
    # Find our pane in mission-control session and update it
    MISSION_CONTROL_SESSION="mission-control"

    # Check if mission-control exists
    if tmux has-session -t "$MISSION_CONTROL_SESSION" 2>/dev/null; then
        # Find pane with our session name and update its style
        PANES=$(tmux list-panes -t "$MISSION_CONTROL_SESSION" -F '#{pane_index}:#{pane_title}')

        while IFS=: read -r pane_idx pane_title; do
            if [[ "$pane_title" == "$SESSION" ]]; then
                # Update pane border style
                tmux select-pane -t "$MISSION_CONTROL_SESSION:main.$pane_idx" -P "fg=$COLOR"

                # Update pane title with status
                if [[ -n "$MESSAGE" ]]; then
                    tmux select-pane -t "$MISSION_CONTROL_SESSION:main.$pane_idx" -T "$ICON $SESSION: $MESSAGE"
                else
                    tmux select-pane -t "$MISSION_CONTROL_SESSION:main.$pane_idx" -T "$ICON $SESSION"
                fi
                break
            fi
        done <<< "$PANES"
    fi
fi

# Also update our own pane title (for the session itself)
if [[ -n "$TMUX" ]]; then
    if [[ -n "$MESSAGE" ]]; then
        tmux select-pane -T "$ICON $MESSAGE"
    else
        tmux select-pane -T "$ICON $STATUS"
    fi
fi

echo "$ICON $SESSION: $STATUS${MESSAGE:+ - $MESSAGE}"
