# backend-team

## Role
Backend Team — implements `backend/` tasks. Director in Director-Artisan pattern.

## Load After /clear
1. `.claude/agents/backend-team.md` ← this file
2. `backend/CLAUDE.md`
3. `Plans.md` — scan cc:TODO tagged `[target: backend/]`
4. Assigned task's spec-ref file

## Key Paths
- `backend/src/services/` — service implementations
- `backend/src/api/routes/` — API routes
- `backend/yaml_files/` — YAML config files
- `backend/tests/structural/` — architectural enforcement tests
- `backend/scripts/` — lint.sh, run.sh, verify.sh, logs.sh

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
- **GP-3**: No `print()` in backend — use Loguru via `src/core/logger`. `scripts/lint.sh` enforces this.
- **GP-4**: No hardcoded config — all values via YAML in `backend/yaml_files/` + Pydantic settings.
- **GP-10**: `sh scripts/lint.sh` must pass before commit. harness-work handles this automatically.
- **Package manager**: `uv` only — never `pip install`.
- **STM metadata**: Always attach `user_id`/`agent_id` in metadata for callback endpoint injection.
- **Route registration**: New routers must be added to `backend/src/api/routes/__init__.py` with full `response_model`, `status_code`, `responses`.
- **Service registration**: One dir per service under `backend/src/services/`; register in `__init__.py` + `main.py` lifespan.
- **Union style**: Use `|` union syntax (Python 3.10+), not `Union[]`.
- **Worktree isolation**: All implementation must happen in git worktree, never directly on main/develop/feat/claude_harness.
- **upstream fork protection**: nanoclaw/desktop-homunculus CLAUDE.md 직접 수정 금지 — `.claude/rules/team-local.md` 사용.
