#!/usr/bin/env bash
#
# Claude Code statusLine command — the "harvester".
#
# Claude Code runs this on every render and passes session JSON on stdin. We
# pull out the official account usage (rate_limits) and write it to a small
# cache file for the tmux segment to read. It prints nothing, so no status line
# appears in the pane — the data shows up only in your tmux bar.

set -uo pipefail

# Pinned under $HOME (not XDG_CACHE_HOME) so this harvester and the tmux segment
# always resolve the same path even when their environments differ. Must match
# helpers.sh usage_cache_file().
CACHE_DIR="$HOME/.cache/claude-usage"
CACHE_FILE="$CACHE_DIR/usage"

input="$(cat)"

# jq is required to parse Claude's JSON. Claude Code may be launched from a GUI
# or other non-interactive context whose PATH lacks Homebrew etc., so fall back
# to common install locations before giving up quietly.
JQ="$(command -v jq 2>/dev/null || true)"
if [ -z "$JQ" ]; then
	for d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin /home/linuxbrew/.linuxbrew/bin; do
		if [ -x "$d/jq" ]; then JQ="$d/jq"; break; fi
	done
fi
[ -n "$JQ" ] || exit 0

data="$(printf '%s' "$input" | "$JQ" -r '
	.rate_limits as $r
	| "FIVE_HOUR_PCT=\($r.five_hour.used_percentage // "")",
	  "FIVE_HOUR_RESET=\($r.five_hour.resets_at // "")",
	  "SEVEN_DAY_PCT=\($r.seven_day.used_percentage // "")",
	  "SEVEN_DAY_RESET=\($r.seven_day.resets_at // "")"
' 2>/dev/null)" || exit 0

# Freshness guard for the shared cache. Every Claude Code session writes this
# one file, and under a statusLine refreshInterval even long-idle sessions
# re-render and replay the stale rate_limits snapshot they last saw — so without
# this the bar flickers between old windows. Accept a snapshot only if it is at
# least as fresh as what's cached: a later window (greater resets_at) always
# wins, and within the same window the higher used_percentage is the more recent
# reading (usage only climbs until the window resets). Compared on five_hour,
# the primary signal; seven_day rides along from the same snapshot. If either
# side lacks a numeric five_hour reading we don't outsmart it and just write.
should_write() {
	[ -f "$CACHE_FILE" ] || return 0 # nothing cached yet

	local nr np cr cp
	nr="$(printf '%s\n' "$data" | sed -n 's/^FIVE_HOUR_RESET=//p')"
	np="$(printf '%s\n' "$data" | sed -n 's/^FIVE_HOUR_PCT=//p')"
	cr="$(sed -n 's/^FIVE_HOUR_RESET=//p' "$CACHE_FILE" 2>/dev/null)"
	cp="$(sed -n 's/^FIVE_HOUR_PCT=//p' "$CACHE_FILE" 2>/dev/null)"

	awk -v nr="$nr" -v np="$np" -v cr="$cr" -v cp="$cp" 'BEGIN {
		if (nr == "" || np == "" || cr == "" || cp == "") exit 0
		nr += 0; np += 0; cr += 0; cp += 0
		if (nr > cr) exit 0              # newer window
		if (nr == cr && np >= cp) exit 0 # same window, fresher (higher) reading
		exit 1                           # stale snapshot: keep what we have
	}'
}

# Only write when we actually have usage data, so a render without rate_limits
# (older clients, transient nulls) never clobbers a good cache.
if printf '%s' "$data" | grep -q 'PCT=[0-9]' && should_write; then
	mkdir -p "$CACHE_DIR"
	{
		printf '%s\n' "$data"
		printf 'UPDATED_AT=%s\n' "$(date +%s)"
	} >"$CACHE_FILE.tmp.$$" 2>/dev/null && mv "$CACHE_FILE.tmp.$$" "$CACHE_FILE" 2>/dev/null
fi

# Silent harvester: print nothing.
exit 0
