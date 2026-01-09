# Dashboard

Mission control for Claude Code tmux sessions. View and interact with multiple Claude instances from a single screen.

```
┌─────────────────────────────────────────────────────────────────┐
│ MISSION CONTROL                                                  │
├────────────────────────┬────────────────────────┬───────────────┤
│ 🟢 mini1: Refactoring  │ 🟡 jdkey: Needs input  │ ⚪ obsidian   │
│                        │                        │               │
│ $ claude               │ $ claude               │ $ _           │
│ > Working on auth...   │ ? Enter API key:       │               │
│                        │                        │               │
├────────────────────────┼────────────────────────┼───────────────┤
│ 🟢 mini2: Running tests│ 🟢 agents: Deploying   │ 🔴 nonroot    │
│                        │                        │               │
│ $ claude               │ $ claude               │ Build failed  │
│ > npm test...          │ > pm2 reload...        │               │
│                        │                        │               │
└────────────────────────┴────────────────────────┴───────────────┘
```

## Features

- **Grid view** of all Claude Code sessions (local and remote)
- **Status indicators**: 🟢 working, 🟡 waiting for input, ⚪ idle, 🔴 error
- **Interactive**: Click into any pane to interact with that session
- **Cross-machine**: Monitor sessions on remote hosts via SSH

## Quick Start

1. **Clone the repo**:
   ```bash
   git clone https://github.com/jdickey1/dashboard.git
   cd dashboard
   ```

2. **Configure your sessions**:
   ```bash
   cp config.example.json config.json
   # Edit config.json with your tmux session names
   ```

3. **Install the hooks**:
   ```bash
   ./install.sh
   ```

4. **Start Mission Control**:
   ```bash
   ./scripts/mission-control.sh
   ```

## Configuration

Edit `config.json` to define your sessions:

```json
{
  "sessions": [
    {
      "name": "mini1",
      "host": "macmini",
      "type": "remote",
      "description": "Mac Mini Claude instance"
    },
    {
      "name": "jdkey",
      "host": "localhost",
      "type": "local",
      "description": "jdkey.com project"
    }
  ],
  "layout": {
    "columns": 3
  }
}
```

### Session Types

- **local**: Attaches to a tmux session on the same machine
- **remote**: SSHs to the host and attaches to the tmux session there

## Claude Code Hooks

The hooks automatically update the dashboard when Claude's status changes:

| Event | Status | Trigger |
|-------|--------|---------|
| `UserPromptSubmit` | 🟢 working | User sends a prompt |
| `Stop` | ⚪ idle | Claude finishes responding |
| `PreToolUse:AskUserQuestion` | 🟡 waiting | Claude asks a question |

### Manual Hook Installation

If the automatic installation doesn't work, add these hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "~/.local/share/dashboard/hooks/on-prompt-submit.sh"}]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "~/.local/share/dashboard/hooks/on-stop.sh"}]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [{"type": "command", "command": "~/.local/share/dashboard/hooks/on-waiting.sh"}]
      }
    ]
  }
}
```

## Usage

### Navigation

- **Switch panes**: `Ctrl-b` then arrow keys (or click with mouse)
- **Zoom pane**: `Ctrl-b z` (toggle fullscreen for current pane)
- **Detach**: `Ctrl-b d`

### Interacting with Sessions

Just click into a pane and type! You're directly connected to that tmux session.

Common commands:
- `/clear` - Clear conversation and start fresh
- `Ctrl-c` - Cancel current operation
- Type any prompt to continue working

## Requirements

- tmux
- jq
- SSH access to remote hosts (for remote sessions)
- Claude Code with hooks support

## File Structure

```
dashboard/
├── config.json              # Your session configuration
├── config.example.json      # Example configuration
├── install.sh               # Installation script
├── scripts/
│   └── mission-control.sh   # Main tmux grid launcher
└── hooks/
    ├── update-status.sh     # Core status update logic
    ├── on-prompt-submit.sh  # Hook: user submitted prompt
    ├── on-stop.sh           # Hook: Claude finished
    └── on-waiting.sh        # Hook: Claude needs input
```

## Troubleshooting

### Session not found
Make sure the tmux session exists before starting Mission Control:
```bash
tmux new-session -d -s mysession
```

### Remote session not connecting
Check SSH access:
```bash
ssh macmini -t 'tmux list-sessions'
```

### Hooks not firing
Verify hooks are installed:
```bash
ls ~/.local/share/dashboard/hooks/
cat ~/.claude/settings.json | jq '.hooks'
```

## License

MIT
