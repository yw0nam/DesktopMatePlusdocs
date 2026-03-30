# Agent Teams Workflow Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Agent Teams workflow so teammates are spawned from DesktopMatePlus (auto-loading workspace skills), use the native shared task list for runtime coordination, and communicate peer-to-peer via Contract Review Protocol.

**Architecture:** Spawn point moves from sub-repo worktrees to DesktopMatePlus workspace root. Worktrees remain for branch isolation. teammate-workflow sub-repo copies are deleted. Plans.md becomes permanent record; TaskCreate drives runtime execution.

**Tech Stack:** SKILL.md (markdown), CLAUDE.md, docs/contracts/ (markdown)

**Spec:** `docs/superpowers/specs/2026-03-29-agent-teams-workflow-redesign.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `.claude/skills/teammate-workflow/SKILL.md` | Rewrite | Shared task list self-assign + Contract Review Protocol |
| `.claude/skills/planning-workflow/SKILL.md` | Modify | Phase 4 TaskCreate, Phase 5 spawn from DesktopMatePlus |
| `CLAUDE.md` | Modify | Agent Teams section: clarify spawn + sub-agent rule |
| `docs/contracts/README.md` | Create | Contract registry format guide |
| `backend/.claude/skills/teammate-workflow/SKILL.md` | Delete | No longer needed |
| `nanoclaw/.claude/skills/teammate-workflow/SKILL.md` | Delete | No longer needed |
| `desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md` | Delete | No longer needed |

---

## Task 1: Rewrite workspace teammate-workflow SKILL.md

**Files:**
- Rewrite: `.claude/skills/teammate-workflow/SKILL.md`

- [ ] **Step 1: Replace entire file content**

Write `.claude/skills/teammate-workflow/SKILL.md` with:

```markdown
# Teammate Workflow

You are an implementing teammate in the DesktopMatePlus Agent Teams workflow.
The Lead Agent has already completed Phases 1–3 (brainstorm → plan → review) and created tasks in the shared task list.
Your job covers **Phase 6 (implement) → Phase 7 (report) only**.

---

## MANDATORY: Use harness-work for ALL implementation

**DO NOT implement tasks directly. Always use:**

```
/harness-work {task-number}
```

This is not optional. `harness-work` handles TDD, lint checks, and commit formatting automatically. Implementing tasks manually bypasses these checks and will cause GP violations.

---

## Your Responsibilities

### Step 1 — Self-assign your tasks

View the shared task list and claim tasks tagged for your repo:

```
TaskList                                              ← view available tasks
TaskUpdate({taskId}, status: "in_progress",
           owner: "{your-team-name}")                 ← claim a task
```

Only claim tasks tagged for your repo (`backend`, `nanoclaw`, `desktop-homunculus`).
Tasks with unresolved `blockedBy` dependencies cannot be claimed yet.

### Step 2 — Work inside your assigned worktree

Your worktree path is specified in your spawn prompt (e.g., `/home/spow12/codes/2025_lower/worktrees/{repo}-{slug}/`).
Always work inside that path. Never commit directly to `main` / `develop` / `feat/claude_harness`.

### Step 3 — Execute tasks via harness-work

```
/harness-work {task-number}
```

harness-work will:
- Implement the task with TDD
- Run lint/tests after each task
- Commit with conventional commit messages
- Mark the task complete

After harness-work completes, update Plans.md:
- Find the matching `cc:TODO` entry (use `planRef` from the task metadata)
- Change it to `cc:DONE`

### Step 3a — Contract Review (after each task)

After harness-work completes each task, scan the changed files.

**Triggers contract review** (any of these):
- HTTP API endpoint added, modified, or deleted (`routes/`, `api/`)
- WebSocket message schema changed
- NanoClaw ↔ FastAPI callback/webhook payload structure changed
- IPC task file format changed

**Does not trigger:**
- Internal logic, refactoring, logging, test additions
- Intra-repo service changes with no external interface impact

**Judgment rule**: When uncertain, trigger (over-trigger allowed, under-trigger forbidden).

#### Sending a CONTRACT_REVIEW_REQUEST

Use the `SendMessage` tool to the target teammate (`backend-team`, `nanoclaw-team`, or `dh-team`):

```
CONTRACT_REVIEW_REQUEST
from: {your-team-name}
to: {target-team-name}
round: 1
changed_files:
  - path/to/changed/file.py
summary: one-line description of what changed
impact: what the consuming team must do differently as a result
```

Pause contract-dependent tasks. Continue independent tasks while waiting.

#### Receiving a CONTRACT_REVIEW_REQUEST

When a review request arrives via SendMessage:
1. Pause your current task briefly
2. Read `changed_files` and `summary`
3. Answer one question: **"Is this breaking from the consumer's perspective?"**
4. Respond immediately:

```
CONTRACT_REVIEW_RESPONSE
from: {your-team-name}
verdict: APPROVED | REJECTED
reason: <required if REJECTED — must include specific revision direction>
```

#### On APPROVED

1. Resume paused tasks
2. Append the contract to `docs/contracts/{consumer}-{provider}.md`
   (create file if it does not exist — follow format in `docs/contracts/README.md`)

#### On REJECTED (round 1)

Apply the `reason`, revise your implementation, then send round 2:

```
CONTRACT_REVIEW_REQUEST
from: {your-team-name}
to: {target-team-name}
round: 2
changed_files:
  - path/to/revised/file.py
summary: revised description
impact: revised impact
```

#### On REJECTED (round 2) — Escalate to Lead

```
CONTRACT_ESCALATION
Two rounds of peer review failed. Arbitration needed.
Round 1 request: [paste]
Round 1 response: [paste]
Round 2 request: [paste]
Round 2 response: [paste]
```

### Step 4 — Report back to Lead Agent

When all your tasks are complete, report:
- Tasks completed (list with task IDs)
- Files created/modified
- Test/lint results
- Any blockers or escalations

---

## Golden Principles (enforced by harness-work)

See `docs/GOLDEN_PRINCIPLES.md` in workspace root.
Key rules:
- **GP-3**: No `print()` (backend) / no `console.log()` (nanoclaw)
- **GP-4**: No hardcoded config values
- **GP-10**: `sh scripts/lint.sh` must pass (backend) / `npm run build` must pass (nanoclaw)

## Escalate to Lead Agent if

- A task requires changes outside your assigned repo
- GP violation cannot be fixed without architectural decision
- harness-work fails after 2 retries
- Contract review round 2 rejected
```

- [ ] **Step 2: Verify file is well-formed**

Read `.claude/skills/teammate-workflow/SKILL.md` and confirm:
- Step 1 uses TaskList/TaskUpdate (not Plans.md cc:TODO)
- Step 3a Contract Review section is present
- No reference to `harness-work breezing` or Plans.md reading for task discovery

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/teammate-workflow/SKILL.md
git commit -m "feat(workflow): rewrite teammate-workflow with task list self-assign and contract review"
```

---

## Task 2: Update planning-workflow SKILL.md

**Files:**
- Modify: `.claude/skills/planning-workflow/SKILL.md`

- [ ] **Step 1: Replace Phase 4 content**

Find the `## Phase 4 — Distribute` section. Replace its entire content with:

```markdown
## Phase 4 — Distribute

For each approved `cc:TODO` task in Plans.md, create a task in the shared task list:

```bash
TaskCreate(
  subject: "{task-id}: {description}",
  description: "{repo}/ directory. See Plans.md {task-id} for full spec. DoD: {acceptance criteria}",
  metadata: { target: "{repo}", planRef: "{task-id}" }
)
```

Set `addBlockedBy` for tasks that have `Depends:` entries in Plans.md.

Plans.md `cc:TODO` markers remain unchanged — they are the permanent planning record.

Only create tasks for repos that have assigned work for this session.
```

- [ ] **Step 2: Replace Phase 5 teammate prompt template**

Find the `**Teammate prompt template**` block in Phase 6 (currently contains `You are the {repo} teammate.`). Replace with:

```markdown
**Teammate prompt template** — keep it lean. Do NOT include implementation instructions:

```
You are the {team-name} teammate.
(Exact names: backend-team | nanoclaw-team | dh-team)

Your worktree: /home/spow12/codes/2025_lower/worktrees/{repo}-{slug}/

1. Load your workflow skill: /teammate-workflow
2. Self-assign tasks from the shared task list tagged for your repo
3. Run harness-work for each assigned task (inside your worktree)
4. Apply Contract Review Protocol when contract-affecting changes are detected
5. Report back when done: tasks completed, files changed, test results, blockers
```

**Critical rules for writing teammate prompts:**
- NEVER include step-by-step implementation instructions — that defeats harness-work
- NEVER specify which files to create or what code to write
- ALWAYS use exact team names (`backend-team`, `nanoclaw-team`, `dh-team`) — required for SendMessage routing
- Teammates are spawned from DesktopMatePlus and auto-load workspace skills — no sub-repo skill copies needed
```

- [ ] **Step 3: Remove sub-repo Plans.md mirroring from Phase 4**

Find and remove this block from Phase 4 (old distribute section):

```
After mirroring, **commit Plans.md in each affected sub-repo immediately**:

```bash
cd nanoclaw/  && git add Plans.md && git commit -m "docs(plans): add <feature> tasks cc:TODO"
cd backend/   && git add Plans.md && git commit -m "docs(plans): add <feature> tasks cc:TODO"
# workspace root Plans.md is committed in Phase 9
```
```

- [ ] **Step 4: Update Quick Reference**

Find the Quick Reference section at the bottom. Replace step 4 and 5:

Old:
```
4. Mirror tasks to sub-repo Plans.md + commit Plans.md in each sub-repo
5. Create worktrees: cd {repo}/ && git worktree add ../worktrees/{repo}-{slug} feat/{slug}
6. Spawn Agent Team → work inside worktrees → /harness-work breezing --no-discuss all
```

New:
```
4. TaskCreate for each cc:TODO task (shared task list) — Plans.md cc:TODO stays as record
5. Create worktrees: cd {repo}/ && git worktree add ../worktrees/{repo}-{slug} feat/{slug}
6. Spawn Agent Team from DesktopMatePlus → teammates self-assign tasks → harness-work
```

- [ ] **Step 5: Verify changes**

Read Phase 4 and Phase 6 sections and confirm:
- Phase 4 uses TaskCreate (not sub-repo Plans.md mirroring)
- Phase 6 prompt template uses `{team-name}` with three canonical names
- Quick reference step 4 mentions TaskCreate

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/planning-workflow/SKILL.md
git commit -m "feat(workflow): update planning-workflow for DesktopMatePlus spawn and task list"
```

---

## Task 3: Update CLAUDE.md Agent Teams section

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Replace Agent Teams Execution section**

Find this block:

```markdown
## Agent Teams Execution (Phase 4–7)

> **MANDATORY**: Implementation MUST use tmux-based Agent Teams. The `Agent` tool (sub-agent) is **FORBIDDEN** for implementation — loses repo isolation and bypasses the worktree workflow. Allowed only for research-only tasks (no code changes).

See full details: [docs/agent-teams-workflow.md](./docs/agent-teams-workflow.md)
```

Replace with:

```markdown
## Agent Teams Execution (Phase 4–7)

> **MANDATORY**: Implementation MUST use Agent Teams spawned **from DesktopMatePlus**. Teammates auto-load workspace CLAUDE.md and skills at creation time.
>
> **Sub-agent rules:**
> - Lead Agent: `Agent` tool **FORBIDDEN** for implementation — bypasses repo isolation
> - Teammates: sub-agents allowed internally (harness-work uses them for TDD/review loops)
> - `Agent` tool allowed for research-only tasks (no code changes)

See full details: `.claude/skills/planning-workflow/SKILL.md`
```

- [ ] **Step 2: Verify**

Read the updated Agent Teams Execution section and confirm:
- No reference to `docs/agent-teams-workflow.md` (file is deleted)
- Spawn from DesktopMatePlus is explicit
- Sub-agent rules distinguish Lead vs Teammate

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): update agent teams spawn rule and sub-agent policy"
```

---

## Task 4: Create docs/contracts/README.md

**Files:**
- Create: `docs/contracts/README.md`

- [ ] **Step 1: Create file**

Write `docs/contracts/README.md`:

```markdown
# Contract Registry

This directory records confirmed cross-repo API contracts.

## Purpose

Contracts are accumulated here after `CONTRACT_REVIEW_REQUEST` / `APPROVED` cycles during Agent Teams sessions. Once recorded, teammates check this file before applying self-judgment — reducing detection misses.

## File Naming

`{consumer}-{provider}.md`

Examples:
- `nanoclaw-backend.md` — NanoClaw consumes Backend HTTP API
- `backend-dh.md` — Backend produces WebSocket events consumed by desktop-homunculus

## Entry Format

```markdown
## {HTTP METHOD} {path}  (or: WebSocket event `{name}` / IPC format `{name}`)
- description: what this contract covers
- payload: key fields and types (brief)
- confirmed: {YYYY-MM-DD}, approved-by: {team-name}
```

### Example

```markdown
## POST /api/webhooks/fastapi
- description: NanoClaw delegates a task result back to FastAPI
- payload: session_id (str, required), result (str, required), agent_id (str, optional)
- confirmed: 2026-03-29, approved-by: backend-team
```

## Graduation Path

As contracts accumulate, teammates use this file to detect violations automatically (no self-judgment needed for known contracts). New contracts still go through self-judgment in `teammate-workflow`.

This directory is checked by `scripts/check_docs.sh` for dead links and freshness.
```

- [ ] **Step 2: Verify**

```bash
cat docs/contracts/README.md
```

Expected: full content printed.

- [ ] **Step 3: Commit**

```bash
git add docs/contracts/README.md
git commit -m "docs(contracts): add contract registry directory and format guide"
```

---

## Task 5: Delete sub-repo teammate-workflow copies

**Files:**
- Delete: `backend/.claude/skills/teammate-workflow/SKILL.md`
- Delete: `nanoclaw/.claude/skills/teammate-workflow/SKILL.md`
- Delete: `desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md`

- [ ] **Step 1: Confirm files exist**

```bash
ls backend/.claude/skills/teammate-workflow/SKILL.md
ls nanoclaw/.claude/skills/teammate-workflow/SKILL.md
ls desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md
```

Expected: all three found.

- [ ] **Step 2: Delete and commit in backend/**

```bash
cd backend
git rm .claude/skills/teammate-workflow/SKILL.md
git commit -m "chore(workflow): remove teammate-workflow copy — loaded from workspace root"
cd ..
```

- [ ] **Step 3: Delete and commit in nanoclaw/**

```bash
cd nanoclaw
git rm .claude/skills/teammate-workflow/SKILL.md
git commit -m "chore(workflow): remove teammate-workflow copy — loaded from workspace root"
cd ..
```

- [ ] **Step 4: Delete and commit in desktop-homunculus/**

```bash
cd desktop-homunculus
git rm .claude/skills/teammate-workflow/SKILL.md
git commit -m "chore(workflow): remove teammate-workflow copy — loaded from workspace root"
cd ..
```

- [ ] **Step 5: Verify deletions**

```bash
ls backend/.claude/skills/teammate-workflow/SKILL.md 2>&1 | grep -q "No such file" && echo "backend: deleted"
ls nanoclaw/.claude/skills/teammate-workflow/SKILL.md 2>&1 | grep -q "No such file" && echo "nanoclaw: deleted"
ls desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md 2>&1 | grep -q "No such file" && echo "dh: deleted"
```

Expected: all three print "deleted".

---

## Self-Review

- [ ] **Spec coverage check**
  - Spawn from DesktopMatePlus → Task 2 (prompt template) + Task 3 (CLAUDE.md) ✓
  - Native task list (TaskCreate) → Task 2 (Phase 4) ✓
  - teammate-workflow self-assign → Task 1 (Step 1) ✓
  - Contract Review Protocol → Task 1 (Step 3a) ✓
  - Sub-repo skill copies deleted → Task 5 ✓
  - docs/contracts/ created → Task 4 ✓

- [ ] **No placeholder scan**: No TBD/TODO in written content

- [ ] **Consistency check**: Team names (`backend-team`, `nanoclaw-team`, `dh-team`) consistent across Task 1 and Task 2
