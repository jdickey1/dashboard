#!/bin/bash
#
# Mission Control Status Overview
# Displays a grid of all sessions with color-coded status
#
# Status colors:
#   Green  = Working (actively processing)
#   Yellow = Waiting (needs user input)
#   Red    = Error
#   Grey   = Idle (ready/done)
#

CONFIG_FILE="${1:-/home/dashboard/app/config.json}"
STATUS_FILE="${DASHBOARD_STATUS_FILE:-/tmp/dashboard-status.json}"

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
GREY='\033[0;90m'
WHITE='\033[0;97m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Get terminal size
TERM_COLS=$(tput cols 2>/dev/null || echo 80)
TERM_ROWS=$(tput lines 2>/dev/null || echo 24)

# Calculate grid - each box is ~14 chars wide (10 + borders + spacing)
BOX_WIDTH=14
COLS=$(( (TERM_COLS - 4) / BOX_WIDTH ))
[[ $COLS -lt 1 ]] && COLS=1
[[ $COLS -gt 6 ]] && COLS=6

# Clear screen
clear

# Get sessions from config
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

SESSIONS=($(jq -r '.sessions[].name' "$CONFIG_FILE"))
TOTAL=${#SESSIONS[@]}
ROWS=$(( (TOTAL + COLS - 1) / COLS ))

# Read status file
declare -A STATUSES
if [[ -f "$STATUS_FILE" ]]; then
    while IFS='=' read -r key value; do
        STATUSES["$key"]="$value"
    done < <(jq -r 'to_entries[] | "\(.key)=\(.value.status)"' "$STATUS_FILE" 2>/dev/null)
fi

# Function to get status color
get_status_color() {
    local session="$1"
    local status="${STATUSES[$session]:-idle}"
    case "$status" in
        working) echo -e "${GREEN}" ;;
        waiting) echo -e "${YELLOW}" ;;
        error)   echo -e "${RED}" ;;
        *)       echo -e "${GREY}" ;;
    esac
}

# Print header
echo -e "${CYAN}${BOLD}"
echo "  MISSION CONTROL"
echo -e "${RESET}"

# Count statuses
working=0 waiting=0 error=0 idle=0
for session in "${SESSIONS[@]}"; do
    status="${STATUSES[$session]:-idle}"
    case "$status" in
        working) ((working++)) ;;
        waiting) ((waiting++)) ;;
        error)   ((error++)) ;;
        *)       ((idle++)) ;;
    esac
done

# Print grid
idx=0
for ((row=0; row<ROWS; row++)); do
    # Status line with name
    echo -n "  "
    for ((col=0; col<COLS; col++)); do
        if [[ $idx -lt $TOTAL ]]; then
            session="${SESSIONS[$idx]}"
            color=$(get_status_color "$session")
            # Remove claude- prefix and truncate to 10 chars
            short_name=$(echo "$session" | sed 's/^claude-//' | cut -c1-10)
            printf "${color}%-10s${RESET}  " "$short_name"
        fi
        ((idx++))
    done
    echo ""
done

# Print legend
echo ""
echo -e "  ${GREEN}■${RESET} Working:$working  ${YELLOW}■${RESET} Waiting:$waiting  ${RED}■${RESET} Error:$error  ${GREY}■${RESET} Idle:$idle"
echo ""
echo -e "  ${GREY}$(date '+%H:%M:%S') | Ctrl-b n: sessions${RESET}"
