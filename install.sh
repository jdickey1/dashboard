#!/bin/bash
#
# Dashboard Installation Script
#
# This script installs the Claude Code hooks for the mission control dashboard.
#
# Usage: ./install.sh [options]
#   --hooks-only    Only install hooks (don't set up config)
#   --uninstall     Remove hooks
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CONFIG_DIR="$HOME/.claude"
HOOKS_INSTALL_DIR="$HOME/.local/share/dashboard/hooks"

# Parse arguments
HOOKS_ONLY=false
UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --hooks-only)
            HOOKS_ONLY=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if $UNINSTALL; then
    echo "Uninstalling dashboard hooks..."

    # Remove hooks directory
    rm -rf "$HOOKS_INSTALL_DIR"

    # Remove from Claude settings
    if [[ -f "$CLAUDE_CONFIG_DIR/settings.json" ]]; then
        echo "Note: You may need to manually remove dashboard hooks from $CLAUDE_CONFIG_DIR/settings.json"
    fi

    echo "Uninstall complete."
    exit 0
fi

echo "Installing Dashboard for Claude Code..."
echo ""

# Create hooks directory
mkdir -p "$HOOKS_INSTALL_DIR"

# Copy hook scripts
cp "$SCRIPT_DIR/hooks/"*.sh "$HOOKS_INSTALL_DIR/"
chmod +x "$HOOKS_INSTALL_DIR/"*.sh

echo "Hooks installed to: $HOOKS_INSTALL_DIR"

# Set environment variable for hooks
export DASHBOARD_HOOKS_DIR="$HOOKS_INSTALL_DIR"

if ! $HOOKS_ONLY; then
    # Copy example config if no config exists
    if [[ ! -f "$SCRIPT_DIR/config.json" ]]; then
        cp "$SCRIPT_DIR/config.example.json" "$SCRIPT_DIR/config.json"
        echo "Created config.json from example - please customize it."
    fi
fi

# Generate Claude Code settings snippet
cat << EOF

===============================================================================
Add the following hooks to your Claude Code settings.

For ~/.claude/settings.json, add to the "hooks" section:

{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_INSTALL_DIR/on-prompt-submit.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_INSTALL_DIR/on-stop.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_INSTALL_DIR/on-waiting.sh"
          }
        ]
      }
    ]
  }
}

Or run: claude config hooks to configure interactively.
===============================================================================

To start Mission Control:
  cd $SCRIPT_DIR
  ./scripts/mission-control.sh

EOF

echo "Installation complete!"
