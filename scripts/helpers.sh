#!/usr/bin/env bash
# Shared helpers for tmux-claude-usage.
# Sourced by claude_usage.sh — not meant to be run directly.

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

# Resolve the Claude Code OAuth access token.
# Order: user-supplied command -> macOS Keychain -> credentials file.
# Prints the token on stdout, or returns non-zero if none found.
resolve_token() {
	local override json token

	override="$(get_tmux_option @claude_usage_token_command "")"
	if [ -n "$override" ]; then
		eval "$override"
		return $?
	fi

	if command -v security >/dev/null 2>&1; then
		json="$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null || true)"
		if [ -n "$json" ]; then
			token="$(printf '%s' "$json" | jq -r '.claudeAiOauth.accessToken // empty')"
			[ -n "$token" ] && { printf '%s' "$token"; return 0; }
		fi
	fi

	if [ -f "$HOME/.claude/.credentials.json" ]; then
		token="$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json")"
		[ -n "$token" ] && { printf '%s' "$token"; return 0; }
	fi

	return 1
}

# Convert an ISO-8601 timestamp (assumed UTC) to a Unix epoch.
# Handles both GNU date and BSD/macOS date.
to_epoch() {
	local iso="$1" trimmed
	if date -d "$iso" +%s >/dev/null 2>&1; then
		date -d "$iso" +%s # GNU
		return
	fi
	# BSD: strip fractional seconds and timezone offset, parse as UTC.
	trimmed="${iso%%.*}"
	trimmed="${trimmed%%+*}"
	trimmed="${trimmed%Z}"
	TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$trimmed" +%s 2>/dev/null
}

# Format a duration in seconds as a compact human string: 2d / 3h / 45m.
human_duration() {
	local s="$1"
	((s < 0)) && s=0
	if ((s >= 86400)); then
		printf '%dd' $((s / 86400))
	elif ((s >= 3600)); then
		printf '%dh' $((s / 3600))
	else
		printf '%dm' $(((s + 59) / 60))
	fi
}

# Epoch mtime of a file, GNU/BSD agnostic. Prints 0 if it cannot be read.
file_mtime() {
	stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}
