---
name: planning-workflow
description: Use when starting any new feature, initiative, or cross-repo task planning in DesktopMatePlus — chains brainstorming to structured plan and distributes TODOs to sub-repos
---

# Planning Workflow

## Overview

Three-phase planning workflow for DesktopMatePlus cross-repo features:
**Brainstorm → Plan → Distribute**

Never skip phases. Each phase depends on the previous output.

## Workflow

```
[Feature request / idea]
        ↓
Phase 1: superpowers:brainstorming
        ↓
[Brainstorm output = spec]
        ↓
Phase 2: claude-code-harness:harness-plan (spec as input)
        ↓
[Structured tasks in Plans.md with [target:] markers]
        ↓
Phase 3: Distribute TODOs to sub-repos
        ↓
[Each repo team has their scoped tasks]
```

## Phase 1 — Brainstorm

Invoke `superpowers:brainstorming` with the feature description.

Output must include:
- User intent and goals
- Constraints and edge cases
- Component breakdown (which repos are affected)
- Open questions resolved

**Do not proceed to Phase 2 until brainstorm output is written.**

## Phase 2 — Plan

Pass the brainstorm output as the spec to `claude-code-harness:harness-plan`.

The plan must produce tasks in `Plans.md` with:
- `<!-- cc:TODO -->` markers
- `[target: repo/]` annotation on each task
- Phase grouping if tasks span multiple milestones
- Clear acceptance criteria per task

**Do not write vague tasks.** Each task must be actionable by a specific team.

## Phase 3 — Distribute

For each `cc:TODO` task in Plans.md, route to the appropriate sub-repo:

| Target | Action |
|--------|--------|
| `backend/` | Dispatch Backend Team Lead with task spec |
| `nanoclaw/` | Dispatch NanoClaw Team Lead with task spec |
| `desktop-homunculus/` | Dispatch DH Team Lead with task spec |
| `workspace scripts/` | Add to Plans.md only (no sub-repo) |

Distribution means dispatching the team lead subagent with the task context — not just writing `[target:]` labels.

## Red Flags — Skip No Phases

| Shortcut | Why Wrong |
|----------|-----------|
| "Idea is clear, skip brainstorm" | Unresolved constraints surface late. Always brainstorm. |
| "I'll just add tasks to Plans.md directly" | Without spec, tasks lack acceptance criteria. |
| "I'll distribute later" | TODOs left in Plans.md without dispatch never get done. |

## Quick Reference

```
1. Skill: superpowers:brainstorming
2. Skill: claude-code-harness:harness-plan  ← use brainstorm output as spec
3. Dispatch team leads for each [target:] task
```
