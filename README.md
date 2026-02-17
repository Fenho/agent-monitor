# agent-monitor

Monitor and manage multiple AI coding agents running across tmux sessions. Currently supports Claude Code, with plans to support other models.

## What it does

- **Dashboard** (`prefix + a`): Interactive TUI showing all Claude agents as side-by-side session columns. Navigate with vim bindings (h/j/k/l), jump to any agent by typing its `[session][row]` shortcut.
- **State tracking**: Real-time agent status via Claude Code hooks — thinking, waiting for input, or idle.
- **Notifications**: Sound alerts when an agent needs attention (`permission_prompt`, `idle_prompt`). Uses `afplay` which bypasses macOS Focus mode.
- **tmux flags**: Windows with idle agents get flagged in the tmux status bar via `monitor-silence`.

## Requirements

- macOS (uses `afplay` for sound, bash 3.2 compatible)
- tmux
- Claude Code CLI
- Optional: `terminal-notifier` for visual notifications (`brew install terminal-notifier`)

## Install

```bash
git clone https://github.com/Fenho/agent-monitor.git
cd agent-monitor
./install.sh
```

The install script:
1. Copies `claude-dashboard`, `claude-notify`, and `claude-state-hook` to `~/.local/bin/`
2. Appends agent monitoring config to `~/.tmux.conf`
3. Configures Claude Code hooks in `~/.claude/settings.json` for notifications and state tracking

After installing, reload tmux: `tmux source-file ~/.tmux.conf`

## Usage

### Dashboard

Press `prefix + a` to open the dashboard as a tmux popup.

```
  ┌ 1 main (flows)      ┌ 2 reviewing         ┌ 3 sidequest
  │ [11] ● THINKING     │ [21] ○ IDLE          │ [31] ? UNKNOWN
  │   monitor:1  5m     │   back:2  25m        │   back:1  1d 1h
  │ [12] ○ IDLE         │ [22] ○ IDLE          │ [32] ? UNKNOWN
  │   back:2  57m       │   front:1  3h 12m    │   front:0  23h 43m
  │ [13] ? UNKNOWN      │                      │
  │   config:1  1d 6h   │                      │
  │ [14] ◆ WAITING      │                      │
  │   front:1  19h 54m  │                      │

  Total: 8 agents  0 thinking  1 waiting  7 idle

  h/j/k/l Nav  Enter Jump  [S][R] Direct  r Refresh  q Quit
```

Sessions are displayed as side-by-side columns (up to 4 per row). Each agent shows its status, window:pane, and uptime.

| Key | Action |
|-----|--------|
| `h` / `l` / left / right | Navigate between sessions |
| `j` / `k` / up / down | Navigate between agents within a session |
| `Enter` | Jump to selected agent's tmux pane |
| `[S][R]` (e.g. `12`) | Jump to session S, row R |
| `gg` / `G` | First / last agent in current session |
| `r` | Manual refresh |
| `q` | Quit |

### Agent states

| Icon | State | Meaning |
|------|-------|---------|
| `●` | THINKING | Agent is processing (green) |
| `◆` | WAITING | Agent needs input/approval (yellow) |
| `○` | IDLE | Agent is idle (dim) |
| `?` | UNKNOWN | No state hook data available (dim) |

States are tracked via `claude-state-hook`, which writes to `/tmp/claude-agent-states/` on each hook event. Hooks only apply to Claude sessions started after installation.

### Notifications

Agents trigger sound alerts automatically when they need input:
- **Permission prompt** (Ping sound) — agent is waiting for tool approval
- **Idle prompt** (Pop sound) — agent is waiting for your input

Hooks are configured in `~/.claude/settings.json` and only apply to new Claude sessions.

## Uninstall

```bash
rm ~/.local/bin/claude-dashboard ~/.local/bin/claude-notify ~/.local/bin/claude-state-hook
rm -rf /tmp/claude-agent-states
```

Then remove the `# agent-monitor` block from `~/.tmux.conf` and the hook entries from `~/.claude/settings.json`.
