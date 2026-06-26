#!/usr/bin/env bash
#
# Passthrough wrapper for users who already run a Claude Code statusLine.
#
# A session has exactly one statusLine slot, but this plugin needs to harvest
# usage data *and* you may want to keep your own context/cost/git line. This
# wrapper runs both from the one slot: it reads the session JSON once, feeds a
# copy to our silent harvester (which writes the usage cache and prints
# nothing), then re-runs your original statusLine on the same JSON and lets
# *its* output through to the pane. init.sh wires this in and records your
# original statusLine object in $ORIGINAL.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Pinned under $HOME (not XDG_CONFIG_HOME): we run inside Claude Code's render
# environment, which can lack the XDG vars your interactive shell sets — so a
# fixed $HOME path guarantees we read the same file init.sh wrote. Must match the
# path hardcoded in scripts/init.sh.
ORIGINAL="$HOME/.config/claude-usage/original-statusline.json"

json="$(cat)"

# Harvest: write the usage cache, discard the (empty) output.
printf '%s' "$json" | "$DIR/statusline.sh" >/dev/null 2>&1

# Resolve jq the same way the harvester does. Claude Code may be launched from a
# GUI or IDE whose PATH lacks Homebrew etc., so fall back to common install
# locations before giving up. Without this, a chained statusLine would silently
# vanish in exactly the environment statusline.sh is hardened against — the
# usage cache would keep updating while your own line disappeared. Keep the probe
# list in sync with scripts/statusline.sh.
JQ="$(command -v jq 2>/dev/null || true)"
if [ -z "$JQ" ]; then
	for d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin /home/linuxbrew/.linuxbrew/bin; do
		if [ -x "$d/jq" ]; then JQ="$d/jq"; break; fi
	done
fi

# Re-run your original statusLine on the same JSON and pass its output through.
# The command string is read from a file (never embedded in another quoting
# layer), so arbitrary quotes in it survive intact.
if [ -f "$ORIGINAL" ] && [ -n "$JQ" ]; then
	cmd="$("$JQ" -r '.command // empty' "$ORIGINAL" 2>/dev/null)"
	[ -n "$cmd" ] && printf '%s' "$json" | bash -c "$cmd"
fi
