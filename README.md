# zellij-ssidebar

A persistent sidebar plugin for [Zellij](https://zellij.dev) that shows your active project sessions at a glance. Click or keyboard-navigate to switch between projects, start new sessions, and see real-time AI agent and shell activity across all sessions.

![screenshot](screenshot.png)

## Quick start

Give this prompt to Claude Code (or your AI coding tool of choice) and it will handle everything:

> Install the zellij-ssidebar plugin from https://github.com/AndrewBeniston/zellij-ssidebar. Clone the repo, build with `cargo build --target wasm32-wasip1 --release`, copy the .wasm to `~/.config/zellij/plugins/`. Then update my Zellij layout to include the sidebar with `scan_dir` pointing to my projects directory. Set up Claude Code hooks using the sidebar-status.sh script from the repo so the sidebar shows real-time AI activity indicators across all sessions (see the "AI activity indicators" section in the README for full setup). Also configure the attention system hooks for `sidebar::attention::` and `sidebar::clear::` pipe messages. Set up shell activity tracking with `zellij-ssidebar` so the sidebar shows foreground commands like `nvim` and `lazygit` in the detail line.

## Why?

Zellij has great session management, but no ambient awareness. You can't see at a glance which projects are running, which session you're in, or which one has Claude Code actively working. This plugin gives you a docked sidebar that stays visible across tabs — an agentic AI dashboard for your terminal. Think VS Code's sidebar, but for terminal sessions with real-time AI and shell visibility.

## Features

- **AI activity at a glance**: see which sessions have Claude Code (or any AI tool) actively working, idle, or needing input — across all sessions, not just the current one
- **Shell activity tracking**: see foreground commands (`nvim`, `lazygit`, `cargo build`) running in any session via shell hooks
- **Duration tracking**: shows how long Claude has been working (live timer), and how long the last turn took when idle; shell commands also show duration
- **Active sessions at a glance**: only shows projects with running or exited sessions, no clutter
- **Current session highlighted**: green text shows you exactly where you are
- **Browse mode**: press `/` to search all discovered projects and start new sessions
- **Attention indicators**: a magenta `!` appears when a session needs your input
- **Session lifecycle**: create, switch to, or kill sessions from the sidebar
- **Auto-discovery**: scans a directory for projects instead of manual configuration
- **New tab with sidebar**: `Cmd+T` creates tabs that include the sidebar
- **Mouse support**: click a project to switch, scroll wheel to navigate
- **Toggle visibility**: `Cmd+O` to focus/unfocus the sidebar
- **Fuzzy search**: subsequence matching in browse mode

## Install

### Build from source

```bash
git clone https://github.com/AndrewBeniston/zellij-ssidebar.git
cd zellij-ssidebar
cargo build --release --target wasm32-wasip1
cp target/wasm32-wasip1/release/zellij-ssidebar.wasm ~/.config/zellij/plugins/
```

> Requires Rust with the `wasm32-wasip1` target: `rustup target add wasm32-wasip1`

### Build the init binary

The shell activity hook requires the `zellij-ssidebar` binary:

```bash
cargo build --release --manifest-path src/init/Cargo.toml
cp src/init/target/release/zellij-ssidebar ~/.local/bin/
```

## Configuration

Add the plugin to your Zellij layout (e.g. `~/.config/zellij/layouts/default.kdl`):

### Discovery mode (recommended)

Automatically discovers projects from a directory:

```kdl
layout {
    pane size=1 borderless=true {
        plugin location="tab-bar"
    }
    pane split_direction="vertical" {
        pane size="15%" name="Projects" {
            plugin location="file:~/.config/zellij/plugins/zellij-ssidebar.wasm" {
                scan_dir "/Users/you/Projects"
                session_layout "/Users/you/.config/zellij/layouts/default.kdl"
            }
        }
        pane
    }
}
```

| Option | Description |
|--------|-------------|
| `scan_dir` | Directory to scan for project folders |
| `session_layout` | Layout file applied when creating new sessions |
| `verbosity` | `"full"` (default) or `"minimal"` to control tab count and command display |

### Legacy mode

Manually list projects:

```kdl
plugin location="file:~/.config/zellij/plugins/zellij-ssidebar.wasm" {
    project_0 "/Users/you/Projects/my-app"
    project_1 "/Users/you/Projects/api-server"
    project_2 "/Users/you/Projects/docs"
}
```

## Keybindings

### When sidebar is focused

| Key | Action |
|-----|--------|
| `Up` / `Down` | Navigate projects |
| `Enter` | Switch to session (or create if not started) |
| `Delete` | Kill selected session |
| `/` | Enter browse mode (search all projects) |
| `Esc` | Deactivate sidebar |
| `Alt+R` | Rescan project directory |
| Click | Switch to clicked project |
| Scroll | Navigate projects |

### Browse mode

| Key | Action |
|-----|--------|
| Type | Fuzzy search projects |
| `Enter` | Open selected project |
| `Backspace` | Delete search character |
| `Esc` | Exit browse mode |

### Global (registered by plugin)

| Key | Action |
|-----|--------|
| `Cmd+O` / `Super+O` | Toggle sidebar focus |
| `Cmd+T` / `Super+T` | New tab with sidebar |

> `Cmd` keys require a terminal that passes them through (e.g. Ghostty with `keybind = cmd+o=unbind`).

## Session status indicators

| Symbol | Colour | Meaning |
|--------|--------|---------|
| `▶` | Green | AI agent is actively working |
| `■` | Cyan | AI agent is idle (done/waiting) |
| `!` | Magenta | Needs attention |
| `·` | Orange | Running session, no AI |
| `·` | Orange | Exited (resurrectable) session |
| `·` | Cyan | Not started |

The current session's name is highlighted in green. Sessions with AI activity show a detail line with "claude" and duration info (e.g. `claude · 30s` while working, `claude · took 2m` when done). Sessions with shell activity show commands like `nvim · 5m` or `lazygit · 10m`.

## Attention system

The sidebar shows a magenta `!` indicator when a session needs your attention. This is powered by Zellij's pipe messaging:

```bash
# Flag a session as needing attention
zellij pipe --name "sidebar::attention::session-name"

# Clear attention for a session
zellij pipe --name "sidebar::clear::session-name"
```

Attention is automatically cleared when you switch to a session via the sidebar.

## Shell activity tracking

The sidebar can show foreground commands running in any session — `nvim`, `lazygit`, `cargo build`, etc. This is powered by a shell hook that writes to a shared filesystem, just like the AI hooks.

### How it works

Shell command state is shared via per-pane files under `$TMPDIR/zellij-<uid>/sidebar-shell/<session>/<pane_id>`. The format is `command_name timestamp`. The plugin reads these files on the same ~1.5s timer as the AI state.

### Setup with `zellij-ssidebar`

The `zellij-ssidebar` binary generates shell hook code that chains with your existing `preexec`/`precmd` hooks (same pattern as direnv, starship, zoxide, and atuin):

**Zsh:**

```bash
eval "$(zellij-ssidebar hook zsh)"
```

Add to `~/.zshrc` (or use the NixOS module below).

**Bash:**

```bash
eval "$(zellij-ssidebar hook bash)"
```

Add to `~/.bashrc` (or use the NixOS module below).

The generated hooks:
- Write the current command's basename to the shared directory on execution
- Remove the file when the command finishes (returning to prompt)
- Strip NixOS wrapper prefixes (`__nvim-wrapped` → `nvim`)
- Chain with existing hooks so they don't clobber each other

### NixOS

A NixOS module is provided in `nix/module.nix`. Import it from the flake:

```nix
{ inputs, ... }:

{
  imports = [ inputs.zellij-ssidebar.nixosModules.default ];

  programs.zellij.ssidebar = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
    staleTimeout = 3600; # 60 minutes
  };
}
```

This:
- Installs the `zellij-ssidebar` binary to the system PATH
- Puts the `.wasm` plugin at `/etc/zellij/plugins/zellij-ssidebar.wasm`
- Injects the `eval "$(zellij-ssidebar hook ...)` line into your shell config
- Sets the `SIDEBAR_STALE_TIMEOUT` environment variable

> **Note:** The module is a pure NixOS module — it does not require Home Manager. The plugin is installed system-wide to `/etc/zellij/plugins/` where all users can access it.

## AI activity indicators

The sidebar shows real-time AI agent activity across all your Zellij sessions. When Claude Code (or any AI tool) is working in a session, you'll see it at a glance without switching sessions.

### How it works

AI state is shared across all sessions via per-pane files under `$TMPDIR/zellij-<uid>/sidebar-ai/<session>/<pane_id>`. The plugin runs in a WASI sandbox where its `/tmp` maps to the host's `$TMPDIR/zellij-<uid>/`, so the hook writes there (not host `/tmp`). Each sidebar instance reads these files on a ~10-second timer, so cross-session state appears within seconds. Pipe messages provide instant updates for the current session.

### Stale timeout

Both AI and shell state share the same stale timeout, controlled by the `SIDEBAR_STALE_TIMEOUT` environment variable (seconds, default `3600` = 60 minutes):

```bash
export SIDEBAR_STALE_TIMEOUT=900  # 15 minutes
```

A state file older than this timeout is ignored (crashed/killed process, missed cleanup). The hooks themselves remove the file on clean exit, so stale files are the exception.

### Setting up Claude Code hooks

Copy the hook script from the repo to your Claude hooks directory:

```bash
cp scripts/sidebar-status.sh ~/.claude/hooks/sidebar-status.sh
chmod +x ~/.claude/hooks/sidebar-status.sh
```

Then register it in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/sidebar-status.sh", "async": true }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/sidebar-status.sh", "async": true }] }],
    "Notification": [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/sidebar-status.sh", "async": true }] }],
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/sidebar-status.sh", "async": true }] }],
    "SessionEnd": [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/sidebar-status.sh", "async": true }] }]
  }
}
```

The hook script handles everything: it writes state files for cross-session visibility and sends pipe messages for instant current-session updates. It also tracks turn duration so you can see how long Claude worked.

> **Note:** The hooks fire on tool use events. Plain text responses (no tool calls) and "thinking" time don't trigger hooks, so the sidebar only reflects tool-based activity.

### Setting up OpenCode hooks

OpenCode integrates via its plugin system. The repo provides a native plugin that maps OpenCode events to sidebar state — no external dependencies.

1. Copy the hook script and plugin to your OpenCode config:

```bash
mkdir -p ~/.config/opencode/hooks ~/.config/opencode/plugins
cp scripts/opencode-sidebar.sh ~/.config/opencode/hooks/
cp scripts/opencode-sidebar.ts ~/.config/opencode/plugins/
chmod +x ~/.config/opencode/hooks/opencode-sidebar.sh
```

2. Restart opencode. The plugin auto-discovers from `~/.config/opencode/plugins/`. If it doesn't appear, register it explicitly in `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-sidebar"]
}
```

The plugin handles everything: it writes state files for cross-session visibility and sends pipe messages for instant current-session updates. It also tracks turn duration so you can see how long OpenCode worked.

> **Note:** The plugin hooks fire on tool use events. Plain text responses (no tool calls) and "thinking" time don't trigger hooks, so the sidebar only reflects tool-based activity.

### Other AI tools

Any tool can integrate — just write to the shared state directory:

```bash
# Signal that an AI agent is working in the current session
dir="${TMPDIR:-/tmp/}zellij-$(id -u)/sidebar-ai/$ZELLIJ_SESSION_NAME"
mkdir -p "$dir"
echo "active $(date +%s)" > "$dir/${ZELLIJ_PANE_ID:-0}"

# Or use pipes for instant updates in the current session
zellij pipe --name "sidebar::ai-active::$ZELLIJ_SESSION_NAME"
```

### Pipe API reference

| Pipe name | Effect |
|-----------|--------|
| `sidebar::ai-active::<session>` | Show AI as working (`▶` green) |
| `sidebar::ai-idle::<session>` | Show AI as idle (`■` cyan) |
| `sidebar::ai-waiting::<session>` | Show AI as waiting (`■` cyan) |
| `sidebar::attention::<session>` | Flag session for attention (`!` magenta) |
| `sidebar::clear::<session>` | Clear attention flag |

## Reloading the plugin

A build script handles compiling and installing:

```bash
./scripts/reload-all.sh
```

After installing, reload the plugin in each session via the Zellij plugin manager: **Ctrl+O, P**, select the sidebar, then press **Enter** to reload. The sidebar's snapshot restore ensures projects appear instantly on reload with no blank flash.

> **Note:** There is no Zellij CLI command to reload a layout-loaded plugin in-place. The manual Ctrl+O, P approach is the only reliable method.

## Pairs well with

This plugin handles session-level awareness. For the full picture, it works nicely alongside:

- [**zellij-sessionizer**](https://github.com/lapce/zellij-sessionizer): fuzzy directory search for starting sessions from anywhere on disk, not just your `scan_dir`. Good for one-off projects.
- [**zellij-choose-tree**](https://github.com/lapce/zellij-choose-tree): tree view for jumping between tabs and panes *within* a session. The sidebar handles between-session navigation, choose-tree handles within-session.

## Requirements

- Zellij 0.43.x+
- Rust with `wasm32-wasip1` target

## Licence

MIT
