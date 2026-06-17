#!/usr/bin/env bash
# opencode-sidebar.sh — OpenCode hook for Zellij sidebar AI state
# Called by the opencode-sidebar.ts plugin with the state as argument:
#   opencode-sidebar.sh active
#   opencode-sidebar.sh idle
#   opencode-sidebar.sh waiting
#   opencode-sidebar.sh end
#
# One file per pane: $TMPDIR/zellij-<uid>/sidebar-ai/<session>/<pane_id>
# Format: "state timestamp [duration]"
#
# NOTE: the sidebar plugin runs in a WASI sandbox where its `/tmp` maps to the
# host's $TMPDIR/zellij-<uid>/, so this hook must write there (not host /tmp).

STATE="$1"
SESSION="$ZELLIJ_SESSION_NAME"
PANE="${ZELLIJ_PANE_ID:-0}"

[ -z "$SESSION" ] && exit 0
[ -z "$STATE" ] && exit 0

STATE_DIR="${TMPDIR:-/tmp/}zellij-$(id -u)/sidebar-ai/$SESSION"
mkdir -p "$STATE_DIR" 2>/dev/null
NOW=$(date +%s)

case "$STATE" in
  active)
    CURRENT=$(cat "$STATE_DIR/$PANE" 2>/dev/null)
    if [ "${CURRENT%% *}" != "active" ]; then
      echo "active $NOW" > "$STATE_DIR/$PANE"
    fi
    zellij pipe --name "sidebar::ai-active::${SESSION}" 2>/dev/null &
    ;;
  idle)
    CURRENT=$(cat "$STATE_DIR/$PANE" 2>/dev/null)
    STARTED=$(echo "$CURRENT" | awk '{print $2}')
    DURATION=0
    if [ "${CURRENT%% *}" = "active" ] && [ -n "$STARTED" ]; then
      DURATION=$((NOW - STARTED))
    fi
    echo "idle $NOW $DURATION" > "$STATE_DIR/$PANE"
    zellij pipe --name "sidebar::ai-idle::${SESSION}" 2>/dev/null &
    ;;
  waiting)
    CURRENT=$(cat "$STATE_DIR/$PANE" 2>/dev/null)
    STARTED=$(echo "$CURRENT" | awk '{print $2}')
    DURATION=0
    if [ "${CURRENT%% *}" = "active" ] && [ -n "$STARTED" ]; then
      DURATION=$((NOW - STARTED))
    fi
    echo "waiting $NOW $DURATION" > "$STATE_DIR/$PANE"
    zellij pipe --name "sidebar::ai-waiting::${SESSION}" 2>/dev/null &
    ;;
  end)
    # Session ended — remove this pane's state so a future session of the same
    # name doesn't inherit a stale "opencode" row.
    rm -f "$STATE_DIR/$PANE" 2>/dev/null
    rmdir "$STATE_DIR" 2>/dev/null
    ;;
esac

exit 0
