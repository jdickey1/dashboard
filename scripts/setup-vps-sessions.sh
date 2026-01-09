#!/bin/bash
#
# Create tmux sessions for all VPS projects
#
# Usage: ./setup-vps-sessions.sh
#

set -e

echo "Creating VPS tmux sessions..."

# Define sessions with their working directories (alphabetical order)
declare -A SESSIONS=(
    ["claude-agents"]="/home/agents/app"
    ["claude-jdkey"]="/home/jdkey/app"
    ["claude-link"]="/home/link/apps/web"
    ["claude-nonrootadmin"]="/home/nonrootadmin"
    ["claude-obsidian"]="/home/obsidian"
    ["claude-planter"]="/home/planter/app"
    ["claude-podstyle"]="/home/podstyle/apps/web"
    ["claude-sharper"]="/home/sharper/app"
    ["claude-tru"]="/home/tru/apps/web"
    ["claude-vidpub"]="/home/vidpub/apps/web"
    ["claude-winning"]="/home/winning/app"
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
