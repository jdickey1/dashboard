#!/bin/bash
#
# Claude Code Hook: Stop
# Called when Claude finishes a response - now idle/ready for input
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/update-status.sh" "idle" "Ready"
