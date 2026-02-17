# agent-monitor

Monitor and manage multiple AI coding agents running across tmux sessions. Currently supports Claude Code, with plans to support other models.

## What it does

- **Dashboard** (`prefix + a`): Interactive TUI showing all Claude agents grouped by tmux session. Navigate with vim bindings, press Enter or a number key to jump directly to any agent's pane.
- **Notifications**: Sound alerts when an agent needs attention (`permission_prompt`, `idle_prompt`). Uses `afplay` which bypasses macOS Focus mode.
- **tmux flags**: Windows with idle agents get flagged in the tmux status bar via `monitor-silence`.

## Requirements

- macOS (uses `afplay` for sound, bash 3.2 compatible)
- tmux
- Claude Code CLI
- Optional: `terminal-notifier` for visual notifications (`brew install terminal-notifier`)

## Install

```bash
git clone https://github.com/YOUR_USER/agent-monitor.git
cd agent-monitor
./install.sh
```

The install script:
1. Copies `claude-dashboard` and `claude-notify` to `~/.local/bin/`
2. Appends agent monitoring config to `~/.tmux.conf`
3. Adds a notification hook to `~/.claude/settings.json`

After installing, reload tmux: `tmux source-file ~/.tmux.conf`

## Usage

### Dashboard

Press `prefix + a` to open the dashboard as a tmux popup.

```
  ┌ main ────────────────────────────────────────
  │  [1]  ACTIVE   nvim:2 [running tool]
  │       PID 65078   CPU  5.2%  Uptime: 12m 3s
  │  [2]   IDLE    back:1
  │       PID 85490   CPU  0.1%  Uptime: 1m 5s

  ┌ review ──────────────────────────────────────
  │  [3]  ACTIVE   pr-42:0
  │       PID 91234   CPU  8.3%  Uptime: 3m 22s

  Total: 3 agents  2 active  1 idle

  j/k Navigate  Enter Jump  [1-9] Direct  r Refresh  q Quit
```

| Key | Action |
|-----|--------|
| `j` / `k` / arrows | Navigate between agents |
| `Enter` | Jump to selected agent's tmux pane |
| `1`-`9` | Jump directly to agent N |
| `gg` / `G` | First / last agent |
| `r` | Manual refresh |
| `q` | Quit |

### Notifications

Agents trigger sound alerts automatically when they need input:
- **Permission prompt** (Ping sound) - agent is waiting for tool approval
- **Idle prompt** (Pop sound) - agent is waiting for your input

Hooks are configured in `~/.claude/settings.json` and only apply to new Claude sessions.

## Uninstall

```bash
rm ~/.local/bin/claude-dashboard ~/.local/bin/claude-notify
```

Then remove the `# agent-monitor` block from `~/.tmux.conf` and the `hooks` block from `~/.claude/settings.json`.
