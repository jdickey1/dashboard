#!/bin/bash
#
# Create tmux sessions for all VPS projects
#
# Usage: ./setup-vps-sessions.sh
#

set -e

echo "Creating VPS tmux sessions..."

# Define sessions with their working directories
declare -A SESSIONS=(
    ["nonrootadmin"]="/home/nonrootadmin"
    ["jdkey"]="/home/jdkey/app"
    ["planter"]="/home/planter/app"
    ["sharper"]="/home/sharper/app"
    ["winning"]="/home/winning/app"
    ["podstyle"]="/home/podstyle/apps/web"
    ["vidpub"]="/home/vidpub/apps/web"
    ["link"]="/home/link/apps/web"
    ["tru"]="/home/tru/apps/web"
    ["agents"]="/home/agents/app"
    ["obsidian"]="/home/obsidian"
)

for session in "${!SESSIONS[@]}"; do
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
