# Agent Teams Workflow Redesign

**Date**: 2026-03-29
**Status**: Approved
**Supersedes**: `2026-03-29-cross-repo-contract-review-design.md`

---

## Problem

The current workflow has two fundamental issues:

1. **Skill loading misdesign**: Teammates were spawned inside `../worktrees/{repo}-{slug}/` (outside DesktopMatePlus). Teammates couldn't find DesktopMatePlus's `.claude/skills/`, so `teammate-workflow/SKILL.md` had to be copied to every sub-repo and kept in sync.

2. **No agent-to-agent interaction**: Teams ran in parallel in isolation. No peer-to-peer communication, no contract validation between teams. Effectively "parallel solo agents."

---

## Root Cause

Per the official Claude Code Agent Teams docs:

> "생성될 때, 팀원은 일반 세션과 동일한 프로젝트 컨텍스트를 로드합니다: CLAUDE.md, MCP servers, skills."

Teammates inherit the **spawning session's project context** at creation time — not from their working directory. The previous workflow spawned teammates by pointing them at sub-repo worktrees, causing them to miss the workspace-root skills.

---

## Solution

Spawn all teammates **from DesktopMatePlus**. They automatically load DesktopMatePlus's CLAUDE.md and skills. Worktrees remain for branch isolation — only the spawn location changes.

Additionally, adopt Agent Teams' **native shared task list** for runtime coordination, and add a **Contract Review Protocol** for cross-repo peer communication.

---

## Architecture

### Spawn Location Change

```
[Old]
Sub-repo worktree (../worktrees/nanoclaw-xxx/)
  → teammate reads nanoclaw/.claude/skills/teammate-workflow/SKILL.md

[New]
DesktopMatePlus (workspace root)
  → teammate auto-loads .claude/skills/teammate-workflow/SKILL.md
  → teammate works inside ../worktrees/{repo}-{slug}/ as instructed
```

Worktrees are still created from sub-repos for branch isolation — only the **teammate spawn point** changes to DesktopMatePlus.

### Task Coordination

| | Old | New |
|--|-----|-----|
| Runtime task tracking | `cc:TODO` in Plans.md | Agent Teams shared task list (TaskCreate) |
| Permanent record | Plans.md | Plans.md (still maintained) |
| Task assignment | Lead reads Plans.md, teammate reads it | Lead creates tasks, teammates self-assign |

Plans.md remains the source of truth for planning. The shared task list mirrors Plans.md tasks for runtime self-assignment.

### Cross-Repo Communication

Direct peer-to-peer via `SendMessage` tool. No Lead Agent intermediary for contract reviews.

---

## Phase-by-Phase Design

### Phase 1–3: Brainstorm → Plan → Review
No change.

### Phase 4: Distribute

Lead Agent:
1. Reads Plans.md `cc:TODO` tasks with `[target:]` markers
2. Creates tasks in shared task list via `TaskCreate`:
   ```
   TaskCreate(
     subject: "{task-id}: {description}",
     description: "{repo}/ directory. Plans.md {task-id} for full spec. DoD: {acceptance criteria}",
     metadata: { target: "{repo}", planRef: "{task-id}" }
   )
   ```
3. Sets `addBlockedBy` for tasks with `Depends:` in Plans.md
4. Plans.md `cc:TODO` markers remain as permanent record

### Phase 5: Worktree Setup + Teammate Spawn

**Step 1 — Create worktrees (same as before)**
```bash
cd nanoclaw/  && git worktree add ../worktrees/nanoclaw-{slug}  feat/{slug}
cd backend/   && git worktree add ../worktrees/backend-{slug}   feat/{slug}
cd desktop-homunculus/ && git worktree add ../worktrees/dh-{slug} feat/{slug}
```

**Step 2 — Spawn teammates FROM DesktopMatePlus**

Teammate prompt template:
```
You are the {team-name} teammate.
(Exact names: backend-team | nanoclaw-team | dh-team)

Your worktree: /home/spow12/codes/2025_lower/worktrees/{repo}-{slug}/

1. Load your workflow skill: /teammate-workflow
2. Self-assign tasks from the shared task list tagged for your repo
3. Run harness-work for each assigned task (inside your worktree)
4. Apply Contract Review Protocol when contract-affecting changes are detected
5. Report back when all your tasks are done: tasks completed, files changed, test results, blockers
```

**Critical rules:**
- NEVER include step-by-step implementation instructions
- NEVER specify which files to create or what code to write
- ALWAYS use exact team names: `backend-team`, `nanoclaw-team`, `dh-team` (required for SendMessage routing)

### Phase 6: Agent Teams Execution

Each teammate:

```
Self-assign task from shared task list
        ↓
cd ../worktrees/{repo}-{slug}/
        ↓
harness-work {task-number}
        ↓
Task complete → scan changed files
    Contract-affecting? NO → self-assign next task
    Contract-affecting? YES ↓
CONTRACT_REVIEW_REQUEST via SendMessage → target team
        ↓
Wait for response (continue independent tasks)
    APPROVED → update Plans.md cc:DONE → continue
    REJECTED round 1 → revise → round 2
    REJECTED round 2 → CONTRACT_ESCALATION to Lead
        ↓
All tasks done → report to Lead
```

#### Contract Review Protocol

**What triggers a contract review:**
- HTTP API endpoint added, modified, or deleted (`routes/`, `api/`)
- WebSocket message schema changed
- NanoClaw ↔ FastAPI callback/webhook payload structure changed
- IPC task file format changed

Judgment rule: when uncertain, trigger (over-trigger allowed, under-trigger forbidden).

**REQUEST format** (sent via SendMessage):
```
CONTRACT_REVIEW_REQUEST
from: {team-name}
to: {target-team-name}
round: 1
changed_files:
  - path/to/changed/file.py
summary: one-line description of what changed
impact: what the consuming team must do differently
```

**RESPONSE format**:
```
CONTRACT_REVIEW_RESPONSE
from: {target-team-name}
verdict: APPROVED | REJECTED
reason: <required if REJECTED — must include specific revision direction>
```

On APPROVED: append contract to `docs/contracts/{consumer}-{provider}.md`.

On REJECTED round 2: send `CONTRACT_ESCALATION` with full history to Lead.

### Phase 7: Review and Integration
No change. Lead reviews each teammate's report, checks acceptance criteria.

### Phase 8: Commit and Merge Worktree

Same as before, but note: worktrees still use `--force` (harness-work creates `.claude/state/` files inside worktrees).

```bash
cd worktrees/nanoclaw-{slug}/
git add <relevant files>
git commit -m "feat: ..."

cd nanoclaw/
git merge feat/{slug} --no-ff
git worktree remove --force ../worktrees/nanoclaw-{slug}
git branch -d feat/{slug}
```

### Phase 9: Complete and Save Memory
No change. Update Plans.md `cc:DONE`, run `/cq:reflect`, save memory.

---

## What Changes

| Artifact | Change |
|----------|--------|
| `.claude/skills/planning-workflow/SKILL.md` | Update Phase 5 (spawn from DesktopMatePlus), Phase 4 (TaskCreate), remove worktree-as-spawn-point language |
| `.claude/skills/teammate-workflow/SKILL.md` | Replace Plans.md `cc:TODO` reading with shared task list self-assign. Add Contract Review Protocol section. |
| `backend/.claude/skills/teammate-workflow/SKILL.md` | **DELETE** — no longer needed |
| `nanoclaw/.claude/skills/teammate-workflow/SKILL.md` | **DELETE** — no longer needed |
| `desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md` | **DELETE** — no longer needed |
| `CLAUDE.md` | Update Agent Teams section: remove "FORBIDDEN sub-agent" blanket rule, clarify teammates spawn from workspace root |
| `docs/contracts/README.md` | **CREATE** — contract registry format guide |

---

## What Stays the Same

- Worktrees for branch isolation (`../worktrees/{repo}-{slug}/`)
- `git worktree remove --force` in Phase 8
- Plans.md as permanent planning record
- harness-work for TDD/lint/review loop within each teammate
- Phase 1–3, 7, 9 unchanged

---

## Success Criteria

- Teammates spawned from DesktopMatePlus load `teammate-workflow` without any sub-repo skill copies
- Lead creates tasks via TaskCreate; teammates self-assign from shared task list
- A Backend-team change to a webhook triggers a `CONTRACT_REVIEW_REQUEST` to NanoClaw-team via SendMessage without going through Lead
- `backend/.claude/skills/teammate-workflow/SKILL.md` can be deleted without breaking the workflow
