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
# Auto-detect terminal width and calculate panes per page
# Each pane needs ~65 columns minimum to be usable for Claude Code
TERM_WIDTH=$(tput cols 2>/dev/null || echo 120)
MIN_PANE_WIDTH=65

if [[ $TERM_WIDTH -ge $((MIN_PANE_WIDTH * 4)) ]]; then
    PANES_PER_PAGE=4
elif [[ $TERM_WIDTH -ge $((MIN_PANE_WIDTH * 3)) ]]; then
    PANES_PER_PAGE=3
elif [[ $TERM_WIDTH -ge $((MIN_PANE_WIDTH * 2)) ]]; then
    PANES_PER_PAGE=2
else
    PANES_PER_PAGE=1
fi

echo "Terminal width: ${TERM_WIDTH} columns → using $PANES_PER_PAGE panes per page"

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

# Calculate pages (add 1 for overview page)
SESSION_PAGES=$(( (TOTAL_SESSIONS + PANES_PER_PAGE - 1) / PANES_PER_PAGE ))
TOTAL_PAGES=$((SESSION_PAGES + 1))

echo "Starting Mission Control: $TOTAL_SESSIONS sessions across $TOTAL_PAGES pages (overview + $SESSION_PAGES session pages)"

# Kill existing mission control session if it exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Function to get attach command for a session
get_attach_cmd() {
    local name="$1"
    local host="$2"
    local type="$3"

    if [[ "$type" == "remote" ]]; then
        echo "ssh $host -t 'bash -l -c \"tmux attach -t $name\"' || { echo 'Session $name not found on $host'; sleep 3; }"
    else
        # Unset TMUX to allow nested session attachment
        echo "TMUX= tmux attach -t $name || { echo 'Session $name not found'; sleep 3; }"
    fi
}

# Ensure tmux server is running (loads config) before querying options
tmux start-server 2>/dev/null || true

# Get tmux base-index (windows and panes start at this number)
BASE_INDEX=$(tmux show-option -gv base-index 2>/dev/null || echo "0")
PANE_BASE=$(tmux show-option -gv pane-base-index 2>/dev/null || echo "0")

# Create session with overview page first
OVERVIEW_CMD="watch -t -n 2 -c $SCRIPT_DIR/status-overview.sh"
tmux new-session -d -s "$SESSION_NAME" -x 200 -y 50 -n "[Overview]" "$OVERVIEW_CMD"

# Force session size for detached session (works around nested tmux constraints)
tmux set-option -t "$SESSION_NAME" window-size manual 2>/dev/null || true
tmux resize-window -t "$SESSION_NAME" -x 200 -y 50 2>/dev/null || true

# Create session pages (windows) with 3 panes each
for ((page=0; page<SESSION_PAGES; page++)); do
    start_idx=$((page * PANES_PER_PAGE))
    window_num=$((page + BASE_INDEX + 1))  # +1 because overview is first

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
    window_name="[$((page+2))/$TOTAL_PAGES] ${window_names}"

    # Create new window for this page
    tmux new-window -t "$SESSION_NAME" -n "$window_name" "$FIRST_CMD"

    # Set first pane title
    tmux select-pane -t "$SESSION_NAME:$window_num.$PANE_BASE" -T "$FIRST_NAME" 2>/dev/null || true

    # Create remaining panes on this page (split horizontally for even thirds)
    for ((j=1; j<${#sessions_on_page[@]}; j++)); do
        idx=${sessions_on_page[$j]}
        NAME=$(jq -r ".sessions[$idx].name" "$CONFIG_FILE")
        HOST=$(jq -r ".sessions[$idx].host" "$CONFIG_FILE")
        TYPE=$(jq -r ".sessions[$idx].type" "$CONFIG_FILE")
        CMD=$(get_attach_cmd "$NAME" "$HOST" "$TYPE")

        # Split vertically (side by side)
        tmux split-window -t "$SESSION_NAME:$window_num" -h "$CMD"
        pane_num=$((PANE_BASE + j))
        tmux select-pane -t "$SESSION_NAME:$window_num.$pane_num" -T "$NAME" 2>/dev/null || true
    done

    # Make panes even width
    tmux select-layout -t "$SESSION_NAME:$window_num" even-horizontal

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

# Select first window (overview) and pane
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
