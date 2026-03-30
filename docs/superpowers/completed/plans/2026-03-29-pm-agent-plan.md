# PM Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a PM Agent to the always-on Agent Team. PM owns Phase 1–3 (brainstorm → spec → plan → teammate review loop). Lead Agent receives SPEC_READY and executes Phase 4–7 only.

**Architecture:** New `pm-workflow/SKILL.md`. Teammate-workflow gains SPEC_REVIEW_REQUEST handling. Planning-workflow updated so Lead starts from SPEC_READY.

**Spec:** `docs/superpowers/specs/2026-03-29-pm-agent-design.md`

**Depends on:** `docs/superpowers/plans/2026-03-29-agent-teams-workflow-redesign-plan.md` must be completed first (teammate-workflow rewrite is a prerequisite).

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `.claude/skills/pm-workflow/SKILL.md` | Create | Full PM Agent workflow |
| `.claude/skills/planning-workflow/SKILL.md` | Modify | Lead starts from SPEC_READY; Phase 1–3 delegated to PM |
| `.claude/skills/teammate-workflow/SKILL.md` | Modify | Add SPEC_REVIEW_REQUEST handling section |

---

## Task 1: Create pm-workflow/SKILL.md

**Files:**
- Create: `.claude/skills/pm-workflow/SKILL.md`

- [ ] **Step 1: Create the file**

Write `.claude/skills/pm-workflow/SKILL.md`:

```markdown
# PM Workflow

You are the PM Agent in the DesktopMatePlus Agent Team.
Your job: turn user feature ideas into approved specs that are ready for Lead Agent execution.

You own **Phase 1–3 only**. Never create TaskCreate entries or direct teammates to implement.

---

## Step 1 — Brainstorm with user

Invoke `superpowers:brainstorming` with the feature description.

Before brainstorming, query cq for known pitfalls:
```
mcp: cq.query(domain=["nanoclaw", "backend"])   ← adjust to feature domain
```

Brainstorm output must include:
- User intent and goals
- Constraints and edge cases
- Which repos are affected (`[target: backend/]`, `[target: nanoclaw/]`, `[target: desktop-homunculus/]`)
- Open questions resolved

Save spec to: `docs/superpowers/specs/{YYYY-MM-DD}-{feature}-design.md`
Commit the spec: `git add docs/superpowers/specs/... && git commit -m "docs(spec): add {feature} design"`

---

## Step 2 — Write Plans.md tasks

Add `cc:TODO` tasks to Plans.md with these fields per task:

```markdown
- [ ] **{TASK-ID}: {description}** — {one-line summary}. DoD: {acceptance criteria}. Depends: {task-id or none}. [target: {repo}/]
```

Rules:
- Every task must have a DoD (definition of done)
- Dependencies must reference valid task IDs
- Only include repos that are actually affected

---

## Step 3 — Spec Review Loop

Send SPEC_REVIEW_REQUEST via SendMessage to each teammate whose repo has tasks in Plans.md.

**Request format:**
```
SPEC_REVIEW_REQUEST
from: pm-agent
to: {team-name}
round: {N}
spec: docs/superpowers/specs/{date}-{feature}-design.md
plans: Plans.md (cc:TODO section)
question: "Is this spec feasible from {repo}/ perspective? Any constraints or conflicts?"
```

Only send to teams with matching `[target: {repo}/]` tasks. Do not send to teams with no affected tasks.

**Wait for all SPEC_REVIEW_RESPONSE messages.**

**If all APPROVED:** proceed to Step 4.

**If any CHANGES_REQUESTED:**
1. Read each `concerns` entry carefully
2. Update `spec.md` and/or Plans.md to address the concerns
3. Report the changes to the user and get confirmation before re-sending
4. Re-send SPEC_REVIEW_REQUEST (increment `round`) **only to teams that returned CHANGES_REQUESTED**
5. Repeat until all teams have returned APPROVED

---

## Step 4 — Submit to Lead Agent

Once all relevant teammates have returned APPROVED, send via SendMessage:

```
SPEC_READY
from: pm-agent
spec: docs/superpowers/specs/{date}-{feature}-design.md
plans: Plans.md
approved-by: {team-name}, {team-name}, ...
notes: (summary of major concerns addressed — omit if no changes were made)
```

Commit any spec/Plans.md changes made during the review loop:
```bash
git add docs/superpowers/specs/... Plans.md
git commit -m "docs(spec): update {feature} spec after teammate review"
```

Your work for this feature is done. Lead Agent takes over.

---

## What PM Agent Does NOT Do

- Create tasks in shared task list — Lead's job
- Tell teammates to start implementing — Lead's job
- Respond to CONTRACT_REVIEW_REQUEST — between implementing teammates only
- Merge worktrees or manage branches
```

- [ ] **Step 2: Verify file is well-formed**

Read `.claude/skills/pm-workflow/SKILL.md` and confirm:
- Step 1 invokes `superpowers:brainstorming`
- Step 3 includes round tracking and re-send logic
- Step 4 sends SPEC_READY to Lead only after all APPROVED
- "What PM Agent Does NOT Do" section is present

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/pm-workflow/SKILL.md
git commit -m "feat(workflow): add pm-workflow skill for PM Agent"
```

---

## Task 2: Add SPEC_REVIEW_REQUEST handling to teammate-workflow

**Files:**
- Modify: `.claude/skills/teammate-workflow/SKILL.md`

- [ ] **Step 1: Locate insertion point**

Open `.claude/skills/teammate-workflow/SKILL.md`. Find the `## Golden Principles` section near the bottom.

- [ ] **Step 2: Insert SPEC_REVIEW_REQUEST section before Golden Principles**

Insert this block immediately before `## Golden Principles`:

```markdown
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
```

- [ ] **Step 3: Verify**

Read the file and confirm:
- New section appears before `## Golden Principles`
- Response format includes `verdict` and `concerns`
- "Out of scope" guidance is present

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/teammate-workflow/SKILL.md
git commit -m "feat(workflow): add SPEC_REVIEW_REQUEST handling to teammate-workflow"
```

---

## Task 3: Update planning-workflow for Lead Agent entry point

**Files:**
- Modify: `.claude/skills/planning-workflow/SKILL.md`

- [ ] **Step 1: Add PM Agent handoff note at the top of the workflow overview**

Find the workflow overview block (the one with Phase 1–9 listed). Add this note immediately before the Phase 1 line:

```markdown
> **PM Agent handles Phase 1–3.** Lead Agent enters at Phase 4 upon receiving `SPEC_READY` from PM Agent. If you are the Lead Agent, skip to Phase 4.
```

- [ ] **Step 2: Update Phase 1 section header**

Find `## Phase 1 — Brainstorm` and replace its opening paragraph with:

```markdown
## Phase 1 — Brainstorm (PM Agent only)

**Lead Agent skips this phase.** PM Agent invokes `superpowers:brainstorming` and drives the spec through Phase 1–3 independently.

Lead Agent waits for `SPEC_READY` from PM Agent before proceeding to Phase 4.
```

- [ ] **Step 3: Add SPEC_READY handling before Phase 4**

Find `## Phase 4 — Distribute`. Insert this block immediately before it:

```markdown
## Lead Agent Entry Point — Receiving SPEC_READY

When Lead Agent receives `SPEC_READY` from PM Agent:

1. Read the referenced spec file
2. Read Plans.md `cc:TODO` tasks — these are already reviewed and approved
3. Proceed directly to Phase 4

```
SPEC_READY received:
spec: docs/superpowers/specs/{date}-{feature}-design.md
plans: Plans.md
approved-by: backend-team, nanoclaw-team
```
```

- [ ] **Step 4: Update Quick Reference**

Find the Quick Reference section. Replace the first line:

Old:
```
0. cq.query(domain=[...])                        ← check known pitfalls first
1. Skill: superpowers:brainstorming
2. Skill: claude-code-harness:harness-plan   ← brainstorm output as spec
3. Skill: claude-code-harness:harness-review  ← iterate until approved
4. Mirror tasks to sub-repo Plans.md + commit Plans.md in each sub-repo
```

New:
```
[PM Agent — Phase 1–3]
0. cq.query(domain=[...])                        ← check known pitfalls first
1. Skill: superpowers:brainstorming
2. Write spec.md + Plans.md cc:TODO tasks
3. SendMessage SPEC_REVIEW_REQUEST → teammates → loop until all APPROVED
4. SendMessage SPEC_READY → Lead Agent

[Lead Agent — Phase 4–9]
4. TaskCreate for each cc:TODO task (shared task list)
```

- [ ] **Step 5: Verify**

Read the file and confirm:
- Phase 1 section is marked "PM Agent only"
- Lead Agent Entry Point section exists before Phase 4
- Quick Reference distinguishes PM Agent and Lead Agent phases

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/planning-workflow/SKILL.md
git commit -m "feat(workflow): update planning-workflow — Lead enters at Phase 4 via SPEC_READY"
```

---

## Self-Review

- [ ] **Spec coverage check**
  - PM Agent workflow (brainstorm → spec → Plans.md) → Task 1 ✓
  - SPEC_REVIEW_REQUEST loop with round tracking → Task 1 Step 3 ✓
  - SPEC_READY handoff to Lead → Task 1 Step 4 ✓
  - Teammate SPEC_REVIEW_REQUEST handling → Task 2 ✓
  - Lead starts from SPEC_READY → Task 3 ✓

- [ ] **No placeholder scan**: No TBD/TODO in written content

- [ ] **Consistency check**:
  - `SPEC_REVIEW_REQUEST` format in pm-workflow matches handling in teammate-workflow
  - `SPEC_READY` format in pm-workflow matches Lead entry point in planning-workflow
  - Team names (`pm-agent`, `lead-agent`, `backend-team`, `nanoclaw-team`, `dh-team`) consistent across all three files
