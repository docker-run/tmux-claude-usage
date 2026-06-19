# tmux-claude-usage

Show your Claude subscription usage in your **tmux status bar** — a progress
bar, percent used, and a human reset time — so you never alt-tab to the browser
usage page again.

```
██████░░░░  64% used · resets in 3 hr 37 min
```

It reads the **official** usage data Claude Code already receives (no API calls,
no tokens, no rate limits), shows it **once** in your global status bar instead
of repeated in every pane, and updates live as you work.

![demo](https://github.com/docker-run/tmux-claude-usage/releases/download/media/demo.gif)

## How it works

Two small pieces:

1. **Harvester** — a Claude Code [status line](https://code.claude.com/docs/en/statusline)
   command. Claude passes it official session data (including `rate_limits`) on
   every render; it writes your usage to a cache file and **prints nothing**, so
   nothing shows inside the Claude pane.
2. **Segment** — a tiny script your tmux status line calls. It reads that cache
   file and renders the bar. Pure bash, no network.

Because the data comes from Claude Code itself, it's free and accurate, and it
refreshes whenever Claude renders — i.e. continuously while you're working.

## Requirements

- `tmux` 3.0+
- `jq` (used by the harvester to parse Claude's JSON)
- Claude Code (logged in)

## Install

### 1. Add the plugin (via [TPM](https://github.com/tmux-plugins/tpm))

```tmux
set -g @plugin 'docker-run/tmux-claude-usage'
```

Press `prefix + I` to fetch it.

### 2. Place the segment in your status line

```tmux
set -g status-right '#{claude_usage}  %Y-%m-%d %H:%M'
```

### 3. Wire up the harvester (one command)

```sh
~/.tmux/plugins/tmux-claude-usage/scripts/init.sh
```

This adds the status line command to `~/.claude/settings.json` (backing it up
first). That's it — use Claude Code normally and the bar fills in.

> Already have a Claude Code status line? `init.sh` won't overwrite it; re-run
> with `--force` to replace it, or `--uninstall` to remove ours later.

## Configuration

Everything is optional with sensible defaults. By default the segment is
**unstyled** (inherits your theme) and shows the 5-hour session window.

```tmux
# Colors (opt-in), by usage threshold
set -g @claude_usage_color_normal   '#7aa2f7'
set -g @claude_usage_color_warning  '#e0af68'
set -g @claude_usage_color_critical '#f7768e'
```

| Option | Default | Description |
| --- | --- | --- |
| `@claude_usage_show` | `session` | `session`, `weekly`, or `all` |
| `@claude_usage_show_bar` | `on` | Show the progress bar |
| `@claude_usage_bar_width` | `10` | Bar width in cells |
| `@claude_usage_bar_full` | `█` | Filled bar character |
| `@claude_usage_bar_empty` | `░` | Empty bar character |
| `@claude_usage_show_reset` | `on` | Show "resets in …" |
| `@claude_usage_show_label` | `off` | Prefix "Session"/"Week" (auto-on for `all`) |
| `@claude_usage_session_label` | `Session` | Label for the 5-hour window |
| `@claude_usage_weekly_label` | `Week` | Label for the 7-day window |
| `@claude_usage_prefix` | _(empty)_ | Text/icon before the segment |
| `@claude_usage_separator` | `  ` | Between windows in `all` mode |
| `@claude_usage_warning_threshold` | `70` | % at which `warning` color applies |
| `@claude_usage_critical_threshold` | `90` | % at which `critical` color applies |
| `@claude_usage_color_normal` | _(none)_ | Color below the warning threshold |
| `@claude_usage_color_warning` | _(none)_ | Color at/above warning threshold |
| `@claude_usage_color_critical` | _(none)_ | Color at/above critical threshold |

### Update frequency

The bar repaints every `status-interval` seconds (standard tmux setting; default
15). Lower it for a snappier bar — it just re-reads a local file, so it's free:

```tmux
set -g status-interval 5
```

The underlying numbers refresh whenever Claude Code renders its status line,
which is constant while you're actively working — exactly when usage changes.

## Notes

- The bar is empty until Claude Code renders at least once in a session, and the
  value goes stale if Claude isn't running — but then your usage isn't changing.
- The harvester only reads Claude's data and writes a local file; nothing is sent
  anywhere.

## License

MIT — see [LICENSE](LICENSE).
