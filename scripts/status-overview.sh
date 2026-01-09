#!/bin/bash
#
# Mission Control Status Overview
# Displays a grid of all sessions with color-coded status
#
# Status colors:
#   🟢 Green  = Working (actively processing)
#   🟡 Yellow = Waiting (needs user input)
#   🔴 Red    = Error
#   ⚪ Grey   = Idle (ready/done)
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

# Box drawing characters
TL='┌' TR='┐' BL='└' BR='┘' H='─' V='│'

# Grid settings
COLS=4
BOX_WIDTH=12

# Clear screen and move cursor to top
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

# Function to get status color and icon
get_status_display() {
    local session="$1"
    local status="${STATUSES[$session]:-idle}"

    case "$status" in
        working)
            echo -e "${GREEN}●${RESET}"
            ;;
        waiting)
            echo -e "${YELLOW}●${RESET}"
            ;;
        error)
            echo -e "${RED}●${RESET}"
            ;;
        *)
            echo -e "${GREY}●${RESET}"
            ;;
    esac
}

get_status_bg() {
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
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║           MISSION CONTROL - STATUS OVERVIEW           ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo ""

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
    # Top border of boxes
    echo -n "    "
    for ((col=0; col<COLS; col++)); do
        if [[ $idx -lt $TOTAL ]]; then
            echo -n "${TL}${H}${H}${H}${H}${H}${H}${H}${H}${H}${H}${TR}  "
        fi
        ((idx++))
    done
    echo ""

    # Reset idx for content row
    idx=$((row * COLS))

    # Status icon row
    echo -n "    "
    for ((col=0; col<COLS; col++)); do
        if [[ $idx -lt $TOTAL ]]; then
            session="${SESSIONS[$idx]}"
            status_icon=$(get_status_display "$session")
            echo -n "${V}    ${status_icon}     ${V}  "
        fi
        ((idx++))
    done
    echo ""

    # Reset idx for name row
    idx=$((row * COLS))

    # Session name row
    echo -n "    "
    for ((col=0; col<COLS; col++)); do
        if [[ $idx -lt $TOTAL ]]; then
            session="${SESSIONS[$idx]}"
            # Truncate/pad name to 8 chars, remove claude- prefix
            short_name=$(echo "$session" | sed 's/^claude-//' | cut -c1-8)
            printf "${V} %-8s ${V}  " "$short_name"
        fi
        ((idx++))
    done
    echo ""

    # Reset idx for bottom border
    idx=$((row * COLS))

    # Bottom border of boxes
    echo -n "    "
    for ((col=0; col<COLS; col++)); do
        if [[ $idx -lt $TOTAL ]]; then
            echo -n "${BL}${H}${H}${H}${H}${H}${H}${H}${H}${H}${H}${BR}  "
        fi
        ((idx++))
    done
    echo ""
    echo ""
done

# Print legend
echo ""
echo -e "    ${GREEN}●${RESET} Working ($working)   ${YELLOW}●${RESET} Waiting ($waiting)   ${RED}●${RESET} Error ($error)   ${GREY}●${RESET} Idle ($idle)"
echo ""
echo -e "    ${GREY}Press ${WHITE}Ctrl-b n${GREY} for session pages${RESET}"
echo ""
echo -e "    ${GREY}Last update: $(date '+%H:%M:%S')${RESET}"
