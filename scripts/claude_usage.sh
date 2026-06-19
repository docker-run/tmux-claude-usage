#!/usr/bin/env bash
#
# tmux-claude-usage — print Claude subscription usage for the tmux status line.
#
# Design: the foreground call only ever reads a cache file and prints it, so the
# status line never blocks on the network. When the cache is stale a refresh is
# spawned in the background (guarded by a lock) to update it for the next redraw.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$DIR/helpers.sh"

CACHE_FILE="${TMPDIR:-/tmp}/tmux-claude-usage.cache"
LOCK_DIR="${TMPDIR:-/tmp}/tmux-claude-usage.lock"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
OAUTH_BETA="anthropic-beta: oauth-2025-04-20"

# Fetch raw usage JSON from the API using the resolved OAuth token.
fetch_usage() {
	local token
	token="$(resolve_token)" || return 1
	[ -n "$token" ] || return 1
	curl -sS --max-time 10 "$USAGE_URL" \
		--config <(printf 'header = "Authorization: Bearer %s"\n' "$token") \
		-H "$OAUTH_BETA"
}

# Turn raw usage JSON into the display string, applying tmux options.
render() {
	local json="$1"
	local show label_session label_weekly show_reset prefix
	local c_normal c_warning c_critical

	show="$(get_tmux_option @claude_usage_show session)" # session | weekly | all
	label_session="$(get_tmux_option @claude_usage_label_session '5h:')"
	label_weekly="$(get_tmux_option @claude_usage_label_weekly '7d:')"
	show_reset="$(get_tmux_option @claude_usage_show_reset on)"
	prefix="$(get_tmux_option @claude_usage_prefix '')"
	c_normal="$(get_tmux_option @claude_usage_color_normal '')"
	c_warning="$(get_tmux_option @claude_usage_color_warning '')"
	c_critical="$(get_tmux_option @claude_usage_color_critical '')"

	# Normalise to: kind <tab> percent <tab> severity <tab> resets_at.
	# Prefer the unified limits[] array; fall back to the window objects.
	local rows
	rows="$(printf '%s' "$json" | jq -r '
		def fromlimits:
			(.limits // [])
			| map(select(.is_active == true))
			| map([(.kind // .group // "session"), (.percent | tostring),
			       (.severity // "normal"), (.resets_at // "")]);
		def fromwindows:
			[ (if .five_hour != null then
			     ["session", ((.five_hour.utilization // 0) | floor | tostring),
			      "normal", (.five_hour.resets_at // "")] else empty end),
			  (if .seven_day != null then
			     ["weekly", ((.seven_day.utilization // 0) | floor | tostring),
			      "normal", (.seven_day.resets_at // "")] else empty end) ];
		(fromlimits) as $a
		| (if ($a | length) > 0 then $a else fromwindows end)
		| .[] | @tsv
	')" || return 1

	local segs=() now
	now="$(date -u +%s)"
	local kind percent severity resets_at
	while IFS=$'\t' read -r kind percent severity resets_at; do
		[ -z "$kind" ] && continue

		local label want=0
		case "$kind" in
		session | five_hour | 5h)
			label="$label_session"
			[ "$show" != "weekly" ] && want=1
			;;
		*)
			label="$label_weekly"
			[ "$show" != "session" ] && want=1
			;;
		esac
		[ "$want" -eq 1 ] || continue

		local seg="${label}${percent}%"
		if [ "$show_reset" = "on" ] && [ -n "$resets_at" ]; then
			seg="${seg} ($(human_duration $(($(to_epoch "$resets_at") - now))))"
		fi

		local color=""
		case "$severity" in
		normal) color="$c_normal" ;;
		warning | warn) color="$c_warning" ;;
		critical | crit) color="$c_critical" ;;
		esac
		[ -n "$color" ] && seg="#[fg=${color}]${seg}#[default]"

		segs+=("$seg")
	done <<<"$rows"

	((${#segs[@]})) || return 1
	local out="${segs[*]}"
	printf '%s%s' "$prefix" "$out"
}

# Fetch + render + atomically write the cache. Quiet on failure (keeps last good).
refresh() {
	local json out
	json="$(fetch_usage)" || return 1
	# Bail on API errors (e.g. rate limiting) or invalid bodies so we keep the
	# last good value instead of overwriting it with garbage.
	printf '%s' "$json" | jq -e 'has("error") | not' >/dev/null 2>&1 || return 1
	out="$(render "$json")" || return 1
	printf '%s' "$out" >"$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
}

cache_is_stale() {
	local ttl="$1"
	[ -f "$CACHE_FILE" ] || return 0
	(($(date +%s) - $(file_mtime "$CACHE_FILE") >= ttl))
}

main() {
	if [ "${1:-}" = "--refresh" ]; then
		refresh
		exit $?
	fi

	# On-demand refresh, throttled by cache_ttl so a low status-interval can't
	# hammer the API. Lock so concurrent redraws spawn a single refresh; detach
	# fds so tmux never waits on us.
	local ttl
	ttl="$(get_tmux_option @claude_usage_cache_ttl 60)"
	if cache_is_stale "$ttl"; then
		if mkdir "$LOCK_DIR" 2>/dev/null; then
			(
				trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
				refresh
			) </dev/null >/dev/null 2>&1 &
		fi
	fi

	[ -f "$CACHE_FILE" ] && cat "$CACHE_FILE"
}

main "$@"
