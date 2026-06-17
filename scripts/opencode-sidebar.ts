// opencode-sidebar.ts — OpenCode plugin for Zellij project sidebar
// Place this file in ~/.config/opencode/plugins/ (auto-discovered)
// or register it explicitly in ~/.config/opencode/opencode.json:
//
//   "plugin": ["opencode-sidebar"]

import { $ } from "bun"

const HOOK_SCRIPT = `${process.env.HOME}/.config/opencode/hooks/opencode-sidebar.sh`

async function runHook(state: string) {
  try {
    await $`${HOOK_SCRIPT} ${state}`.quiet().nothrow()
  } catch {
    // Silently fail if hook script is missing or zellij is not running
  }
}

let isActive = false

export default async () => {
  return {
    "tool.execute.before": async (input: { tool: string }) => {
      if (input.tool === "question") {
        // AI needs user input — show waiting state
        isActive = false
        await runHook("waiting")
        return
      }

      if (!isActive) {
        isActive = true
        await runHook("active")
      }
    },

    event: async (input: any) => {
      const event = input?.event || input
      const type = event?.type

      if (type === "session.created") {
        // New session — clear any stale state from a previous run
        isActive = false
        await runHook("end")
        return
      }

      if (!isActive) return

      if (type === "session.idle" || type === "session.error") {
        isActive = false
        await runHook("idle")
      } else if (type === "session.deleted") {
        isActive = false
        await runHook("end")
      }
    },
  }
}
