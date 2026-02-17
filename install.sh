#!/bin/bash
# Install agent-monitor
# Copies scripts, patches tmux.conf, and configures Claude Code hooks.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"

info()  { printf '\033[1;34m==> %s\033[0m\n' "$1"; }
warn()  { printf '\033[1;33m==> %s\033[0m\n' "$1"; }
ok()    { printf '\033[1;32m==> %s\033[0m\n' "$1"; }

# 1. Copy scripts
info "Installing scripts to $BIN_DIR"
mkdir -p "$BIN_DIR"
cp "$REPO_DIR/bin/claude-dashboard"  "$BIN_DIR/claude-dashboard"
cp "$REPO_DIR/bin/claude-notify"     "$BIN_DIR/claude-notify"
cp "$REPO_DIR/bin/claude-state-hook" "$BIN_DIR/claude-state-hook"
chmod +x "$BIN_DIR/claude-dashboard" "$BIN_DIR/claude-notify" "$BIN_DIR/claude-state-hook"

# Ensure ~/.local/bin is on PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  warn "$BIN_DIR is not on your PATH. Add it to your shell profile:"
  warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Create state directory
mkdir -p /tmp/claude-agent-states

# 2. Patch tmux.conf
TMUX_CONF="$HOME/.tmux.conf"
MARKER="# agent-monitor"

if [ -f "$TMUX_CONF" ] && grep -qF "$MARKER" "$TMUX_CONF"; then
  info "tmux config already patched, skipping"
else
  info "Adding agent monitoring config to $TMUX_CONF"
  cat >> "$TMUX_CONF" << 'TMUX_EOF'

# agent-monitor
set -g monitor-silence 30
set -g silence-action other
set -g visual-silence off
set -g monitor-activity on
set -g activity-action other
set -g visual-activity off
set-window-option -g window-status-activity-style "dim"
set-window-option -g window-status-bell-style "dim"

# Dashboard popup (prefix + a) — jump via tmux source-file in client context
bind a display-popup -E -w 90% -h 80% "~/.local/bin/claude-dashboard" \; \
  if-shell "test -f /tmp/.claude-dashboard-jump" \
    "source-file /tmp/.claude-dashboard-jump ; run-shell 'rm -f /tmp/.claude-dashboard-jump'"
TMUX_EOF
  ok "tmux config patched. Run: tmux source-file ~/.tmux.conf"
fi

# 3. Configure Claude Code hooks (notifications + state tracking)
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
NOTIFY_CMD="$BIN_DIR/claude-notify"
STATE_CMD="$BIN_DIR/claude-state-hook"

info "Configuring Claude Code hooks"

/usr/bin/python3 << PYEOF
import json, os, sys

path = "$CLAUDE_SETTINGS"
notify_cmd = "$NOTIFY_CMD"
state_cmd = "$STATE_CMD"

# Load existing settings or start fresh
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)
else:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    settings = {}

if "hooks" not in settings:
    settings["hooks"] = {}

hooks = settings["hooks"]

# Helper: check if a command is already in an event's hook list
def has_command(event, cmd):
    for entry in hooks.get(event, []):
        for h in entry.get("hooks", []):
            if h.get("command", "") == cmd:
                return True
    return False

# Notification hooks: sound + state tracking
if not has_command("Notification", notify_cmd) or not has_command("Notification", state_cmd):
    # Rebuild Notification to include both handlers
    notify_hooks = []
    state_hooks_added = False
    for entry in hooks.get("Notification", []):
        # Remove old entries that reference our commands (will re-add below)
        filtered = [h for h in entry.get("hooks", [])
                    if h.get("command", "") not in (notify_cmd, state_cmd)]
        if filtered:
            entry["hooks"] = filtered
            notify_hooks.append(entry)

    notify_hooks.append({
        "matcher": "permission_prompt|idle_prompt",
        "hooks": [
            {"type": "command", "command": notify_cmd, "timeout": 5},
            {"type": "command", "command": state_cmd, "timeout": 5},
        ]
    })
    hooks["Notification"] = notify_hooks

# State tracking hooks for other events
state_hook_entry = {"hooks": [{"type": "command", "command": state_cmd, "timeout": 5}]}

for event in ("UserPromptSubmit", "PostToolUse", "Stop", "SessionEnd"):
    if not has_command(event, state_cmd):
        if event not in hooks:
            hooks[event] = []
        hooks[event].append(dict(state_hook_entry))

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print("Hooks configured in " + path)
PYEOF

ok "Claude hooks configured (new sessions only)"

# 4. Optional: terminal-notifier for visual notifications
if ! command -v terminal-notifier &>/dev/null; then
  warn "terminal-notifier not found. Sound notifications will still work."
  warn "For visual notifications: brew install terminal-notifier"
fi

echo ""
ok "Installation complete!"
echo ""
echo "  Dashboard:      prefix + a  (tmux popup)"
echo "  Notifications:  sound on permission_prompt / idle_prompt"
echo "  State tracking: thinking / waiting / idle (via hooks)"
echo ""
echo "  Note: Claude Code hooks only apply to NEW sessions."
echo "  Restart any running Claude sessions to pick up the hooks."
