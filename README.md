![demo](https://github.com/docker-run/tmux-claude-usage/releases/download/media/demo.gif)

[![Download](https://img.shields.io/badge/Download-v1.0.0-2ea44f)](https://github.com/docker-run/tmux-claude-usage/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build](https://github.com/docker-run/tmux-claude-usage/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/docker-run/tmux-claude-usage/actions/workflows/shellcheck.yml)

Your Claude usage — progress bar, percent, and reset time — right in the tmux status bar.

## Contents

- [Overview](#overview)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Update frequency](#update-frequency)
- [Contribution](#contribution)
- [License](#license)

## Overview

Stop alt-tabbing to the browser usage page. This plugin shows your Claude
subscription usage — a progress bar, `% used`, and a human reset time — in your
tmux status bar, **once**, globally:

```
██████░░░░  64% used · resets in 3 hr 37 min
```

It uses the **official** usage data Claude Code already receives — no API calls,
no tokens, no rate limits — and updates live as you work.

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
- Claude Code (logged in)

## Installation

**1. Add the plugin** via [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'docker-run/tmux-claude-usage'
```

**2. Place the segment** in your status line:

```tmux
set -g status-right '#{claude_usage}  %Y-%m-%d %H:%M'
```

**3. Fetch and wire it up** — press `prefix + I`, then run once:

```sh
~/.tmux/plugins/tmux-claude-usage/scripts/init.sh
```

`init.sh` adds the status line command to `~/.claude/settings.json` (backing it
up first). Use Claude Code normally and the bar fills in.

> Already have a Claude status line? `init.sh` won't overwrite it — re-run with
> `--force` to replace, or `--uninstall` to remove ours.

## Configuration

No configuration is required. By default the segment is **unstyled** (inherits
your theme) and shows the 5-hour session window. Opt into color by usage
threshold:

```tmux
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
| `@claude_usage_warning_threshold` | `70` | % for the `warning` color |
| `@claude_usage_critical_threshold` | `90` | % for the `critical` color |
| `@claude_usage_color_normal` | _(none)_ | Color below the warning threshold |
| `@claude_usage_color_warning` | _(none)_ | Color at/above warning |
| `@claude_usage_color_critical` | _(none)_ | Color at/above critical |

## Update frequency

The bar repaints every `status-interval` seconds (standard tmux setting, default
15). Lower it for a snappier bar — it just re-reads a local file, so it's free:

```tmux
set -g status-interval 5
```

The numbers themselves refresh whenever Claude Code renders — constant while
you're actively working, idle when it isn't (which is when usage isn't changing).

## Contribution

See the [CONTRIBUTION.md](CONTRIBUTION.md) file.

## License

[MIT](LICENSE)
