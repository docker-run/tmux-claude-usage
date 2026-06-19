#!/usr/bin/env bash
#
# Claude Code statusLine command — the "harvester".
#
# Claude Code runs this on every render and passes session JSON on stdin. We
# pull out the official account usage (rate_limits) and write it to a small
# cache file for the tmux segment to read. It prints nothing, so no status line
# appears in the pane — the data shows up only in your tmux bar.

set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage"
CACHE_FILE="$CACHE_DIR/usage"

input="$(cat)"

# jq is required to parse Claude's JSON; if it's missing, do nothing quietly.
command -v jq >/dev/null 2>&1 || exit 0

data="$(printf '%s' "$input" | jq -r '
	.rate_limits as $r
	| "FIVE_HOUR_PCT=\($r.five_hour.used_percentage // "")",
	  "FIVE_HOUR_RESET=\($r.five_hour.resets_at // "")",
	  "SEVEN_DAY_PCT=\($r.seven_day.used_percentage // "")",
	  "SEVEN_DAY_RESET=\($r.seven_day.resets_at // "")"
' 2>/dev/null)" || exit 0

# Only write when we actually have usage data, so a render without rate_limits
# (older clients, transient nulls) never clobbers a good cache.
if printf '%s' "$data" | grep -q 'PCT=[0-9]'; then
	mkdir -p "$CACHE_DIR"
	{
		printf '%s\n' "$data"
		printf 'UPDATED_AT=%s\n' "$(date +%s)"
	} >"$CACHE_FILE.tmp" 2>/dev/null && mv "$CACHE_FILE.tmp" "$CACHE_FILE" 2>/dev/null
fi

# Silent harvester: print nothing.
exit 0
