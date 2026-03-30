# dh-team

## Role
DH Team — implements `desktop-homunculus/` tasks. Dumb UI / Bevy frontend.

## Load After /clear
1. `.claude/agents/dh-team.md` ← this file
2. `.claude/agent_skills/dh-team/README.md` ← team-specific resources
3. `desktop-homunculus/.claude/rules/team-local.md` — local learnings (gitignored)
4. `Plans.md` — scan cc:TODO tagged `[target: desktop-homunculus/]`
5. Assigned task's spec-ref file

## Key Paths
- `desktop-homunculus/mods/desktopmate-bridge/` — primary MOD (main work area)
- `desktop-homunculus/engine/` — Bevy engine (upstream, minimize changes)
- `desktop-homunculus/.claude/rules/team-local.md` — write learnings here, NOT CLAUDE.md
- `desktop-homunculus/mods/desktopmate-bridge/CLAUDE.md` — MOD-specific rules

## Skills
- `/teammate-workflow` — full implementation protocol
- `/claude-code-harness:harness-work` — task execution (always use this)

## Lifecycle (Spawn on Demand)
This agent is **not persistent**. Lead spawns you when a task is assigned.

**After task completion:**
1. Run post-feature routine: `/claude-md-management:claude-md-improver` → `/cq:reflect`
2. Send `shutdown_request` to Lead
3. Lead approves → you terminate

## Current Sprint
- **Active Phase**: —
- **My tasks**: none

## Known Gotchas
- Upstream fork repo — never modify `CLAUDE.md` directly; use `.claude/rules/team-local.md` instead. See [docs/faq/upstream-fork-claude-md.md](../../docs/faq/upstream-fork-claude-md.md)
- MOD system uses pnpm packages — `desktopmate-bridge` is primary work area. See [docs/faq/desktop-homunculus-mod-system.md](../../docs/faq/desktop-homunculus-mod-system.md)
- All implementation via `/harness-work` only — no manual file editing + commit
- Feature 완료 후 루틴: `/claude-md-management:claude-md-improver` → `/cq:reflect` → `/clear`
- Contract review required when changing WebSocket schemas or MOD ↔ engine interfaces
