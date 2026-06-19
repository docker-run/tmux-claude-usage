# Reproducible demo for tmux-claude-usage.
# Regenerate from the repo root with:  vhs assets/demo.tape
# Requires: vhs, tmux. Uses an isolated cache + tmux server; touches nothing real.

Output assets/demo.gif

Require tmux

Set Shell bash
Set FontSize 22
Set Width 1200
Set Height 170
Set Padding 16
Set Theme "TokyoNight"

Hide
Type 'export XDG_CACHE_HOME=$(mktemp -d); L=cu-demo; S=$PWD/scripts/segment.sh' Enter
Type 'bash assets/demo/seed.sh 32' Enter
Type 'tmux -L $L new-session -d "bash --norc"' Enter
Type 'tmux -L $L send-keys "clear" Enter' Enter
Type 'tmux -L $L set -g status-style "fg=#7aa2f7,bg=#1f2335"' Enter
Type 'tmux -L $L set -g status-left "#[fg=#1d202f,bg=#7aa2f7,bold] claude #[fg=#7aa2f7,bg=#1f2335] "' Enter
Type 'tmux -L $L set -g status-right "#($S) #[fg=#7aa2f7,bg=#1f2335]"' Enter
Type 'tmux -L $L set -g @claude_usage_color_normal "#7aa2f7"' Enter
Type 'tmux -L $L set -g @claude_usage_color_warning "#e0af68"' Enter
Type 'tmux -L $L set -g @claude_usage_color_critical "#f7768e"' Enter
Type 'tmux -L $L set -g status-interval 1' Enter
Type '( sleep 3; bash assets/demo/seed.sh 73; sleep 3; bash assets/demo/seed.sh 95 ) &' Enter
Type 'clear; tmux -L $L attach' Enter
Sleep 1s
Show
Sleep 8s
