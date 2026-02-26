# agent-monitor

Monitor and manage multiple AI coding agents running across tmux sessions. Currently supports Claude Code, with plans to support other models.

## What it does

- **Dashboard** (`prefix + a`): Interactive TUI showing all Claude agents as side-by-side session columns with vim navigation.
- **State tracking**: Real-time agent status via Claude Code hooks — thinking, waiting, done, or idle.
- **Urgency coloring**: Waiting agents escalate from yellow → orange → red over time. Done (unseen idle) agents escalate from magenta → yellow → orange → red.
- **Inline send**: Preview an agent's last output and send a message without leaving the dashboard.
- **Tracker popup**: Quick-access markdown tracker via tmux popup overlay.
- **Notifications**: Sound alerts when agents need attention. Terminal bell on state transitions. Uses `afplay` which bypasses macOS Focus mode.
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
  ┌ 1 flows  ▓▓░ 2●1◆      ┌ 2 reviewing  ░░ 2○
  │ ▸ monitor                │ ▸ back
  │ [11] ● THINKING    5m   │ [21] ○ IDLE       25m
  │ ▸ back                   │ ▸ front
  │ [12] ✓ DONE        2m   │ [22] ○ IDLE       3h
  │ ▸ front                  │
  │ [13] ◆ WAITING     8m   │

  Total: 5 agents  1 thinking  1 waiting  3 idle

  h/j/k/l Nav  Enter Jump  [S][R] Direct  m Mark  s Send  t Tracker  r Refresh  q Quit
```

Sessions are displayed as side-by-side columns (dynamically sized to fit the terminal). Each session header includes a productivity bar and state counts. Agents are grouped under their tmux window name.

| Key | Action |
|-----|--------|
| `h` / `l` / left / right | Navigate between sessions |
| `j` / `k` / up / down | Navigate between agents within a session |
| `Enter` | Jump to selected agent's tmux pane |
| `[S][R]` (e.g. `12`) | Jump to session S, row R |
| `gg` / `G` | First / last agent in current session |
| `m` | Toggle mark on the selected agent (persists across refreshes) |
| `s` | Send a message to the selected agent (shows output preview) |
| `t` | Open tracker file in `$EDITOR` |
| `r` | Manual refresh |
| `q` | Quit |

### Agent states

| Icon | State | Color | Meaning |
|------|-------|-------|---------|
| `●` | THINKING | Green | Agent is processing |
| `◆` | WAITING | Yellow → Orange → Red | Agent needs input/approval (escalates over time) |
| `✓` | DONE | Magenta → Yellow → Orange → Red | Agent finished but you haven't seen it yet |
| `○` | IDLE | Dim | Agent is idle (acknowledged) |
| `?` | UNKNOWN | Dim | No state hook data available |

DONE clears automatically when you jump to the agent from the dashboard, or when the agent's tmux pane is currently visible (checked every refresh cycle).

States are tracked via `claude-state-hook`, which writes to `/tmp/claude-agent-states/` on each hook event. Hooks only apply to Claude sessions started after installation.

### Configuration

These variables at the top of `claude-dashboard` can be customized:

| Variable | Default | Description |
|----------|---------|-------------|
| `REFRESH_INTERVAL` | `5` | Seconds between auto-refresh |
| `STATE_DIR` | `/tmp/claude-agent-states` | Where state hook writes agent states |
| `TRACKER_FILE` | `$HOME/.local/share/agent-monitor/tracker.md` | Markdown file opened by the `t` key (auto-created) |
| `MIN_COL_W` | `30` | Minimum column width in characters |

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
