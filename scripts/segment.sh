#!/usr/bin/env bash
#
# tmux segment — reads the harvested usage cache and renders the status bar
# text: a progress bar, "NN% used", and a human reset time. Pure bash, no
# network, no jq; runs on every status-line redraw.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$DIR/helpers.sh"

CACHE_FILE="$(usage_cache_file)"
[ -f "$CACHE_FILE" ] || exit 0

# Load the harvested values without sourcing (no code execution from the file).
five_pct="" five_reset="" seven_pct="" seven_reset="" updated_at=""
while IFS='=' read -r key val; do
	case "$key" in
	FIVE_HOUR_PCT) five_pct="$val" ;;
	FIVE_HOUR_RESET) five_reset="$val" ;;
	SEVEN_DAY_PCT) seven_pct="$val" ;;
	SEVEN_DAY_RESET) seven_reset="$val" ;;
	UPDATED_AT) updated_at="$val" ;;
	esac
done <"$CACHE_FILE"

# Options
show="$(get_tmux_option @claude_usage_show session)"          # session | weekly | all
bar_width="$(get_tmux_option @claude_usage_bar_width 10)"
bar_full="$(get_tmux_option @claude_usage_bar_full '█')"
bar_empty="$(get_tmux_option @claude_usage_bar_empty '░')"
show_bar="$(get_tmux_option @claude_usage_show_bar on)"
show_reset="$(get_tmux_option @claude_usage_show_reset on)"
show_label="$(get_tmux_option @claude_usage_show_label off)"
session_label="$(get_tmux_option @claude_usage_session_label 'Session')"
weekly_label="$(get_tmux_option @claude_usage_weekly_label 'Week')"
prefix="$(get_tmux_option @claude_usage_prefix '')"
separator="$(get_tmux_option @claude_usage_separator '  ')"
stale_after="$(get_tmux_option @claude_usage_stale_after '')"
stale_label="$(get_tmux_option @claude_usage_stale_label 'stale')"

now="$(date +%s)"

# Build one window's text. Args: percent reset_epoch label.
window_segment() {
	local pct_raw="$1" reset_epoch="$2" label="$3"
	[ -n "$pct_raw" ] || return 1

	local pct
	printf -v pct '%.0f' "$pct_raw" 2>/dev/null || return 1

	# Only trust reset_epoch if it's a plain epoch integer (guards against a
	# future payload handing us an ISO string, which would break the maths).
	local have_reset=0
	[[ "$reset_epoch" =~ ^[0-9]+$ ]] && have_reset=1

	# Self-expiring cache: once the window's reset time has passed, it has
	# provably rolled over to a fresh window. The harvester only refreshes while
	# Claude renders, so an idle cache would otherwise show stale numbers — but
	# we know the truth locally: usage is back to 0% and there's no active
	# window to count down to. No probing or timer needed.
	if [ "$have_reset" = 1 ] && [ "$now" -ge "$reset_epoch" ]; then
		pct=0
		have_reset=0
	fi

	local parts=()
	{ [ "$show_label" = on ] || [ "$show" = all ]; } && [ -n "$label" ] && parts+=("$label")
	[ "$show_bar" = on ] && parts+=("$(render_bar "$pct" "$bar_width" "$bar_full" "$bar_empty")")
	parts+=("${pct}% used")
	if [ "$show_reset" = on ] && [ "$have_reset" = 1 ]; then
		parts+=("· resets in $(human_reset $((reset_epoch - now)))")
	fi

	local text="${parts[*]}" color
	color="$(pick_color "$pct")"
	if [ -n "$color" ]; then
		printf '#[fg=%s]%s#[default]' "$color" "$text"
	else
		printf '%s' "$text"
	fi
}

segments=()
case "$show" in
weekly)
	s="$(window_segment "$seven_pct" "$seven_reset" "$weekly_label")" && segments+=("$s")
	;;
all)
	s="$(window_segment "$five_pct" "$five_reset" "$session_label")" && segments+=("$s")
	s="$(window_segment "$seven_pct" "$seven_reset" "$weekly_label")" && segments+=("$s")
	;;
*)
	s="$(window_segment "$five_pct" "$five_reset" "$session_label")" && segments+=("$s")
	;;
esac

((${#segments[@]})) || exit 0

out=""
for i in "${!segments[@]}"; do
	((i > 0)) && out+="$separator"
	out+="${segments[$i]}"
done

# Staleness marker. The numbers only refresh while Claude Code renders; usage
# incurred elsewhere (browser, another machine) won't show up until then. When
# the cache is older than @claude_usage_stale_after seconds, flag it so the
# figure isn't mistaken for live. Off unless the option is set to a positive
# integer.
if [[ "$stale_after" =~ ^[0-9]+$ ]] && [ "$stale_after" -gt 0 ] &&
	[[ "$updated_at" =~ ^[0-9]+$ ]] && [ $((now - updated_at)) -ge "$stale_after" ]; then
	out+=" ($stale_label $(human_reset $((now - updated_at))))"
fi

printf '%s%s' "$prefix" "$out"
