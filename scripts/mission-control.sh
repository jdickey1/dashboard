#!/bin/bash
#
# Mission Control - tmux grid for monitoring Claude Code sessions
#
# Usage: ./mission-control.sh [config.json]
#
# Navigation:
#   Ctrl-b n     Next page
#   Ctrl-b p     Previous page
#   Ctrl-b 0-9   Jump to page
#   Arrow keys   Switch between panes on current page
#   Ctrl-b z     Zoom/unzoom current pane
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${1:-$SCRIPT_DIR/../config.json}"
SESSION_NAME="mission-control"
PANES_PER_PAGE=3

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
TOTAL_SESSIONS=$(jq -r '.sessions | length' "$CONFIG_FILE")

if [[ "$TOTAL_SESSIONS" -eq 0 ]]; then
    echo "No sessions defined in config."
    exit 1
fi

# Calculate pages
TOTAL_PAGES=$(( (TOTAL_SESSIONS + PANES_PER_PAGE - 1) / PANES_PER_PAGE ))

echo "Starting Mission Control: $TOTAL_SESSIONS sessions across $TOTAL_PAGES pages ($PANES_PER_PAGE per page)"

# Kill existing mission control session if it exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Function to get attach command for a session
get_attach_cmd() {
    local name="$1"
    local host="$2"
    local type="$3"

    if [[ "$type" == "remote" ]]; then
        echo "ssh $host -t 'bash -l -c \"tmux attach -t $name\"' || { echo 'Session $name not found'; read -p 'Press enter to retry...'; exec bash -c \"\$0\"; }"
    else
        echo "tmux attach -t $name || { echo 'Session $name not found'; read -p 'Press enter to retry...'; exec bash -c \"\$0\"; }"
    fi
}

# Get tmux base-index (windows and panes start at this number)
BASE_INDEX=$(tmux show-option -gv base-index 2>/dev/null || echo "0")
PANE_BASE=$(tmux show-option -gv pane-base-index 2>/dev/null || echo "0")

# Create pages (windows) with 3 panes each
for ((page=0; page<TOTAL_PAGES; page++)); do
    start_idx=$((page * PANES_PER_PAGE))
    window_num=$((page + BASE_INDEX))

    # Get sessions for this page
    sessions_on_page=()
    for ((j=0; j<PANES_PER_PAGE; j++)); do
        idx=$((start_idx + j))
        if [[ $idx -lt $TOTAL_SESSIONS ]]; then
            sessions_on_page+=($idx)
        fi
    done

    # First session on this page
    first_idx=${sessions_on_page[0]}
    FIRST_NAME=$(jq -r ".sessions[$first_idx].name" "$CONFIG_FILE")
    FIRST_HOST=$(jq -r ".sessions[$first_idx].host" "$CONFIG_FILE")
    FIRST_TYPE=$(jq -r ".sessions[$first_idx].type" "$CONFIG_FILE")
    FIRST_CMD=$(get_attach_cmd "$FIRST_NAME" "$FIRST_HOST" "$FIRST_TYPE")

    # Build window name from session names on this page
    window_names=""
    for idx in "${sessions_on_page[@]}"; do
        name=$(jq -r ".sessions[$idx].name" "$CONFIG_FILE")
        short_name=$(echo "$name" | sed 's/claude-//' | cut -c1-8)
        window_names+="${short_name} "
    done
    window_name="[$((page+1))/$TOTAL_PAGES] ${window_names}"

    if [[ $page -eq 0 ]]; then
        # Create session with first window
        tmux new-session -d -s "$SESSION_NAME" -n "$window_name" "$FIRST_CMD"
    else
        # Create new window
        tmux new-window -t "$SESSION_NAME" -n "$window_name" "$FIRST_CMD"
    fi

    # Set first pane title
    tmux select-pane -t "$SESSION_NAME:$window_num.$PANE_BASE" -T "$FIRST_NAME" 2>/dev/null || true

    # Create remaining panes on this page (split horizontally for even thirds)
    for ((j=1; j<${#sessions_on_page[@]}; j++)); do
        idx=${sessions_on_page[$j]}
        NAME=$(jq -r ".sessions[$idx].name" "$CONFIG_FILE")
        HOST=$(jq -r ".sessions[$idx].host" "$CONFIG_FILE")
        TYPE=$(jq -r ".sessions[$idx].type" "$CONFIG_FILE")
        CMD=$(get_attach_cmd "$NAME" "$HOST" "$TYPE")

        # Split horizontally (stacked vertically)
        tmux split-window -t "$SESSION_NAME:$window_num" -v "$CMD"
        pane_num=$((PANE_BASE + j))
        tmux select-pane -t "$SESSION_NAME:$window_num.$pane_num" -T "$NAME" 2>/dev/null || true
    done

    # Make panes even height
    tmux select-layout -t "$SESSION_NAME:$window_num" even-vertical

    # Enable pane titles for this window
    tmux set-option -t "$SESSION_NAME:$window_num" pane-border-status top 2>/dev/null || true
done

# Global options
tmux set-option -t "$SESSION_NAME" pane-border-format " #T "
tmux set-option -t "$SESSION_NAME" pane-border-style "fg=colour240"
tmux set-option -t "$SESSION_NAME" pane-active-border-style "fg=cyan,bold"

# Status bar
tmux set-option -t "$SESSION_NAME" status on
tmux set-option -t "$SESSION_NAME" status-style "bg=colour235,fg=white"
tmux set-option -t "$SESSION_NAME" status-position bottom
tmux set-option -t "$SESSION_NAME" status-left "#[fg=cyan,bold] MISSION CONTROL #[default]"
tmux set-option -t "$SESSION_NAME" status-left-length 20
tmux set-option -t "$SESSION_NAME" status-right "#[fg=green]Ctrl-b n/p: pages #[fg=white]| %H:%M "
tmux set-option -t "$SESSION_NAME" status-right-length 40

# Select first window and pane
tmux select-window -t "$SESSION_NAME:$BASE_INDEX"
tmux select-pane -t "$SESSION_NAME:$BASE_INDEX.$PANE_BASE"

# Attach to the session
echo "Attaching to Mission Control..."
echo "  Ctrl-b n/p  - Next/prev page"
echo "  Ctrl-b 0-9  - Jump to page"
echo "  Arrow keys  - Switch panes"
echo "  Ctrl-b z    - Zoom pane"
echo ""
exec tmux attach -t "$SESSION_NAME"
