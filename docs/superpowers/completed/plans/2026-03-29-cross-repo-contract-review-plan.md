# Cross-Repo Contract Review Protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real-time peer-to-peer contract validation between Agent Teams teammates so that contract-affecting changes are reviewed and approved by consuming teams before proceeding.

**Architecture:** Extend `teammate-workflow/SKILL.md` with a Contract Review Protocol section that teammates follow after each harness-work task. Teams communicate via `SendMessage` directly. `planning-workflow/SKILL.md` is updated to require named teammates so routing works.

**Tech Stack:** SKILL.md (markdown), SendMessage tool (Claude Code Agent Teams), `docs/contracts/` (markdown accumulation)

**Spec:** `docs/superpowers/specs/2026-03-29-cross-repo-contract-review-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `.claude/skills/teammate-workflow/SKILL.md` | Modify | Add Step 3a — Contract Review Protocol |
| `.claude/skills/planning-workflow/SKILL.md` | Modify | Require named teammates in Phase 6 prompt template |
| `docs/contracts/README.md` | Create | Explain contracts directory format and graduation path |

---

## Task 1: Add Contract Review Protocol to teammate-workflow

**Files:**
- Modify: `.claude/skills/teammate-workflow/SKILL.md` (after Step 3, before Step 4)

- [ ] **Step 1: Verify current Step 3 / Step 4 boundary**

Open `.claude/skills/teammate-workflow/SKILL.md` and confirm the text between Step 3 and Step 4 looks like:

```
### Step 3 — Execute ALL tasks via harness-work
...
/harness-work breezing --no-discuss all
...
### Step 4 — Report back to Lead Agent
```

- [ ] **Step 2: Insert Contract Review Protocol section between Step 3 and Step 4**

Insert the following block immediately after the harness-work code block in Step 3 (before `### Step 4`):

```markdown
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
4. Respond immediately with:

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

Send to Lead Agent:

```
CONTRACT_ESCALATION
Two rounds of peer review failed. Arbitration needed.
Round 1 request: [paste full request]
Round 1 response: [paste full response]
Round 2 request: [paste full request]
Round 2 response: [paste full response]
```
```

- [ ] **Step 3: Verify the section is in the right place**

Read the file and confirm this order:
1. Step 3 — Execute ALL tasks via harness-work
2. Step 3a — Contract Review (after each task)  ← new
3. Step 4 — Report back to Lead Agent

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/teammate-workflow/SKILL.md
git commit -m "feat(workflow): add contract review protocol to teammate-workflow"
```

---

## Task 2: Update planning-workflow to require named teammates

**Files:**
- Modify: `.claude/skills/planning-workflow/SKILL.md` (Phase 6 section)

- [ ] **Step 1: Locate the teammate prompt template in Phase 6**

Find this block in `.claude/skills/planning-workflow/SKILL.md`:

```
You are the {repo} teammate.

1. Read /home/.../{repo}/CLAUDE.md (the original repo, not the worktree)
2. Load your workflow skill: /teammate-workflow
3. Your worktree: worktrees/{repo}-{slug}/
4. Run: /harness-work breezing --no-discuss all
5. Report back when done: tasks completed, files changed, test results, blockers
```

- [ ] **Step 2: Replace teammate prompt template**

Replace the block above with:

```
You are the {repo-team-name} teammate.
(Use exact names: backend-team | nanoclaw-team | dh-team)

1. Read /home/.../{repo}/CLAUDE.md (the original repo, not the worktree)
2. Load your workflow skill: /teammate-workflow
3. Your worktree: worktrees/{repo}-{slug}/
4. Run: /harness-work breezing --no-discuss all
5. Contract review may pause execution mid-run — respond to incoming SendMessage requests promptly
6. Report back when done: tasks completed, files changed, test results, blockers
```

- [ ] **Step 3: Add naming rule to Critical rules block**

Find the "Critical rules for writing teammate prompts" block and add one rule:

```markdown
- ALWAYS assign exact team names (backend-team | nanoclaw-team | dh-team) — required for SendMessage routing in contract review
```

- [ ] **Step 4: Verify**

Read Phase 6 section and confirm:
- Teammate prompt template uses `{repo-team-name}` with the three canonical names listed
- Critical rules block includes the naming rule
- Step 5 in prompt mentions contract review

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/planning-workflow/SKILL.md
git commit -m "feat(workflow): require named teammates in Phase 6 for contract review routing"
```

---

## Task 3: Create docs/contracts/README.md

**Files:**
- Create: `docs/contracts/README.md`

- [ ] **Step 1: Create docs/contracts/ directory and README**

Create `docs/contracts/README.md` with this content:

```markdown
# Contract Registry

This directory records confirmed cross-repo API contracts.

## Purpose

Contracts are accumulated here after `CONTRACT_REVIEW_REQUEST` / `APPROVED` cycles in Agent Teams sessions. Once a contract is recorded here, teammates check this file first before applying self-judgment — reducing false negatives.

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

As contracts accumulate, teammates use this file to detect violations automatically (no self-judgment needed for known contracts). New contracts still go through the self-judgment path in `teammate-workflow`.

This directory is checked by `scripts/check_docs.sh` for dead links and freshness.
```

- [ ] **Step 2: Verify file exists and is well-formed**

```bash
cat docs/contracts/README.md
```

Expected: Full content printed with no truncation.

- [ ] **Step 3: Commit**

```bash
git add docs/contracts/README.md
git commit -m "docs(contracts): add contract registry directory and format guide"
```

---

## Task 4: Sync teammate-workflow to sub-repos

**Files:**
- Modify: `backend/.claude/skills/teammate-workflow/SKILL.md`
- Modify: `nanoclaw/.claude/skills/teammate-workflow/SKILL.md`
- Modify: `desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md`

**Why**: Teammates run inside worktrees created with `git worktree add ../worktrees/{repo}-{slug}`. These worktrees inherit the sub-repo's `.claude/skills/` directory — NOT the workspace root's. So teammate-workflow must exist in each sub-repo to be discoverable.

- [ ] **Step 1: Verify the three sub-repo skill files exist**

```bash
ls backend/.claude/skills/teammate-workflow/SKILL.md
ls nanoclaw/.claude/skills/teammate-workflow/SKILL.md
ls desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md
```

Expected: all three files found.

- [ ] **Step 2: Copy updated SKILL.md to each sub-repo**

```bash
cp .claude/skills/teammate-workflow/SKILL.md backend/.claude/skills/teammate-workflow/SKILL.md
cp .claude/skills/teammate-workflow/SKILL.md nanoclaw/.claude/skills/teammate-workflow/SKILL.md
cp .claude/skills/teammate-workflow/SKILL.md desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md
```

- [ ] **Step 3: Verify diff is identical (no accidental changes)**

```bash
diff .claude/skills/teammate-workflow/SKILL.md backend/.claude/skills/teammate-workflow/SKILL.md
diff .claude/skills/teammate-workflow/SKILL.md nanoclaw/.claude/skills/teammate-workflow/SKILL.md
diff .claude/skills/teammate-workflow/SKILL.md desktop-homunculus/.claude/skills/teammate-workflow/SKILL.md
```

Expected: no output (files are identical).

- [ ] **Step 4: Commit in each sub-repo**

```bash
cd backend && git add .claude/skills/teammate-workflow/SKILL.md && git commit -m "feat(workflow): sync contract review protocol to teammate-workflow" && cd ..
cd nanoclaw && git add .claude/skills/teammate-workflow/SKILL.md && git commit -m "feat(workflow): sync contract review protocol to teammate-workflow" && cd ..
cd desktop-homunculus && git add .claude/skills/teammate-workflow/SKILL.md && git commit -m "feat(workflow): sync contract review protocol to teammate-workflow" && cd ..
```

- [ ] **Step 5: Commit workspace root**

```bash
git add .claude/skills/teammate-workflow/SKILL.md
git commit -m "feat(workflow): sync contract review protocol to teammate-workflow"
```

---

## Self-Review

After completing all tasks, verify:

- [ ] **Spec coverage check**
  - Detection criteria → Task 1 Step 3a ✓
  - Message protocol (REQUEST/RESPONSE format) → Task 1 Step 3a ✓
  - Soft blocking (2 rounds → escalate) → Task 1 Step 3a ✓
  - Named teammates for SendMessage routing → Task 2 ✓
  - Graduation path (docs/contracts/) → Task 1 (APPROVED section) + Task 3 ✓
  - Sub-repo sync → Task 4 ✓

- [ ] **No placeholder scan**: No TBD/TODO in any written content

- [ ] **Consistency check**: Team names (`backend-team`, `nanoclaw-team`, `dh-team`) are consistent across Task 1 and Task 2
