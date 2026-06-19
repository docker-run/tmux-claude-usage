#!/usr/bin/env bash
#
# TPM entry point. Replaces the `#{claude_usage}` placeholder in your
# status-left / status-right with a call to the usage script.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLACEHOLDER='#{claude_usage}'
SCRIPT_CALL="#($CURRENT_DIR/scripts/segment.sh)"

set_tmux_option() {
	tmux set-option -gq "$1" "$2"
}

get_tmux_option() {
	local value
	value="$(tmux show-option -gqv "$1")"
	printf '%s' "$value"
}

interpolate_option() {
	local option="$1" value
	value="$(get_tmux_option "$option")"
	set_tmux_option "$option" "${value//$PLACEHOLDER/$SCRIPT_CALL}"
}

main() {
	chmod +x "$CURRENT_DIR"/scripts/*.sh 2>/dev/null
	interpolate_option "status-right"
	interpolate_option "status-left"
}

main
