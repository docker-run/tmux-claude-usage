#!/usr/bin/env bash
#
# One-step installer for the statusLine harvester. Wires this plugin's
# statusline.sh into ~/.claude/settings.json (with a backup), so Claude Code
# starts feeding usage data to the tmux segment. Safe to re-run.
#
#   ./scripts/init.sh            install; if another statusLine already exists,
#                                keep it by chaining (yours + the harvester both
#                                run from the one slot)
#   ./scripts/init.sh --force    install only the harvester, replacing any
#                                existing statusLine
#   ./scripts/init.sh --uninstall  remove the harvester; restore the statusLine
#                                we chained, if any
#
# Set CLAUDE_SETTINGS to target a different settings file (handy for testing).

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
HARVEST_CMD="$DIR/statusline.sh"
CHAIN_CMD="$DIR/chain.sh"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-usage"
ORIGINAL="$CONFIG_DIR/original-statusline.json"

command -v jq >/dev/null 2>&1 || {
	echo "error: jq is required (brew install jq / apt install jq)" >&2
	exit 1
}
chmod +x "$DIR"/*.sh 2>/dev/null || true

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' >"$SETTINGS"

if ! jq empty "$SETTINGS" 2>/dev/null; then
	echo "error: $SETTINGS is not valid JSON. Fix or remove it, then re-run." >&2
	exit 1
fi

backup="$SETTINGS.bak.$(date +%s)"
mode="${1:-}"

# Point the statusLine slot at one of our commands, keeping the existing
# padding (or 0). Args: command-path.
set_statusline() {
	local cmd="$1" tmp
	cp "$SETTINGS" "$backup"
	tmp="$(mktemp)"
	jq --arg cmd "$cmd" \
		'.statusLine = {type: "command", command: $cmd, padding: (.statusLine.padding // 0)}' \
		"$SETTINGS" >"$tmp" && mv "$tmp" "$SETTINGS"
}

next_steps() {
	cat <<EOF

Next:
  1. Make sure '#{claude_usage}' is in your tmux status-left/right and the
     plugin is loaded (TPM: prefix + I).
  2. Use Claude Code normally — the tmux segment updates as it renders.
  3. The usage data is sent only to Claude Pro/Max sessions; on API-key,
     Console, Bedrock, Vertex, or Team/Enterprise the bar stays empty.
EOF
}

current="$(jq -r '.statusLine.command // empty' "$SETTINGS")"

# --- uninstall -------------------------------------------------------------
if [ "$mode" = "--uninstall" ]; then
	cp "$SETTINGS" "$backup"
	tmp="$(mktemp)"
	if [ "$current" = "$CHAIN_CMD" ] && [ -f "$ORIGINAL" ]; then
		jq --slurpfile orig "$ORIGINAL" '.statusLine = $orig[0]' "$SETTINGS" >"$tmp" && mv "$tmp" "$SETTINGS"
		rm -f "$ORIGINAL"
		echo "✓ restored your original statusLine (backup: $backup)"
	elif [ "$current" = "$HARVEST_CMD" ] || [ "$current" = "$CHAIN_CMD" ]; then
		jq 'del(.statusLine)' "$SETTINGS" >"$tmp" && mv "$tmp" "$SETTINGS"
		rm -f "$ORIGINAL"
		echo "✓ removed statusLine from $SETTINGS (backup: $backup)"
	else
		rm -f "$tmp"
		echo "statusLine isn't this plugin's; leaving it untouched."
	fi
	exit 0
fi

# --- already ours (idempotent) ---------------------------------------------
if [ "$mode" != "--force" ] && { [ "$current" = "$HARVEST_CMD" ] || [ "$current" = "$CHAIN_CMD" ]; }; then
	echo "✓ already installed — nothing to do."
	echo "    command: $current"
	exit 0
fi

# --- a different statusLine exists: keep it by chaining --------------------
if [ "$mode" != "--force" ] && [ -n "$current" ]; then
	mkdir -p "$CONFIG_DIR"
	jq '.statusLine' "$SETTINGS" >"$ORIGINAL"
	cp "$SETTINGS" "$backup"
	tmp="$(mktemp)"
	jq --arg cmd "$CHAIN_CMD" '.statusLine.command = $cmd' "$SETTINGS" >"$tmp" && mv "$tmp" "$SETTINGS"
	cat <<EOF
✓ existing statusLine preserved — yours and the harvester now both run
    your line: $current
    saved to:  $ORIGINAL  (restored on --uninstall)
    backup:    $backup
EOF
	next_steps
	exit 0
fi

# --- plain install (or --force replace) ------------------------------------
set_statusline "$HARVEST_CMD"
[ "$mode" = "--force" ] && rm -f "$ORIGINAL"
cat <<EOF
✓ statusLine harvester installed
    command: $HARVEST_CMD
    backup:  $backup
EOF
next_steps
