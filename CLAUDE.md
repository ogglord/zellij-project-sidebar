# Claude Code Context

## Building

Use the Nix devShell to compile. The flake provides rustup, stdenv.cc, lld, and pkg-config. The shellHook ensures the wasm32-wasip1 target is installed.

```bash
# Enter the devShell
nix develop

# Build the plugin (WASM target)
cargo build --release --target wasm32-wasip1

# Build the init binary (native target)
cargo build --release --bin zellij-sidebar-init

# Build both at once
cargo build --release --target wasm32-wasip1 --bin zellij-sidebar-init
```

The plugin binary: `target/wasm32-wasip1/release/zellij-project-sidebar.wasm`
The init binary: `target/release/zellij-sidebar-init`

## Project Structure

- `src/main.rs` — Zellij plugin (WASM)
- `src/bin/init.rs` — `zellij-sidebar-init` CLI binary
- `scripts/` — Shell hook scripts for Claude Code and OpenCode
- `nix/module.nix` — NixOS/Home Manager module
- `ARCHITECTURE.md` — Filesystem bridge and environment variable documentation

## Filesystem Bridge

The plugin runs in a WASI sandbox. The host maps `$TMPDIR/zellij-<uid>/` to the plugin's `/tmp/`.

- **AI state**: `sidebar-ai/<session>/<pane_id>` → `state timestamp [duration]`
- **Shell state**: `sidebar-shell/<session>/<pane_id>` → `command timestamp`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SIDEBAR_STALE_TIMEOUT` | `3600` | Seconds before stale state is ignored (AI + shell) |

## Key Decisions

- Shell hooks chain with existing `preexec`/`precmd` (zsh: `preexec_functions`, bash: `PROMPT_COMMAND` + `DEBUG` trap)
- NixOS wrapper names are stripped (`__nvim-wrapped` → `nvim`)
- Up to 5 shell commands shown per session, deduplicated, most recent first
- Detail line priority: AI state → shell commands → Zellij active_command → tab count
- Stale timeout is shared between AI and shell state via env var
