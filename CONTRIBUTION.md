# Contribution

Issues and pull requests are welcome.

## Development

- Shell scripts are linted with [ShellCheck](https://www.shellcheck.net/); CI
  runs it on every push and pull request. Run it locally before opening a PR:

  ```sh
  shellcheck scripts/*.sh claude-usage.tmux
  ```

- Keep the tmux segment dependency-free (pure bash). Only the harvester
  (`scripts/statusline.sh`) uses `jq`.

## Regenerating the demo

The README GIF is produced with [vhs](https://github.com/charmbracelet/vhs):

```sh
vhs assets/demo.tape
```

The generated `assets/demo.gif` is published in the `media` release rather than
committed, so installs stay lean.
