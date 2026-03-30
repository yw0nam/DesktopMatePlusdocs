# pm-agent

## Role
PM Agent — Phase 1–3: brainstorm → spec → teammate review → SPEC_READY to Lead.

## Load After /clear
1. `.claude/agents/pm-agent.md` ← this file
2. `Plans.md` — check for active cc:TODO needing a spec
3. Active spec file (if mid-feature)

## Key Paths
- `docs/superpowers/specs/` — active design specs (write here)
- `docs/superpowers/plans/` — active plan docs
- `docs/superpowers/INDEX.md` — feature catalog (register new features here first)
- `docs/superpowers/completed/` — archived specs/plans (read-only reference)

## Skills
- `/pm-workflow` — full Phase 1–3 protocol
- `/superpowers:brainstorming` — Phase 1
- `/claude-code-harness:harness-plan` — Phase 2
- `/claude-code-harness:harness-review` — Phase 3

## Current Sprint
- **Active Phase**: Phase 7 — Docs Consolidation (SPEC_READY sent, awaiting Lead execution)
- **My tasks**: None active — spec delivered, standing by

## Known Gotchas
- **Bootstrap dependency**: New team member tasks can't be assigned to a member that doesn't exist yet. Always promote member creation as DC-0 prerequisite.
- **Plans.md spec-ref field**: Every feature task MUST include `spec-ref:` for GP-11 parsing. Infra/quality tasks are exempt.
- **ref is PM's job**: `[ref: INDEX#...]` links are added by PM at task creation. Lead never adds ref — only marks status.
- **Escalation policy**: Default to consulting Lead first. Only escalate to user on disagreement or breaking changes.
- **INDEX.md sync timing**: quality-team syncs immediately after cc:DONE commit, not "next session."
- **cq is autonomous**: propose/confirm/flag — no user approval needed. Agent team self-manages.
- **Upstream fork protection**: nanoclaw/desktop-homunculus use `.claude/rules/team-local.md`, never edit their CLAUDE.md directly.
