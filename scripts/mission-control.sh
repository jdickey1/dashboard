#!/bin/bash
#
# Mission Control - tmux grid for monitoring Claude Code sessions
#
# Usage: ./mission-control.sh [config.json]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${1:-$SCRIPT_DIR/../config.json}"
SESSION_NAME="mission-control"

# Check dependencies
command -v tmux >/dev/null 2>&1 || { echo "tmux is required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed."; exit 1; }

# Check config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE"
    echo "Copy config.example.json to config.json and customize it."
    exit 1
fi

# Parse config
SESSIONS=$(jq -r '.sessions | length' "$CONFIG_FILE")
COLUMNS=$(jq -r '.layout.columns // 3' "$CONFIG_FILE")

if [[ "$SESSIONS" -eq 0 ]]; then
    echo "No sessions defined in config."
    exit 1
fi

echo "Starting Mission Control with $SESSIONS sessions in $COLUMNS columns..."

# Kill existing mission control session if it exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Function to get attach command for a session
get_attach_cmd() {
    local name="$1"
    local host="$2"
    local type="$3"

    if [[ "$type" == "remote" ]]; then
        echo "ssh $host -t 'bash -l -c \"tmux attach -t $name\"' || { echo 'Session $name not found'; sleep 10; }"
    else
        echo "tmux attach -t $name || { echo 'Session $name not found'; sleep 10; }"
    fi
}

# Create new session with first pane
FIRST_NAME=$(jq -r '.sessions[0].name' "$CONFIG_FILE")
FIRST_HOST=$(jq -r '.sessions[0].host' "$CONFIG_FILE")
FIRST_TYPE=$(jq -r '.sessions[0].type' "$CONFIG_FILE")
FIRST_CMD=$(get_attach_cmd "$FIRST_NAME" "$FIRST_HOST" "$FIRST_TYPE")

tmux new-session -d -s "$SESSION_NAME" -n main "$FIRST_CMD"

# Create remaining panes
for ((i=1; i<SESSIONS; i++)); do
    NAME=$(jq -r ".sessions[$i].name" "$CONFIG_FILE")
    HOST=$(jq -r ".sessions[$i].host" "$CONFIG_FILE")
    TYPE=$(jq -r ".sessions[$i].type" "$CONFIG_FILE")
    CMD=$(get_attach_cmd "$NAME" "$HOST" "$TYPE")

    # Just keep splitting - tmux tiled layout will organize them
    tmux split-window -t "$SESSION_NAME:main" "$CMD"

    # Re-tile after each split to prevent "no space for new pane" error
    tmux select-layout -t "$SESSION_NAME:main" tiled
done

# Enable pane titles and borders
tmux set-option -t "$SESSION_NAME" pane-border-status top
tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_index}: #T "
tmux set-option -t "$SESSION_NAME" pane-border-style "fg=colour240"
tmux set-option -t "$SESSION_NAME" pane-active-border-style "fg=cyan"

# Set pane titles
for ((i=0; i<SESSIONS; i++)); do
    NAME=$(jq -r ".sessions[$i].name" "$CONFIG_FILE")
    tmux select-pane -t "$SESSION_NAME:main.$i" -T "$NAME" 2>/dev/null || true
done

# Final layout adjustment
tmux select-layout -t "$SESSION_NAME:main" tiled

# Set up status bar
tmux set-option -t "$SESSION_NAME" status on
tmux set-option -t "$SESSION_NAME" status-style "bg=colour235,fg=white"
tmux set-option -t "$SESSION_NAME" status-position bottom
tmux set-option -t "$SESSION_NAME" status-left "#[fg=cyan,bold] MISSION CONTROL #[default]"
tmux set-option -t "$SESSION_NAME" status-left-length 20
tmux set-option -t "$SESSION_NAME" status-right "#[fg=yellow]$SESSIONS sessions #[fg=white]| %H:%M:%S "
tmux set-option -t "$SESSION_NAME" status-interval 1

# Select first pane
tmux select-pane -t "$SESSION_NAME:main.0"

# Attach to the session
echo "Attaching to Mission Control..."
exec tmux attach -t "$SESSION_NAME"
