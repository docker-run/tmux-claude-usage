#!/usr/bin/env bash
#
# One-step installer for the statusLine harvester. Wires this plugin's
# statusline.sh into ~/.claude/settings.json (with a backup), so Claude Code
# starts feeding usage data to the tmux segment. Safe to re-run.
#
#   ./scripts/init.sh            install (refuses to replace an existing statusLine)
#   ./scripts/init.sh --force    install, replacing any existing statusLine
#   ./scripts/init.sh --uninstall  remove our statusLine again

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"
CMD="$DIR/statusline.sh"

command -v jq >/dev/null 2>&1 || {
	echo "error: jq is required (brew install jq / apt install jq)" >&2
	exit 1
}
chmod +x "$DIR"/*.sh 2>/dev/null || true

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' >"$SETTINGS"

backup="$SETTINGS.bak.$(date +%s)"

if [ "${1:-}" = "--uninstall" ]; then
	cp "$SETTINGS" "$backup"
	tmp="$(mktemp)"
	jq 'del(.statusLine)' "$SETTINGS" >"$tmp" && mv "$tmp" "$SETTINGS"
	echo "✓ removed statusLine from $SETTINGS (backup: $backup)"
	exit 0
fi

existing="$(jq -r '.statusLine.command // empty' "$SETTINGS")"
if [ -n "$existing" ] && [ "$existing" != "$CMD" ] && [ "${1:-}" != "--force" ]; then
	echo "A different statusLine command is already configured:" >&2
	echo "  $existing" >&2
	echo "Re-run with --force to replace it (it will be backed up first)." >&2
	exit 1
fi

cp "$SETTINGS" "$backup"
tmp="$(mktemp)"
jq --arg cmd "$CMD" \
	'.statusLine = {type: "command", command: $cmd, padding: 0}' \
	"$SETTINGS" >"$tmp" && mv "$tmp" "$SETTINGS"

cat <<EOF
✓ statusLine harvester installed
    command: $CMD
    backup:  $backup

Next:
  1. Make sure '#{claude_usage}' is in your tmux status-left/right and the
     plugin is loaded (TPM: prefix + I).
  2. Use Claude Code normally — the tmux segment updates as it renders.
EOF
