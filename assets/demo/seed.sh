#!/usr/bin/env bash
# Seed an isolated demo usage cache for assets/demo.tape. Arg: percent used.
set -euo pipefail
dir="${XDG_CACHE_HOME:?set XDG_CACHE_HOME first}/claude-usage"
mkdir -p "$dir"
printf 'FIVE_HOUR_PCT=%s\nFIVE_HOUR_RESET=%s\n' "$1" "$(($(date +%s) + 13440))" >"$dir/usage"
