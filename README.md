# agent-monitor

Kanban-style TUI for monitoring and managing Claude Code agents running across tmux sessions. One tmux session = one quest; the dashboard groups your agents by quest and moves them through swim lanes (WORKING → MY REVIEW → PR REVIEW → ship) as you make progress.

## What it does

- **Kanban dashboard** (`prefix + a`): tmux popup showing every running Claude agent as a card, grouped by lane. Vim-navigable.
- **Per-quest workflow**: advance a quest forward (`f`) or back (`b`) through lanes; block it (`x`) with an optional reason; ship it past PR REVIEW to log it in history. All operations work at the quest (session) level — every agent in the session moves together.
- **Status detection**: each agent's state (thinking / waiting / done / idle) is tracked via Claude Code hooks, with a pane-scan fallback that catches transitions the hooks miss (long reasoning, long-running tools).
- **Per-quest time tracking**: lane transitions are journaled; on ship, the history line records total time and a per-lane breakdown.
- **Shipped registry**: every shipped quest gets a line in `shipped.md` with timestamp, tasks, durations, and the commit SHA + PR number for each repo the quest touched.
- **Branch + env display**: each agent card shows its git branch; sessions in `main/`, `dev/`, `prod/` working copies get an ENV badge.
- **Multi-stage tracker** (`t`): four-column todo board (BACKLOG → TODO → IN_PROGRESS → DONE) as a tmux popup. Assign a task to an agent and the assignment auto-promotes it to IN_PROGRESS.
- **Inline send** (`s`): preview an agent's last output and either send free-form text or pick a task from TODO to dispatch as a prompt.
- **Agent linking** (`L`): pair two agents so they can message each other; injected context lets each one know who their partner is.
- **Notes** (`n`) and **shipped history** (`H`): one-key access to `notes.md` and `shipped.md` in `$EDITOR`.
- **Notifications**: sound on permission prompts and idle prompts, terminal bell on state transitions to WAITING. Idle agents get a notification badge (DONE state) that clears when you visit the pane.
- **tmux activity flags**: windows with silent agents get flagged in the tmux status bar via `monitor-silence`.

## Requirements

- macOS (uses `afplay` for sound, bash 3.2 compatible)
- tmux
- Claude Code CLI
- `gh` (GitHub CLI) — optional, used to resolve PR numbers when shipping
- `terminal-notifier` — optional, for visual notifications (`brew install terminal-notifier`)

## Install

```bash
git clone https://github.com/Fenho/agent-monitor.git
cd agent-monitor
./install.sh
```

The install script:
1. Copies `claude-dashboard`, `claude-notify`, `claude-state-hook`, and `claude-pr-tracker` to `~/.local/bin/`
2. Appends the dashboard popup binding (`prefix + a`) and activity-monitoring config to `~/.tmux.conf`
3. Configures Claude Code hooks in `~/.claude/settings.json` for state tracking and notifications

After installing, reload tmux: `tmux source-file ~/.tmux.conf`. Claude Code hooks only apply to **new** sessions, so restart any running Claude agents to pick them up.

## Usage

### Dashboard

Press `prefix + a` to open the dashboard as a tmux popup.

```
  Agent Dashboard    3 working   2 my review   1 pr review

   WORKING · 3
  ╭─ 4 contact-collect ──────────────╮  ╭─ 5 noise ────────────────────────╮
  │ ▸ orchestrator                   │  │ ▸ full                           │
  │ [41] ○ IDLE                4d 3h │  │ [51] ○ IDLE                4d 3h │
  ╰──────────────────────────────────╯  ╰──────────────────────────────────╯

   MY REVIEW · 2
  ╭─ 1 inbound-ai-calls ─────────────╮  ╭─ 2 llm-ai-voice-call [PROD] ─────╮
  │ ▸ agent-monitor feat/foo         │  │ ▸ back tmp/d                     │
  │ [11] ⠹ THINKING              4m  │  │ [21] ○ IDLE                3d 4h │
  │ ▸ back                           │  │ ▸ orchestrator                   │
  │ ⚡ pnpm fenhogod                 │  │ [23] ★ ○ IDLE              3h 7m │
  ╰──────────────────────────────────╯  ╰──────────────────────────────────╯

  Total: 5 agents  1 thinking  0 waiting  4 idle  ·  2 apps  ·  2 todo  1 wip

  j/k ↕  h/l ↔  Enter Jump  m Mark  f/b Lane/Ship  x Block  H History
  L Link  s Send  n Notes  t Tracker  r Refresh  q Quit
```

Sessions render as rounded cards in lane-colored borders. Each card shows its windows (dim), the agents and apps in each window, and a closing border.

| Key | Action |
|-----|--------|
| `h` / `l` / left / right | Navigate between cards |
| `j` / `k` / up / down | Navigate between agents within a card |
| `Enter` | Jump to selected agent's tmux pane |
| `[S][R]` (e.g. `12`) | Jump to session S, row R |
| `gg` / `G` | First / last agent in the current column |
| `m` | Toggle mark on the selected agent (★) |
| `f` | Advance the quest one lane (WORKING → MY REVIEW → PR REVIEW → ship) |
| `b` | Retreat the quest one lane (no-op past WORKING) |
| `x` | Toggle BLOCKED on the quest; prompts for an optional reason |
| `L` | Link two agents — press on first, then on second |
| `s` | Send a message to the selected agent (preview, then free-form or task pick) |
| `n` | Open `notes.md` in `$EDITOR` |
| `H` | Open `shipped.md` in `$EDITOR` |
| `t` | Tracker overview popup (BACKLOG / TODO / IN_PROGRESS / DONE) |
| `r` | Manual refresh |
| `q` | Quit |

### Swim lanes

Quests start in **WORKING**. You move them forward with `f`:

- **WORKING** → MY REVIEW → PR REVIEW → ship (logged to `shipped.md`, agents marked shipped and hidden).
- **BLOCKED** is out of the main flow. Press `x` to send a quest there with an optional reason rendered inline under the card. Press `x` again to unblock — the quest returns to its prior workflow lane. `f`/`b` are no-ops while blocked.
- `BLOCKED` only appears as a column when at least one quest is in it.

When a new agent joins a session whose quest is already past WORKING (or is BLOCKED), it's auto-synced to the quest's lane on the next refresh — no manual catch-up needed.

### Status detection

| Icon | State | Color | Meaning |
|------|-------|-------|---------|
| `⠋⠙⠹…` | THINKING | Green (animated braille spinner) | Agent is processing |
| `◆` | WAITING | Yellow → Orange → Red | Agent needs input/approval (escalates over time) |
| `✓` | DONE | Magenta → Yellow → Orange → Red | Agent finished but you haven't seen it yet |
| `○` | IDLE | Dim | Agent is idle (acknowledged) |
| `?` | UNKNOWN | Dim | No state data available |

DONE clears automatically when you `Enter`-jump to the agent or when the agent's tmux pane is currently visible.

State is tracked two ways:
- **Hooks** (`claude-state-hook`): Claude Code fires hooks on `UserPromptSubmit`, `PostToolUse`, `Stop`, and `Notification`. Each write goes to `/tmp/claude-agent-states/<session_id>`.
- **Pane scan**: on every refresh the dashboard captures the tmux pane for any agent whose hook state is `idle`/`unknown` or whose `thinking` state is >60s stale. A spinner glyph (`…(Ns`) → THINKING. A permission prompt (`❯ 1. Yes`) → WAITING. Otherwise the file is trusted.

The pane-scan fallback catches the cases where hooks miss transitions — long reasoning chains, long-running tools, agents that died without firing `Stop`.

### Quest time tracking

Every lane transition is journaled to `~/.local/share/agent-monitor/lane-events.log`. On ship, durations are computed and appended to the history line:

```
- **18:32** 1 my-feature — refactor X  ⏱ 3h 0m total · W 2h 0m · R 40m · PR 10m  → `a3f7b2c` #42
```

- **⏱ total · W · R · PR · B**: time per lane (W=WORKING, R=MY REVIEW, PR=PR REVIEW, B=BLOCKED).
- **→ `sha` #pr**: commit SHA at HEAD and PR number (resolved via `gh pr list`) for each repo the quest touched. Multi-repo quests show one `sha #pr` per repo, comma-separated.
- In-flight quests that existed before lane tracking was added get a backdated WORKING start using `ps etime`, so totals are still useful.

### Tracker (`t`)

Multi-stage todo board, four files in `~/.local/share/agent-monitor/tracker/`:

```
BACKLOG.md → TODO.md → IN_PROGRESS.md → DONE.md
```

The `t` popup shows all four columns side by side with vim navigation. Pressing `s` on an agent and choosing "task from TODO" both dispatches the task as a prompt and promotes the task to IN_PROGRESS with an `> assigned: %pane_id` line — so the tracker remembers which agent is on it. Pressing `Enter` on an IN_PROGRESS task jumps to that agent.

### Notifications

Agents trigger sound alerts when they need input:
- **Permission prompt** (Ping) — agent is waiting for tool approval
- **Idle prompt** (Pop) — agent is waiting for your input

`afplay` is used so notifications fire even with macOS Focus Mode on. Sound hooks live in `~/.claude/settings.json` and only apply to new Claude sessions.

The dashboard also rings the terminal bell on a state transition into WAITING, and renders a notification badge (the DONE state, magenta-and-escalating) on agents that just went idle until you visit their pane.

### Configuration

Top-of-file variables in `claude-dashboard`:

| Variable | Default | Description |
|----------|---------|-------------|
| `REFRESH_INTERVAL` | `5` | Seconds between auto-refresh |
| `STATE_DIR` | `/tmp/claude-agent-states` | Where state hooks write per-session state files |
| `DATA_DIR` | `$HOME/.local/share/agent-monitor` | Tracker, notes, shipped history, lane journal |
| `MIN_COL_W` | `22` | Minimum card column width in characters |
| `MAX_COLS` | `8` | Max cards per row before wrapping to a new group |

### Files on disk

| Path | Contents |
|------|----------|
| `~/.local/share/agent-monitor/tracker/{BACKLOG,TODO,IN_PROGRESS,DONE}.md` | Tracker stages |
| `~/.local/share/agent-monitor/notes.md` | Free-form notes (`n` key) |
| `~/.local/share/agent-monitor/shipped.md` | Shipped quest history (`H` key) |
| `~/.local/share/agent-monitor/lane-events.log` | Per-quest lane transition journal |
| `/tmp/claude-agent-states/` | One file per Claude session, written by `claude-state-hook` |
| `/tmp/claude-dashboard-lanes` | tty → lane mapping |
| `/tmp/claude-dashboard-blocked` | tty → block reason |
| `/tmp/claude-dashboard-shipped` | Shipped tty list (hides them from the board) |
| `/tmp/claude-dashboard-{notifs,marks,links,prev-states,selected}` | UI state |
| `/tmp/claude-agent-messages/` | Inter-agent message inbox/outbox (linking) |

## Uninstall

```bash
rm ~/.local/bin/claude-{dashboard,notify,state-hook,pr-tracker}
rm -rf /tmp/claude-agent-states /tmp/claude-agent-messages /tmp/claude-dashboard-*
```

Then remove the `# agent-monitor` block from `~/.tmux.conf` and the hook entries from `~/.claude/settings.json`. Keep `~/.local/share/agent-monitor/` if you want to preserve your tracker, notes, and shipped history.
