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
cp "$REPO_DIR/bin/claude-dashboard" "$BIN_DIR/claude-dashboard"
cp "$REPO_DIR/bin/claude-notify"    "$BIN_DIR/claude-notify"
chmod +x "$BIN_DIR/claude-dashboard" "$BIN_DIR/claude-notify"

# Ensure ~/.local/bin is on PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  warn "$BIN_DIR is not on your PATH. Add it to your shell profile:"
  warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

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
bind a display-popup -E -w 80% -h 80% "~/.local/bin/claude-dashboard" \; \
  if-shell "test -f /tmp/.claude-dashboard-jump" \
    "source-file /tmp/.claude-dashboard-jump ; run-shell 'rm -f /tmp/.claude-dashboard-jump'"
TMUX_EOF
  ok "tmux config patched. Run: tmux source-file ~/.tmux.conf"
fi

# 3. Configure Claude Code notification hook
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
NOTIFY_CMD="$BIN_DIR/claude-notify"

info "Configuring Claude Code notification hook"

if [ -f "$CLAUDE_SETTINGS" ]; then
  # Check if hook already exists
  if grep -qF "claude-notify" "$CLAUDE_SETTINGS"; then
    info "Claude hook already configured, skipping"
  else
    # Use python to merge the hook into existing settings
    /usr/bin/python3 << PYEOF
import json, sys

path = "$CLAUDE_SETTINGS"
cmd = "$NOTIFY_CMD"

with open(path) as f:
    settings = json.load(f)

hook_entry = {
    "matcher": "permission_prompt|idle_prompt",
    "hooks": [
        {
            "type": "command",
            "command": cmd,
            "timeout": 5
        }
    ]
}

if "hooks" not in settings:
    settings["hooks"] = {}

if "Notification" not in settings["hooks"]:
    settings["hooks"]["Notification"] = []

settings["hooks"]["Notification"].append(hook_entry)

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print("Hook added to " + path)
PYEOF
    ok "Claude hook configured (new sessions only)"
  fi
else
  mkdir -p "$HOME/.claude"
  cat > "$CLAUDE_SETTINGS" << JSONEOF
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt|idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "$NOTIFY_CMD",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
JSONEOF
  ok "Created $CLAUDE_SETTINGS with notification hook"
fi

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
echo ""
echo "  Note: Claude Code hooks only apply to NEW sessions."
echo "  Restart any running Claude sessions to pick up the hook."
