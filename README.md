# tmux-claude-usage

Show your Claude subscription usage — session/weekly percentage and time until
reset — directly in your tmux status line. No more flipping to the browser to
check how much you have left.

```
5h:30% (4h)          # default
[claude] 5h:30% (4h) 7d:62% (3d)   # session + weekly, with a prefix
```

It reads the same numbers the Claude usage page shows, caches them, and never
blocks your status line on the network.

## Requirements

- `tmux` 3.0+
- `curl` and `jq`
- A logged-in Claude Code install (the token is read from your local
  credentials — macOS Keychain or `~/.claude/.credentials.json`)

## Install

### With [TPM](https://github.com/tmux-plugins/tpm)

Add to `~/.tmux.conf` (or `~/.config/tmux/tmux.conf`):

```tmux
set -g @plugin 'docker-run/tmux-claude-usage'
```

Then put the placeholder wherever you want it in your status line:

```tmux
set -g status-right '#{claude_usage}  %Y-%m-%d %H:%M'
```

Hit `prefix + I` to fetch and you're done.

### Manual

```tmux
run-shell ~/clone/path/tmux-claude-usage/claude-usage.tmux
```

## Theming

By default the segment is **unstyled** — it inherits your status line's colors,
so it fits any theme out of the box. Opt into color by mapping the API's
severity levels to colors:

```tmux
set -g @claude_usage_color_normal   '#7aa2f7'
set -g @claude_usage_color_warning  '#e0af68'
set -g @claude_usage_color_critical '#f7768e'
```

## Options

| Option | Default | Description |
| --- | --- | --- |
| `@claude_usage_show` | `session` | `session`, `weekly`, or `all` |
| `@claude_usage_show_reset` | `on` | Append time-until-reset, e.g. `(4h)` |
| `@claude_usage_cache_ttl` | `120` | Seconds between API refreshes |
| `@claude_usage_label_session` | `5h:` | Label for the 5-hour window |
| `@claude_usage_label_weekly` | `7d:` | Label for the 7-day window |
| `@claude_usage_prefix` | _(empty)_ | Text/icon before the segment |
| `@claude_usage_color_normal` | _(none)_ | Color when severity is `normal` |
| `@claude_usage_color_warning` | _(none)_ | Color when severity is `warning` |
| `@claude_usage_color_critical` | _(none)_ | Color when severity is `critical` |
| `@claude_usage_token_command` | _(auto)_ | Shell command that prints the OAuth token, if you store it elsewhere |

## How it works

The status line calls a script that only reads a small cache file and prints it,
so redraws are instant. When the cache is older than `@claude_usage_cache_ttl`,
a single background refresh is spawned (lock-guarded) to update it for the next
redraw. The refresh resolves your Claude Code OAuth token, requests usage from
`api.anthropic.com`, and renders the segment. On any failure the last good value
is kept.

## Notes

This uses an undocumented usage endpoint and may break if it changes. It only
ever reads your usage; it does not transmit anything anywhere except the
authenticated request to Anthropic.

## License

MIT — see [LICENSE](LICENSE).
