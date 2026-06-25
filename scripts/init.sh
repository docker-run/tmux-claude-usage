#!/usr/bin/env bash
#
# One-step installer for the statusLine harvester. Wires this plugin's
# statusline.sh into Claude Code's settings.json (with a backup), so Claude Code
# starts feeding usage data to the tmux segment. Safe to re-run.
#
#   ./scripts/init.sh            install; if another statusLine already exists,
#                                keep it by chaining (yours + the harvester both
#                                run from the one slot)
#   ./scripts/init.sh --force    install only the harvester, replacing any
#                                existing statusLine
#   ./scripts/init.sh --uninstall  remove the harvester; restore the statusLine
#                                we chained, if any
#   ./scripts/init.sh --check    diagnose a blank/stale bar (jq, wiring, cache,
#                                tmux segment) without changing anything
#
# Settings file: $CLAUDE_SETTINGS if set, else $CLAUDE_CONFIG_DIR/settings.json,
# else ~/.claude/settings.json.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$DIR/helpers.sh"
SETTINGS="${CLAUDE_SETTINGS:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json}"
HARVEST_CMD="$DIR/statusline.sh"
CHAIN_CMD="$DIR/chain.sh"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-usage"
ORIGINAL="$CONFIG_DIR/original-statusline.json"
mode="${1:-}"

# Diagnose the whole chain and exit. Read-only, and runs before the hard jq
# requirement so it can report a missing jq instead of bailing out. Runs in a
# subshell with `set +e` so a failed check never aborts the rest.
run_doctor() (
	set +e
	echo "claude-usage doctor"
	echo
	problems=0

	jqpath="$(command -v jq 2>/dev/null)"
	if [ -z "$jqpath" ]; then
		for d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin /home/linuxbrew/.linuxbrew/bin; do
			if [ -x "$d/jq" ]; then jqpath="$d/jq"; break; fi
		done
	fi
	if [ -n "$jqpath" ]; then
		echo "  ✓ jq found: $jqpath"
	else
		echo "  ✗ jq not found — install it (brew install jq / apt install jq)"
		problems=1
	fi

	if [ ! -f "$SETTINGS" ]; then
		echo "  ✗ Claude settings not found: $SETTINGS"
		echo "      (set CLAUDE_CONFIG_DIR if your Claude config lives elsewhere)"
		echo "      then run: $DIR/init.sh"
		problems=1
	elif [ -n "$jqpath" ]; then
		cmd="$("$jqpath" -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null)"
		case "$cmd" in
		"$HARVEST_CMD")
			echo "  ✓ statusLine wired to the harvester ($SETTINGS)" ;;
		"$CHAIN_CMD")
			echo "  ✓ statusLine wired (chained with your own line) ($SETTINGS)" ;;
		"")
			echo "  ✗ no statusLine configured — run: $DIR/init.sh"
			problems=1 ;;
		*)
			echo "  ✗ statusLine points elsewhere: $cmd"
			echo "      run: $DIR/init.sh   (it will chain, keeping that line)"
			problems=1 ;;
		esac
	fi

	cache="$(usage_cache_file)"
	pct="$(grep -oE 'FIVE_HOUR_PCT=[0-9.]+' "$cache" 2>/dev/null | cut -d= -f2)"
	if [ -n "$pct" ]; then
		ua="$(grep -oE 'UPDATED_AT=[0-9]+' "$cache" 2>/dev/null | cut -d= -f2)"
		echo "  ✓ usage cached: ${pct}% (updated $(( ( $(date +%s) - ${ua:-0} ) / 60 )) min ago) — data is arriving"
	elif [ -f "$cache" ]; then
		echo "  • cache present but no usage numbers yet — let Claude Code render once more"
	else
		echo "  • no usage cached yet ($cache)"
		echo "      Use Claude Code (signed into Pro/Max) so it renders and feeds the bar."
		echo "      On API/Console/Bedrock/Vertex/Team/Enterprise rate_limits isn't sent,"
		echo "      so the bar stays empty — that's expected, not a bug."
	fi

	if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
		wired="$(tmux show-option -gqv status-left 2>/dev/null)$(tmux show-option -gqv status-right 2>/dev/null)"
		if printf '%s' "$wired" | grep -q 'segment.sh'; then
			echo "  ✓ segment present in your tmux status line"
		elif printf '%s' "$wired" | grep -q 'claude_usage'; then
			echo "  ✗ '#{claude_usage}' not expanded yet — load the plugin (TPM: prefix + I)"
			problems=1
		else
			echo "  ✗ segment not in status-left/right — add '#{claude_usage}' and reload tmux"
			problems=1
		fi
	else
		echo "  • not inside a tmux server — run this from your tmux session to check wiring"
	fi

	echo
	if [ "$problems" -eq 0 ]; then
		echo "All checks passed."
	else
		echo "Some checks need attention (see ✗ above)."
	fi
	exit "$problems"
)

if [ "$mode" = "--check" ]; then
	run_doctor || exit $?
	exit 0
fi

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

# Back up settings.json, then keep only the newest $KEEP_BACKUPS so the .bak
# files don't pile up over repeated installs/uninstalls. Backups are named by
# epoch, so iterating the (lexically sorted) glob is already oldest-first.
KEEP_BACKUPS=3
backup_settings() {
	cp "$SETTINGS" "$backup"
	local f all=()
	for f in "$SETTINGS".bak.*; do
		[ -e "$f" ] && all+=("$f")
	done
	local drop=$((${#all[@]} - KEEP_BACKUPS)) i
	for ((i = 0; i < drop; i++)); do rm -f "${all[$i]}"; done
}

# Point the statusLine slot at one of our commands, keeping the existing
# padding (or 0). Args: command-path.
set_statusline() {
	local cmd="$1" tmp
	backup_settings
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

Bar empty or not updating? Diagnose it: $DIR/init.sh --check
EOF
}

current="$(jq -r '.statusLine.command // empty' "$SETTINGS")"

# --- uninstall -------------------------------------------------------------
if [ "$mode" = "--uninstall" ]; then
	backup_settings
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
	backup_settings
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
