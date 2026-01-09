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

# Colors for status
COLOR_WORKING="green"
COLOR_WAITING="yellow"
COLOR_IDLE="white"
COLOR_ERROR="red"
COLOR_OFFLINE="colour240"  # gray

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

# Create new session with first pane
FIRST_SESSION=$(jq -r '.sessions[0].name' "$CONFIG_FILE")
FIRST_HOST=$(jq -r '.sessions[0].host' "$CONFIG_FILE")
FIRST_TYPE=$(jq -r '.sessions[0].type' "$CONFIG_FILE")

if [[ "$FIRST_TYPE" == "remote" ]]; then
    tmux new-session -d -s "$SESSION_NAME" -n main "ssh $FIRST_HOST -t 'bash -l -c \"tmux attach -t $FIRST_SESSION\"' 2>/dev/null || echo \"Session $FIRST_SESSION not found on $FIRST_HOST\" && sleep 5"
else
    tmux new-session -d -s "$SESSION_NAME" -n main "tmux attach -t $FIRST_SESSION 2>/dev/null || echo \"Session $FIRST_SESSION not found\" && sleep 5"
fi

# Set first pane title
tmux select-pane -t "$SESSION_NAME:main.0" -T "$FIRST_SESSION"

# Create remaining panes
for ((i=1; i<SESSIONS; i++)); do
    NAME=$(jq -r ".sessions[$i].name" "$CONFIG_FILE")
    HOST=$(jq -r ".sessions[$i].host" "$CONFIG_FILE")
    TYPE=$(jq -r ".sessions[$i].type" "$CONFIG_FILE")

    # Determine split direction based on layout
    ROW=$((i / COLUMNS))
    COL=$((i % COLUMNS))

    if [[ $COL -eq 0 ]]; then
        # New row - split horizontally from the first pane of previous row
        SPLIT_TARGET="$SESSION_NAME:main.$((i - COLUMNS))"
        tmux split-window -t "$SPLIT_TARGET" -v
    else
        # Same row - split vertically from previous pane
        SPLIT_TARGET="$SESSION_NAME:main.$((i - 1))"
        tmux split-window -t "$SPLIT_TARGET" -h
    fi

    # Get the new pane and set its command
    if [[ "$TYPE" == "remote" ]]; then
        tmux send-keys -t "$SESSION_NAME:main.$i" "ssh $HOST -t 'bash -l -c \"tmux attach -t $NAME\"' || echo 'Session $NAME not found on $HOST' && sleep 5" Enter
    else
        tmux send-keys -t "$SESSION_NAME:main.$i" "tmux attach -t $NAME 2>/dev/null || echo 'Session $NAME not found' && sleep 5" Enter
    fi

    # Set pane title
    tmux select-pane -t "$SESSION_NAME:main.$i" -T "$NAME"
done

# Enable pane titles and borders
tmux set-option -t "$SESSION_NAME" pane-border-status top
tmux set-option -t "$SESSION_NAME" pane-border-format "#{?pane_active,#[reverse],} #T #{?pane_active,#[noreverse],}"

# Balance the layout
tmux select-layout -t "$SESSION_NAME:main" tiled

# Set up status bar
tmux set-option -t "$SESSION_NAME" status on
tmux set-option -t "$SESSION_NAME" status-position bottom
tmux set-option -t "$SESSION_NAME" status-left "#[fg=cyan,bold] MISSION CONTROL #[default]"
tmux set-option -t "$SESSION_NAME" status-right "#[fg=white]%H:%M:%S #[default]"
tmux set-option -t "$SESSION_NAME" status-interval 1

# Attach to the session
echo "Attaching to Mission Control..."
tmux attach -t "$SESSION_NAME"
