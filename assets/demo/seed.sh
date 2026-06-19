#!/usr/bin/env bash
# Seed an isolated demo usage cache for assets/demo.tape. Arg: percent used.
# The reset timestamp is fixed on the first call and preserved afterwards, so
# the "resets in …" countdown only ticks down as the demo plays — it never
# wobbles when later calls bump the percent.
set -euo pipefail
dir="${XDG_CACHE_HOME:?set XDG_CACHE_HOME first}/claude-usage"
mkdir -p "$dir"
reset=""
[ -f "$dir/usage" ] && reset="$(sed -n 's/^FIVE_HOUR_RESET=//p' "$dir/usage")"
[ -n "$reset" ] || reset="$(($(date +%s) + 13440))"
printf 'FIVE_HOUR_PCT=%s\nFIVE_HOUR_RESET=%s\n' "$1" "$reset" >"$dir/usage"
