#!/usr/bin/env bash
# Shared helpers for the tmux segment. Sourced, not executed.

# Path to the cache file the statusLine harvester writes and the segment reads.
# Pinned under $HOME — not TMPDIR or XDG_CACHE_HOME — because the harvester runs
# in Claude Code's process and the segment runs in tmux's, and those two
# environments can differ. $HOME is the one variable they always agree on, so a
# fixed $HOME path guarantees both sides resolve the same file. Must match the
# path hardcoded in scripts/statusline.sh.
usage_cache_file() {
	printf '%s/.cache/claude-usage/usage' "$HOME"
}

# Read a tmux user option, falling back to a default when unset/empty.
get_tmux_option() {
	local option="$1" default="$2" value
	value="$(tmux show-option -gqv "$option" 2>/dev/null)"
	if [ -n "$value" ]; then
		printf '%s' "$value"
	else
		printf '%s' "$default"
	fi
}

# Render a text progress bar. Args: percent width full_char empty_char.
render_bar() {
	local pct="$1" width="$2" full="$3" empty="$4" filled i out=""
	filled=$(((pct * width + 50) / 100)) # rounded to nearest cell
	((filled < 0)) && filled=0
	((filled > width)) && filled=width
	for ((i = 0; i < filled; i++)); do out+="$full"; done
	for ((i = filled; i < width; i++)); do out+="$empty"; done
	printf '%s' "$out"
}

# Format seconds-until-reset as browser-style text: "4 hr 50 min", "2 days 3 hr".
human_reset() {
	local s="$1" d h m
	((s < 0)) && s=0
	d=$((s / 86400))
	h=$(((s % 86400) / 3600))
	m=$(((s % 3600) / 60))
	if ((d > 0)); then
		if ((h > 0)); then
			printf '%d day%s %d hr' "$d" "$([ "$d" -ne 1 ] && printf s)" "$h"
		else
			printf '%d day%s' "$d" "$([ "$d" -ne 1 ] && printf s)"
		fi
	elif ((h > 0)); then
		if ((m > 0)); then printf '%d hr %d min' "$h" "$m"; else printf '%d hr' "$h"; fi
	else
		printf '%d min' "$m"
	fi
}

# Pick a color for a usage percentage based on the configured thresholds.
# Prints empty string when the relevant color option is unset (theme-agnostic).
pick_color() {
	local pct="$1" warn crit
	warn="$(get_tmux_option @claude_usage_warning_threshold 70)"
	crit="$(get_tmux_option @claude_usage_critical_threshold 90)"
	if ((pct >= crit)); then
		get_tmux_option @claude_usage_color_critical '#f7768e'
	elif ((pct >= warn)); then
		get_tmux_option @claude_usage_color_warning '#e0af68'
	else
		get_tmux_option @claude_usage_color_normal ''
	fi
}
