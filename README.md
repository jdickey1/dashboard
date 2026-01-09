# Mission Control for Claude Code

A tmux-based dashboard for monitoring and interacting with multiple Claude Code sessions across local and remote machines. View all your Claude instances in a single, paginated grid interface.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ MISSION CONTROL                              [1/6] agents jdkey link        │
├───────────────────────────┬───────────────────────────┬─────────────────────┤
│ claude-agents             │ claude-jdkey              │ claude-link         │
│                           │                           │                     │
│ $ claude                  │ $ claude                  │ $ claude            │
│ > Deploying service...    │ > Running tests...        │ > Building...       │
│                           │                           │                     │
├───────────────────────────┴───────────────────────────┴─────────────────────┤
│                        Ctrl-b n/p: pages | 04:30                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **Paginated grid view**: 3 sessions per page, navigate with `Ctrl-b n/p`
- **Local & remote sessions**: Monitor tmux sessions on the same machine or via SSH
- **Direct interaction**: Click into any pane to interact with that Claude instance
- **Session setup script**: Automatically create all your tmux sessions
- **Configurable**: Define your sessions in a simple JSON config file

## Requirements

### Local Machine (where you run Mission Control)

- **tmux** 3.0+
- **jq** (JSON processor)
- **bash** 4.0+
- **SSH access** to remote hosts (for remote sessions)

### Remote Machines (for remote sessions only)

- **tmux** installed and accessible in PATH
- **SSH server** with key-based authentication (recommended)
- Target tmux sessions must already exist

### Installing Dependencies

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install tmux jq

# macOS (Homebrew)
brew install tmux jq
```

**Note for macOS**: Homebrew installs tmux to `/opt/homebrew/bin/`. For remote sessions to work, ensure tmux is in PATH for non-interactive SSH shells by adding to `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="/opt/homebrew/bin:$PATH"
```

### Recommended tmux Configuration

Add to `/etc/tmux.conf` or `~/.tmux.conf` on all machines:

```bash
# Start window/pane numbering at 1 (easier keyboard navigation)
set -g base-index 1
setw -g pane-base-index 1

# Enable mouse support for pane selection
set -g mouse on
```

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/jdickey1/dashboard.git
   cd dashboard
   ```

2. **Create your configuration**:
   ```bash
   cp config.example.json config.json
   ```

3. **Edit `config.json`** with your sessions (see Configuration below)

4. **(Optional) Install Claude Code hooks** for status updates:
   ```bash
   ./install.sh
   ```

## Configuration

Edit `config.json` to define your sessions:

```json
{
  "sessions": [
    {
      "name": "claude-project1",
      "host": "localhost",
      "type": "local",
      "description": "My first project"
    },
    {
      "name": "claude-remote1",
      "host": "user@remote-server",
      "type": "remote",
      "description": "Remote Claude instance"
    }
  ],
  "layout": {
    "columns": 3,
    "show_status_bar": true
  }
}
```

### Session Types

| Type | Description |
|------|-------------|
| `local` | Attaches to a tmux session on the current machine |
| `remote` | SSHs to the specified host and attaches to the tmux session |

### Session Naming Convention

We recommend prefixing all session names with `claude-` for consistency:
- `claude-myproject`
- `claude-server1`
- `claude-admin`

## Usage

### Creating Sessions

Before launching Mission Control, create your tmux sessions:

```bash
# Create sessions manually
tmux new-session -d -s claude-myproject -c /path/to/project

# Or use the setup script (edit it first with your sessions)
./scripts/setup-vps-sessions.sh
```

### Launching Mission Control

```bash
./scripts/mission-control.sh
```

Or with a custom config:

```bash
./scripts/mission-control.sh /path/to/config.json
```

### Navigation

| Key | Action |
|-----|--------|
| `Ctrl-b n` | Next page |
| `Ctrl-b p` | Previous page |
| `Ctrl-b 0-9` | Jump to page number |
| Arrow keys | Move between panes on current page |
| `Ctrl-b z` | Zoom/unzoom current pane (fullscreen) |
| `Ctrl-b d` | Detach from Mission Control |
| Mouse click | Select a pane (if mouse mode enabled) |

### Interacting with Sessions

Click or navigate to any pane and start typing - you're directly connected to that Claude Code session.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/mission-control.sh` | Main dashboard launcher |
| `scripts/setup-vps-sessions.sh` | Create tmux sessions (customize for your setup) |
| `install.sh` | Install Claude Code hooks for status updates |

## Claude Code Hooks (Optional)

The hooks system can automatically update session status indicators:

| Event | Status | Trigger |
|-------|--------|---------|
| `UserPromptSubmit` | Working | User sends a prompt |
| `Stop` | Idle | Claude finishes responding |
| `PreToolUse:AskUserQuestion` | Waiting | Claude asks a question |

Install hooks with `./install.sh` or manually add them to `~/.claude/settings.json`.

## Troubleshooting

### "can't find window: 0"

This occurs when the tmux server isn't running and `base-index` defaults to 0 instead of your configured value. The script handles this automatically by running `tmux start-server` first.

### "no space for new pane"

Your terminal is too narrow for 3 horizontal panes. The script creates sessions with a minimum size of 200x50 to prevent this. Make sure your terminal is at least 60 columns wide when attaching.

### Remote session not connecting

1. Verify SSH access works:
   ```bash
   ssh user@host -t 'tmux list-sessions'
   ```

2. If you get "tmux: command not found", ensure tmux is in PATH for non-interactive shells. Add to `~/.bashrc` on the remote host:
   ```bash
   export PATH="/opt/homebrew/bin:$PATH"  # macOS with Homebrew
   # or
   export PATH="/usr/local/bin:$PATH"     # Linux custom install
   ```

3. Verify the target session exists on the remote host:
   ```bash
   ssh user@host 'tmux has-session -t session-name && echo exists'
   ```

### Session directories not accessible

If setup-vps-sessions.sh reports directories not found, ensure the user running the script has execute permission on parent directories:

```bash
sudo chmod o+x /home/username
```

### Sessions disconnecting immediately

The target tmux session must exist before Mission Control can attach:

```bash
# Check if session exists
tmux has-session -t claude-myproject 2>/dev/null && echo "exists" || echo "not found"

# Create it if needed
tmux new-session -d -s claude-myproject
```

## File Structure

```
dashboard/
├── config.json              # Your session configuration (git-ignored)
├── config.example.json      # Example configuration
├── install.sh               # Hook installation script
├── scripts/
│   ├── mission-control.sh   # Main dashboard launcher
│   └── setup-vps-sessions.sh # Session creation helper
└── hooks/
    └── claude-hooks.json    # Claude Code hook definitions
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see LICENSE file for details.

## Acknowledgments

Built for managing multiple [Claude Code](https://claude.ai/claude-code) instances across development environments.
