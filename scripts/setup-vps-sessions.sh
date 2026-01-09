#!/bin/bash
#
# Create tmux sessions for Claude Code projects
#
# Usage: ./setup-vps-sessions.sh
#
# Customize the SESSIONS array below with your own projects.
#

set -e

echo "Creating Claude Code tmux sessions..."

# Define sessions with their working directories
# Format: ["session-name"]="/path/to/project"
#
# Example configuration - customize for your setup:
declare -A SESSIONS=(
    ["claude-project1"]="$HOME/projects/project1"
    ["claude-project2"]="$HOME/projects/project2"
    ["claude-admin"]="$HOME"
)

# Sort keys alphabetically
IFS=$'\n' sorted_keys=($(sort <<<"${!SESSIONS[*]}")); unset IFS

for session in "${sorted_keys[@]}"; do
    dir="${SESSIONS[$session]}"

    # Check if session already exists
    if tmux has-session -t "$session" 2>/dev/null; then
        echo "  [exists] $session"
    else
        # Create session in detached mode, starting in the project directory
        if [[ -d "$dir" ]]; then
            tmux new-session -d -s "$session" -c "$dir"
            echo "  [created] $session -> $dir"
        else
            tmux new-session -d -s "$session"
            echo "  [created] $session (dir $dir not found, using home)"
        fi
    fi
done

echo ""
echo "All sessions created. Current tmux sessions:"
tmux list-sessions

echo ""
echo "To attach to a session: tmux attach -t <session-name>"
echo "To start Mission Control: ./scripts/mission-control.sh"
