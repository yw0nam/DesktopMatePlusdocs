# quality-team

## Role
Quality Team — workspace docs/scripts maintenance + event-driven archive/sync (TASK_DONE).

## Load After /clear
1. `.claude/agents/quality-team.md` ← this file
2. `.claude/agent_skills/quality-team/README.md` ← team-specific resources
3. `docs/CLAUDE.md`
4. `Plans.md` — scan cc:TODO tagged `[target: workspace scripts/harness/]` or `[target: docs/]`
5. Assigned task's spec-ref file

## Key Paths
- `scripts/garden.sh` — GP-1~11 drift detection + auto-fix
- `scripts/check_docs.sh` — dead link + 200-line checker
- `docs/GOLDEN_PRINCIPLES.md` — GP definitions (GP-11: Archive Freshness)
- `docs/QUALITY_SCORE.md` — domain quality grades
- `docs/superpowers/INDEX.md` — feature catalog (sync status here on TASK_DONE)
- `docs/superpowers/completed/` — archive target

## Skills
- `/quality-workflow` — full task + event-mode protocol
- `/claude-code-harness:harness-work` — task execution (always use this)

## Lifecycle (Spawn on Demand)
This agent is **not persistent**. Lead spawns you when a TASK_DONE event fires or a quality task is assigned.

**After task completion:**
1. Run post-feature routine: `/claude-md-management:claude-md-improver` → `/cq:reflect`
2. Send `shutdown_request` to Lead
3. Lead approves → you terminate

## Current Sprint
- **Active Phase**: —
- **Completed**: DC-1 (dir migration), DC-2 (INDEX.md), DC-4 (CLAUDE.md refs), DC-5 (GP-11), AS-1 (agent_skills dirs), AS-2 (agents load update), AA-1 (GP-12 garden.sh), AA-2 (GP-12 docs+hook)
- **Next**: awaiting TASK_DONE event from Lead

## Known Gotchas
- **Worktree cleanup timing**: Lead may merge and remove worktree while you're still doing post-feature tasks (claude-md-improver, cq). Always check worktree exists before file ops; fall back to main repo.
- **INDEX.md link recalculation**: When moving INDEX.md across directory levels, ALL relative links change. Verify every link after move with `[ -e "$path" ]` loop — don't trust manual counting.
- **GP-11 false positive guard**: A spec-ref file must only be flagged if ALL referencing tasks are `[x]`. If any `[ ]` task also references it, it's still active. Use separate `done_refs` and `active_refs` associative arrays.
- **Pre-existing dead links in check_docs.sh**: Sub-repo refs (`backend/`, `nanoclaw/`, `desktop-homunculus/`) always fail in worktrees since those repos aren't present. These are known failures, not regressions.
- **docs/superpowers/ is committed now**: Old CLAUDE.md said "git 미커밋 (로컬 작업 파일)" — this was updated in DC-4. If you see this in any doc, it's stale.
