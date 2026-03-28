---
name: planning-workflow
description: Use when starting any new feature, initiative, or cross-repo task planning in DesktopMatePlus — chains brainstorming → plan → review → Agent Teams execution → release → memory
---

# Planning Workflow

## Overview

Full 7-phase workflow for DesktopMatePlus cross-repo features.
**Never skip phases. Each phase depends on the previous output.**

```
[Feature request / idea]
        ↓
Phase 1: superpowers:brainstorming
        ↓
[Brainstorm output = spec.md]
        ↓
Phase 2: claude-code-harness:harness-plan (spec.md as input)
        ↓
[Structured tasks in Plans.md with [target:] markers]
        ↓
Phase 3: claude-code-harness:harness-review (spec.md as input)
        ↓
[Review feedback → iterate Phase 2 until approved]
        ↓
Phase 4: Distribute TODOs to sub-repos
        ↓
[Each repo team has their scoped tasks]
        ↓
Phase 5: Agent Teams execution in each repo
        ↓
[/harness-work breezing --no-discuss all → report back to Lead Agent]
        ↓
Phase 6: Review and integration
        ↓
[Lead Agent reviews → delegates /harness-release per repo team]
        ↓
Phase 7: Commit
        ↓
[Each affected repo commits; workspace Plans.md committed last]
        ↓
Phase 8: Complete and save memory
        ↓
[Mark cc:DONE, save memories useful for similar future tasks]
```

---

## Phase 1 — Brainstorm

Invoke `superpowers:brainstorming` with the feature description.

Output must include:
- User intent and goals
- Constraints and edge cases
- Component breakdown (which repos are affected)
- Open questions resolved

**Do not proceed to Phase 2 until brainstorm output is written.**

---

## Phase 2 — Plan

Pass the brainstorm output as spec to `claude-code-harness:harness-plan`.

The plan must produce tasks in `Plans.md` with:
- `<!-- cc:TODO -->` markers
- `[target: repo/]` annotation on each task
- Phase grouping if tasks span multiple milestones
- Clear acceptance criteria per task

**Do not write vague tasks.** Each task must be actionable by a specific team.

---

## Phase 3 — Review

Invoke `claude-code-harness:harness-review` with the spec.md as input.

- If feedback → revise tasks in Plans.md, re-review
- Loop Phase 2 ↔ Phase 3 until reviewer approves
- **Do not proceed to Phase 4 without approval**

---

## Phase 4 — Distribute

For each approved `cc:TODO` task, annotate in Plans.md and mirror to each sub-repo's Plans.md:

| Target | Plans.md annotation | Sub-repo Plans.md |
|--------|--------------------|--------------------|
| `backend/` | `[target: backend/]` | `backend/Plans.md` |
| `nanoclaw/` | `[target: nanoclaw/]` | `nanoclaw/Plans.md` |
| `desktop-homunculus/` | `[target: desktop-homunculus/]` | `desktop-homunculus/Plans.md` |
| `workspace scripts/` | `[target: workspace scripts/]` | Plans.md only |

Only distribute to repos that have assigned tasks for this session.

---

## Phase 5 — Agent Teams Execution

Spawn Agent Team (requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`).

Say to the Leader:

```
Create an agent team to execute the cross-repo tasks in Plans.md.
Spawn teammates for repos that have cc:TODO tasks:
- backend-team (works in backend/)
- nanoclaw-team (works in nanoclaw/)
- dh-team (works in desktop-homunculus/)

Each teammate should:
1. Read their repo's CLAUDE.md first
2. Run /harness-work breezing --no-discuss all for their [target:] tasks
3. Report back to leader when done: tasks completed, files changed, test results
```

Each teammate is a full independent Claude Code session — skills auto-loaded from project context.
Use `Shift+Down` to cycle teammates, click pane to message directly.

---

## Phase 6 — Review and Integration

Lead Agent reviews each teammate's report:
- Verify acceptance criteria met
- Check for cross-repo integration issues
- If issues found: message the relevant teammate directly with fix instructions

Once approved, delegate release prep:

```
Ask each teammate to run /harness-release to prepare:
- Release notes
- Changelog entry
- Version bump (if applicable)
```

Coordinate release activities across repos from Leader position.

---

## Phase 7 — Commit

Commit changes in each affected repo **in dependency order** (sub-repos first, workspace last).

For each repo team:
1. `git add` only relevant files (never `git add .` — avoid committing untracked sub-repos or temp files)
2. Commit with a descriptive message following repo conventions
3. Workspace `Plans.md` commit comes last (after all sub-repo commits)

```
# Order: nanoclaw/ → backend/ → desktop-homunculus/ → DesktopMatePlus (Plans.md)
```

**Do not push** unless user explicitly requests it.

---

## Phase 8 — Complete and Save Memory

1. Update Plans.md: change `cc:TODO` → `cc:DONE` for all completed tasks
2. Clean up Agent Team: ask leader to `Clean up the team`
3. Save memories useful for future similar tasks:
   - Patterns that worked well
   - Pitfalls encountered
   - Cross-repo coordination decisions

---

## Red Flags — Skip No Phases

| Shortcut | Why Wrong |
|----------|-----------|
| "Idea is clear, skip brainstorm" | Unresolved constraints surface late. Always brainstorm. |
| "I'll add tasks to Plans.md directly" | Without spec, tasks lack acceptance criteria. |
| "Skip review, plan looks good" | Review catches scope creep and missing DoD. |
| "I'll distribute later" | TODOs without dispatch never get executed. |
| "Just run it without Agent Teams" | Single-agent execution loses parallelism and repo isolation. |

---

## Quick Reference

```
1. Skill: superpowers:brainstorming
2. Skill: claude-code-harness:harness-plan   ← brainstorm output as spec
3. Skill: claude-code-harness:harness-review  ← iterate until approved
4. Mirror tasks to sub-repo Plans.md
5. Spawn Agent Team → /harness-work breezing --no-discuss all
6. Review reports → /harness-release per repo
7. Commit: sub-repos first → workspace Plans.md last
8. cc:DONE + clean up team + save memory
```
