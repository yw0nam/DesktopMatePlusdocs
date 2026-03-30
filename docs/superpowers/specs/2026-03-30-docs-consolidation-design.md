# Docs Consolidation Design

**Date:** 2026-03-30
**Status:** Draft
**Author:** PM Agent (brainstorm with user + Lead Agent feedback)

---

## Synopsis

Consolidate scattered TODO/Plan/Spec management from 4 locations into a unified `docs/superpowers/` structure with clear active/completed separation, cross-reference rules between Plans.md and INDEX.md, a new `quality-team` agent, and garden.sh automated archive freshness detection.

## Problem

1. **Scattered entry points** — Plans.md, INDEX.md, superpowers/plans/, superpowers/specs/, docs/plans/ (deprecated)
2. **Duplication & drift** — Plans.md and INDEX.md track overlapping state without sync
3. **Stale file accumulation** — Completed specs/plans remain in active directories
4. **No completion tracking** — No way to distinguish active vs completed in superpowers/

## Design

### 1. Directory Structure

**Before:**
```
docs/
├── plans/                          ← deprecated, abandoned
├── prds/feature/INDEX.md           ← feature catalog
├── superpowers/
│   ├── specs/                      ← active + completed mixed
│   └── plans/                      ← active + completed mixed
```

**After:**
```
docs/
├── superpowers/
│   ├── INDEX.md                    ← feature catalog (from prds/feature/INDEX.md)
│   ├── specs/                      ← active only
│   ├── plans/                      ← active only
│   └── completed/
│       ├── specs/                  ← archived specs
│       ├── plans/                  ← archived plans + docs/plans/ migration
│       └── prds/                   ← archived PRD task docs
```

**Migration:**
- `docs/prds/feature/INDEX.md` → `docs/superpowers/INDEX.md`
- `docs/prds/feature/**/*.md` (task docs) → `docs/superpowers/completed/prds/`
- `docs/plans/**/*.md` → `docs/superpowers/completed/plans/`
- Existing completed specs/plans (all cc:DONE references) → `completed/{specs,plans}/`
- Delete empty `docs/prds/` and `docs/plans/` after migration

**Archive condition:** A spec/plan moves to `completed/` when ALL tasks in Plans.md referencing it are cc:DONE. Orphan files (not referenced by any Plans.md task) also move to `completed/`.

### 2. Plans.md ↔ INDEX.md Cross-Reference

**Role separation (maintained):**
- `Plans.md` — Cross-repo execution tracking (cc:TODO/WIP/DONE). Short-lived per iteration.
- `INDEX.md` — Feature catalog. Project-lifetime, append-only.

**Reference rules:**

1. **Plans.md → INDEX.md**: PM Agent adds `[ref: INDEX#{section}/{id}]` when creating cc:TODO tasks. Lead Agent never adds ref — only marks status.
   ```markdown
   - [ ] **BE-05: Callback refactor** — ... DoD: ... spec-ref: docs/superpowers/specs/2026-03-30-callback-design.md. [ref: INDEX#fastapi_backend/02] [target: backend/]
   ```

2. **ref is optional**: Infrastructure/quality tasks (GC, DOC, QS) have no INDEX.md entry — no ref needed.

3. **Plans.md `spec-ref:` field**: Every feature task MUST include `spec-ref:` pointing to its design spec. This enables garden.sh GP-11 parsing.

4. **INDEX.md → Plans.md**: INDEX.md table includes active Plans.md Phase reference.

5. **State sync**:
   - Plans.md cc:DONE → quality-team immediately updates INDEX.md status
   - New features: PM Agent registers in INDEX.md first → Plans.md cc:TODO with ref + spec-ref

### 3. quality-team Agent

**Name:** `quality-team`
**Target:** `[target: workspace scripts/harness/]` + `[target: docs/]`
**Operation mode:** Event-driven (triggered by TASK_DONE messages from Lead)

**Responsibilities:**

| Task | Trigger | Output |
|------|---------|--------|
| garden.sh maintenance | Plans.md task | Script changes |
| check_docs.sh maintenance | Plans.md task | Script changes |
| QUALITY_SCORE.md update | After garden.sh run | Doc update |
| Archive completed files | TASK_DONE from Lead | git mv to completed/ |
| INDEX.md state sync | TASK_DONE from Lead | INDEX.md Status update |
| Cross-repo PR coordination | garden.sh creates repo PR | SPEC_REVIEW_REQUEST to affected team |
| GOLDEN_PRINCIPLES.md updates | New GP added | Doc update |

**TASK_DONE protocol (Lead → quality-team):**
```
TASK_DONE
task-id: {TASK-ID}
spec-ref: docs/superpowers/specs/{file} (if applicable)
action: archive + index-sync / index-sync-only / archive-only
```

quality-team processes the action and reports completion back to Lead.

**Conflict prevention:** quality-team must pull latest state before modifying INDEX.md to avoid merge conflicts with concurrent Plans.md edits.

### 4. garden.sh GP-11: Archive Freshness

**Addition to existing GP-1~10 framework:**

```
GP-11: Archive Freshness
  Target: docs/superpowers/specs/, docs/superpowers/plans/
  Condition: File referenced by Plans.md task(s) that are ALL cc:DONE,
             but file still in active directory
  Severity: WARN
  Action: Warning output only (no auto git mv — quality-team handles manually)
  Verify: garden.sh --gp GP-11
  Parse method: grep spec-ref: fields in Plans.md, cross-check with cc:DONE status
```

**Why warn-only, not auto-move:**
- garden.sh is a detection tool; execution is quality-team's responsibility
- Auto git mv risks conflicts with other teammates' worktrees

**Requires:** GOLDEN_PRINCIPLES.md updated with GP-11 definition (quality-team task).

### 5. Team Composition Update

**Before (4 members):**
pm-agent, backend-team, nanoclaw-team, dh-team

**After (5 members):**
pm-agent, backend-team, nanoclaw-team, dh-team, **quality-team**

quality-team uses `/teammate-workflow` skill like other implementation teammates.

### 6. CLAUDE.md Updates Required

- Update directory map in `docs/CLAUDE.md`
- Update FAQ/Appendix references in root `CLAUDE.md`
- Update Agent Teams section with quality-team
- Update Plans.md cc:TODO format documentation (spec-ref field)

## Out of Scope

- Automated CI/CD integration (workspace has no GitHub Actions)
- Changes to individual repo docs/ structures
- Plans.md format overhaul beyond adding spec-ref field

## Risks

- **Migration breaks links**: Existing cross-references in CLAUDE.md, FAQ, etc. must be updated
- **garden.sh parsing fragility**: Plans.md format must remain consistent for GP-11 to work
- **Transition period**: During migration, some files will be in old locations — garden.sh GP-11 should not run until migration is complete
