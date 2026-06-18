# Architecture

## Filesystem Bridge

The sidebar plugin runs inside a Zellij **WASI sandbox**. The host maps a directory into the sandbox so the plugin can read files written by shell/AI hooks that run on the host.

- **Host side**: `$TMPDIR/zellij-<uid>/` (e.g. `/tmp/zellij-1000/`)
- **Plugin side**: `/tmp/` (mapped by Zellij WASI)

The plugin reads two shared directories under this mount:

| Directory | Format | Purpose |
|-----------|--------|---------|
| `sidebar-ai/<session>/<pane_id>` | `state timestamp [duration]` | AI agent activity (Claude, OpenCode) |
| `sidebar-shell/<session>/<pane_id>` | `command timestamp` | Foreground shell commands (nvim, lazygit, etc.) |

Each sidebar instance reads these files on a ~10-second timer. Multiple instances read them concurrently — they never delete shared files (eviction is in-memory only). The hooks own file lifecycle.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SIDEBAR_STALE_TIMEOUT` | `3600` (seconds = 60 min) | How long a state file can persist without a heartbeat before the plugin ignores it. Applies to both AI and shell state. |

The `zellij-ssidebar` hook generator reads this variable and bakes it into the emitted shell code so the hooks themselves know the timeout (e.g. for stale cleanup). The plugin also reads it at runtime.

## Stale State Model

Both AI and shell hooks share the same stale timeout:

- A file older than `SIDEBAR_STALE_TIMEOUT` seconds is ignored (crashed/killed process, missed cleanup).
- A session no longer present in Zellij has its in-memory state evicted immediately.
- The hook itself removes the file on clean exit (`precmd` for shell, `SessionEnd` for AI), so stale files are the exception.

## Command Name Sanitization

Shell hooks write the basename of the current command. NixOS wrapper scripts are stripped:
- `__nvim-wrapped` → `nvim`
- `__lazygit-wrapped` → `lazygit`

## Hook Chaining

The `zellij-ssidebar` binary generates hook code that **chains** with existing `preexec`/`precmd` hooks:
- **zsh**: appends to `preexec_functions` and `precmd_functions` arrays
- **bash**: chains via `PROMPT_COMMAND` / `DEBUG` trap

This is the `eval "$(mytool init bash)"` pattern used by direnv, starship, zoxide, mise, and atuin.
