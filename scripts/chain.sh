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
ORIGINAL="${XDG_CONFIG_HOME:-$HOME/.config}/claude-usage/original-statusline.json"

json="$(cat)"

# Harvest: write the usage cache, discard the (empty) output.
printf '%s' "$json" | "$DIR/statusline.sh" >/dev/null 2>&1

# Re-run your original statusLine on the same JSON and pass its output through.
# The command string is read from a file (never embedded in another quoting
# layer), so arbitrary quotes in it survive intact.
if [ -f "$ORIGINAL" ] && command -v jq >/dev/null 2>&1; then
	cmd="$(jq -r '.command // empty' "$ORIGINAL" 2>/dev/null)"
	[ -n "$cmd" ] && printf '%s' "$json" | bash -c "$cmd"
fi
