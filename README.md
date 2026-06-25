![demo](https://github.com/docker-run/tmux-claude-usage/releases/download/media/demo.gif)

[![Download](https://img.shields.io/badge/Download-v1.0.0-2ea44f)](https://github.com/docker-run/tmux-claude-usage/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build](https://github.com/docker-run/tmux-claude-usage/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/docker-run/tmux-claude-usage/actions/workflows/shellcheck.yml)

Your Claude usage — progress bar, percent, and reset time — right in the tmux status bar. It uses the official usage data Claude Code already receives — no API calls, no tokens, no rate limits — and updates live as you work.

## Contents

- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Update frequency](#update-frequency)
- [Contribution](#contribution)
- [License](#license)

## How it works

Two small pieces:

1. **Harvester** — a Claude Code [status line](https://code.claude.com/docs/en/statusline)
   command. Claude hands it official session data (including `rate_limits`) on
   every render; it writes your usage to a cache file and **prints nothing**, so
   no line appears inside the pane.
2. **Segment** — a tiny script your tmux status line calls. It reads that cache
   and renders the bar. Pure bash, no network.

Because the data comes from Claude itself, it's free and accurate, and refreshes
whenever Claude renders — continuously while you work.

## Requirements

- `tmux` 3.0+
- `jq`
- Claude Code, signed in with a **Claude Pro or Max** subscription. The usage
  data (`rate_limits`) is sent only to Pro/Max sessions.

## Installation

**1. Add the plugin** via [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'docker-run/tmux-claude-usage'
```

**2. Place the segment** in your status line:

```tmux
set -g status-right '#{claude_usage}  %Y-%m-%d %H:%M'
```

**3. Fetch and wire it up** — press `prefix + I` (TPM clones the plugin), then
run the installer once. It resolves the plugin's path itself — wherever TPM put
it, default or a custom `TMUX_PLUGIN_MANAGER_PATH` — so this one line works on
every setup (run it from inside tmux, right after `prefix + I`):

```sh
bash "$(tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH | cut -d= -f2-)tmux-claude-usage/scripts/init.sh"
```

`init.sh` adds the status line command to Claude Code's `settings.json` (under
`~/.claude`, or `$CLAUDE_CONFIG_DIR` if you've set one), backing it up first.
Use Claude Code normally and the bar fills in.

> Already have a Claude status line? `init.sh` keeps it: it chains your line and
> the harvester through the single slot, so both run and your line still shows.
> Use `--force` to install only the harvester instead, or `--uninstall` to
> restore your original line.

### Without TPM

Clone it anywhere and source the entry point from your `tmux.conf`:

```sh
git clone https://github.com/docker-run/tmux-claude-usage \
  ~/.tmux/plugins/tmux-claude-usage
```

```tmux
run-shell ~/.tmux/plugins/tmux-claude-usage/claude-usage.tmux
```

Then place `#{claude_usage}` in your status line (step 2) and run that clone's
`scripts/init.sh` (step 3).

## Configuration

Out of the box the segment shows the 5-hour
session window, inherits your theme's color normally, and turns **amber** then
**red** as you approach your limit. Every option below is optional — for
example, override the colors to match your theme (hex or palette names both work).

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
| `@claude_usage_stale_after` | _(off)_ | Seconds; flag the bar stale once the cache is older than this |
| `@claude_usage_stale_label` | `stale` | Word used in the stale marker |
| `@claude_usage_warning_threshold` | `70` | % for the `warning` color |
| `@claude_usage_critical_threshold` | `90` | % for the `critical` color |
| `@claude_usage_color_normal` | _(theme)_ | Color below the warning threshold |
| `@claude_usage_color_warning` | `yellow` | Color at/above warning |
| `@claude_usage_color_critical` | `red` | Color at/above critical |

### Match the demo

The powerline look in the demo above is a full Tokyo Night Storm status-bar
theme, **not** part of the plugin — the plugin only contributes the
`#{claude_usage}` segment. To reproduce that exact look, source the example
theme:

```tmux
source-file ~/.tmux/plugins/tmux-claude-usage/examples/tokyo-night-storm.conf
```

It styles your **whole** status bar (left, right, windows) and uses
[`tmux-prefix-highlight`](https://github.com/tmux-plugins/tmux-prefix-highlight)
for the `prefix` indicator — drop the `#{prefix_highlight}` token from the file
if you don't use that plugin.

## Update frequency

The bar repaints every `status-interval` seconds (standard tmux setting, default
15). Lower it for a snappier bar — it just re-reads a local file, so it's free:

```tmux
set -g status-interval 5
```

Repainting isn't the same as refreshing, though: the underlying numbers only
update when **Claude Code** renders and hands the harvester fresh data. Usage you
rack up elsewhere — the browser, another machine — won't appear until a local
Claude Code session renders again, so a number can sit unchanged while the real
figure climbs. There's no token-free way to fetch it on demand. To avoid mistaking
a stale figure for a live one, set `@claude_usage_stale_after` and the bar appends
e.g. `(stale 2 hr)` once the cache passes that age:

```tmux
set -g @claude_usage_stale_after 1800  # mark stale after 30 min
```

## Contribution

See the [CONTRIBUTION.md](CONTRIBUTION.md) file.

## License

[MIT](LICENSE)
