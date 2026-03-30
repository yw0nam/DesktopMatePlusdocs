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
- Run `TaskGet({taskId})` to read the task's `metadata.planRef` field (e.g. `"OBS-1"`)
- Find the matching `cc:TODO` entry in Plans.md and change it to `cc:DONE`
Note: harness-work updates the shared task list; Plans.md cc:DONE is a manual step.

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

Canonical team names for SendMessage: `backend-team`, `nanoclaw-team`, `dh-team`.

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
   (if the file does not exist, create it following the format in `docs/contracts/README.md`;
   if that file is also missing, use the entry format: `## METHOD /path\n- description: ...\n- confirmed: DATE, approved-by: TEAM`)

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
to: lead-agent
from: {your-team-name}
Two rounds of peer review failed. Arbitration needed.
Round 1 request: [paste]
Round 1 response: [paste]
Round 2 request: [paste]
Round 2 response: [paste]
```

### Step 4 — Post-feature routine (before reporting)

When all tasks for a feature (Plans.md Phase) are complete, run this routine **before** reporting to Lead:

**A. Update CLAUDE.md learnings:**
```
/claude-md-management:claude-md-improver
```
Record learnings, confusions, and patterns from this session.
- `nanoclaw/`, `desktop-homunculus/`: write to `.claude/rules/team-local.md` (gitignored) — never edit upstream CLAUDE.md directly.
- `backend/`: update `backend/CLAUDE.md` directly.

**B. Save knowledge to cq (Stack Overflow for agents):**
```
/cq:reflect
```
Then `cq.propose(...)` for each valuable learning:
- Non-obvious behaviors encountered
- Mistakes that could repeat
- Architectural decisions made
- Differences between similar concepts

When a past KU helped you: `cq.confirm(id)`. When a KU was wrong: `cq.flag(id, reason)`.

**C. Clear context:**
```
/clear
```
Keep context clean between features. After clearing, reload only:
- Your repo's CLAUDE.md
- Plans.md (current cc:TODO tasks)
- The relevant spec-ref file

### Step 5 — Report back to Lead Agent

After the post-feature routine, report:
- Tasks completed (list with task IDs)
- Files created/modified
- Test/lint results
- Any blockers or escalations

---

## Handling SPEC_REVIEW_REQUEST from PM Agent

When a `SPEC_REVIEW_REQUEST` arrives via SendMessage while you are executing tasks:

1. Pause your current task at the next natural break point
2. Read the linked `spec` file and the `cc:TODO` tasks in Plans.md tagged `[target: your-repo/]`
3. Assess two things only:
   - **Feasibility**: Can this actually be implemented in your repo given current architecture?
   - **Constraint conflicts**: Does this violate GP rules, existing patterns, or missing dependencies?
4. Respond immediately via SendMessage:

```
SPEC_REVIEW_RESPONSE
from: {your-team-name}
verdict: APPROVED | CHANGES_REQUESTED
concerns:
  - (if CHANGES_REQUESTED) specific problem + suggested fix
```

5. Resume your current task

**Review scope:** implementation feasibility and constraint conflicts only.
**Out of scope:** design taste, style preferences, unrelated improvements.
**Response time:** immediately — do not let PM Agent wait more than one task cycle.

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
