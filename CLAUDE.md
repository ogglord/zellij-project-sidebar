# Claude Code Context

## Project Structure

- `src/main.rs` — Zellij plugin (WASM target). Handles rendering, keyboard/mouse input, session management, and reads shared state files.
- `src/init/src/main.rs` — `zellij-ssidebar` CLI binary (native target). Generates shell hook code for zsh/bash.
- `scripts/` — Shell hook scripts for Claude Code (`sidebar-status.sh`) and OpenCode (`opencode-sidebar.sh`, `opencode-sidebar.ts`).
- `nix/module.nix` — NixOS/Home Manager module. Injects `eval "$(zellij-ssidebar hook ...)"` into shell configs.
- `ARCHITECTURE.md` — Filesystem bridge and environment variable documentation.
- `flake.nix` — Nix flake providing devShell (rustup + wasm target) and package build.

## Code Standards

- **Minimal changes**: make the smallest possible change to achieve the goal.
- **No premature abstraction**: duplicate code is acceptable if it keeps the change local and obvious.
- **Follow existing patterns**: when adding new features, mirror the existing AI state loader (`load_ai_states`) structure.
- **WASI constraints**: the plugin cannot access host filesystem directly; it only sees the mapped `/tmp/` directory.
- **Non-destructive reads**: plugin instances never delete shared state files (hooks own lifecycle). Eviction is in-memory only.
- **Chaining hooks**: shell hooks must chain with existing `preexec`/`precmd` (zsh: `preexec_functions+=`, bash: `PROMPT_COMMAND` + `DEBUG` trap).
- **NixOS wrapper stripping**: strip `__` prefix and `-wrapped` suffix from command names in shell hooks.

## How to Compile

Use the Nix devShell to compile. The flake provides rustup, stdenv.cc, lld, and pkg-config. The shellHook ensures the wasm32-wasip1 target is installed.

```bash
# Enter the devShell
nix develop

# Build the plugin (WASM target)
cargo build --release --target wasm32-wasip1

# Build the init binary (native target)
cargo build --release --manifest-path src/init/Cargo.toml

# Build both at once
cargo build --release --target wasm32-wasip1
```

The plugin binary: `target/wasm32-wasip1/release/zellij-ssidebar.wasm`
The init binary: `src/init/target/release/zellij-ssidebar`

## How to Deploy

1. **Commit and push to GitHub**:
   ```bash
   git add -A
   git commit -m "<message>"
   git push
   ```

2. **Deploy to your NixOS system**:
   ```bash
   homelab deploy
   ```

This updates the NixOS configuration with the latest plugin binary and init binary, then rebuilds the system.

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
