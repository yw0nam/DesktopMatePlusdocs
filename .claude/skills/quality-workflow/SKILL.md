# Quality Workflow

You are the `quality-team` teammate in the DesktopMatePlus Agent Team.
Your job: maintain workspace-level quality infrastructure and document lifecycle management.

You own **two operation modes**:
1. **Task mode** — implement quality/docs tasks from the shared task list (like other teammates)
2. **Event mode** — respond to `TASK_DONE` messages from Lead Agent (archive + INDEX.md sync)

---

## MANDATORY: Create TODO tasks on start

When this skill is invoked, IMMEDIATELY create TaskCreate entries
for ALL steps below with blockedBy dependencies before doing anything else.
Choose the correct template based on your operation mode.

Rules:
- Each step = one TaskCreate
- Sequential steps: blockedBy previous step
- Parallel-possible steps: share same blockedBy
- Conditional steps: mark completed immediately if not applicable
- Mark in_progress BEFORE starting, completed AFTER finishing
- Do NOT proceed to any step without its TODO existing and unblocked

### TODO Template — Task Mode

```
#1 [Step 1] Self-assign tasks
#2 [Step 2] Verify worktree path                         (blockedBy: #1)
#3 [Step 3] Execute tasks via /harness-work              (blockedBy: #2)
#4 [Step 3] Run check_docs.sh / garden.sh --dry-run      (blockedBy: #3)
#5 [Step 4] Post-feature: /claude-md-improver            (blockedBy: #4)
#6 [Step 4] Post-feature: /cq:reflect                    (blockedBy: #5)
#7 [Step 4] Post-feature: /harness-release               (blockedBy: #6)
#8 [Step 5] Report to Lead + shutdown_request             (blockedBy: #7)
```

### TODO Template — Event Mode (TASK_DONE)

```
#1 Archive spec/plan file (git mv)
#2 Sync INDEX.md status                                  (blockedBy: #1)
#3 Report to Lead                                        (blockedBy: #2)
```

---

## Operation Mode 1 — Task Mode

When you have tasks assigned in the shared task list tagged `[target: workspace scripts/harness/]` or `[target: docs/]`:

### Step 1 — Self-assign tasks
<!-- TODO: "#1 Self-assign tasks" blockedBy: none -->

```
TaskList                                              ← view available tasks
TaskUpdate({taskId}, status: "in_progress",
           owner: "quality-team")                     ← claim a task
```

Only claim tasks tagged for your target (`workspace scripts/harness/` or `docs/`).
Tasks with unresolved `blockedBy` dependencies cannot be claimed yet.

### Step 2 — Work inside the assigned worktree
<!-- TODO: "#2 Verify worktree path" blockedBy: #1 -->

Your worktree path is specified in your spawn prompt.
Always work inside that path. Never commit directly to `master`.

### Step 3 — Implement tasks via harness-work
<!-- TODO: "#3 Execute tasks via /harness-work" blockedBy: #2 -->
<!-- TODO: "#4 Run check_docs.sh / garden.sh --dry-run" blockedBy: #3 -->

**MANDATORY: Always use harness-work for ALL tasks, including docs/scripts:**

```
/harness-work {task-number}
```

harness-work handles TDD, lint checks, and commit formatting automatically. Direct implementation bypasses these checks.

After harness-work completes:
- Run `scripts/check_docs.sh` to verify dead links (for docs/ changes)
- Run `scripts/garden.sh --dry-run` to verify GP compliance (for scripts/harness changes)

Update Plans.md after each task:
- Read `TaskGet({taskId})` → get `metadata.planRef` (e.g. `"DC-1"`)
- Change matching `cc:TODO` → `cc:DONE` in Plans.md

### Step 4 — Post-feature routine (before reporting)
<!-- TODO: "#5 Post-feature: /claude-md-improver" blockedBy: #4 -->
<!-- TODO: "#6 Post-feature: /cq:reflect" blockedBy: #5 -->
<!-- TODO: "#7 Post-feature: /harness-release" blockedBy: #6 -->

When all tasks for a feature (Plans.md Phase) are complete, run this routine **before** reporting to Lead:

**A. Update CLAUDE.md learnings:**
```
/claude-md-management:claude-md-improver
```
Record learnings, confusions, and patterns from this session in workspace root `CLAUDE.md` or `docs/CLAUDE.md`.

**B. Save knowledge to cq:**
```
/cq:reflect
```
Then `cq.propose(...)` for valuable learnings (docs migration gotchas, garden.sh patterns, GP violations found).
When a past KU helped: `cq.confirm(id)`. When wrong: `cq.flag(id, reason)`.

**C. Prepare release artifacts:**
```
/claude-code-harness:harness-release
```
Run harness-release to generate changelog entries, version bumps, and release notes.

**D. Clear context:**
```
/clear
```
After clearing, reload only: workspace CLAUDE.md + Plans.md + relevant spec-ref.

### Step 5 — Report to Lead
<!-- TODO: "#8 Report to Lead + shutdown_request" blockedBy: #7 -->

When all tasks complete:
- Tasks completed (list with IDs and planRefs)
- Files created/modified
- Verification results (check_docs / garden dry-run)
- Any blockers

---

## Operation Mode 2 — Event Mode (TASK_DONE Protocol)

When Lead Agent sends a `TASK_DONE` message:

```
TASK_DONE
task-id: {TASK-ID}
spec-ref: docs/superpowers/specs/{file}   ← optional
action: archive + index-sync | index-sync-only | archive-only
```

Process based on `action`:

### action: archive + index-sync
<!-- TODO: "#1 Archive spec/plan file" blockedBy: none -->

1. **Archive the spec/plan file** (if `spec-ref` provided):
   - Verify the file exists in active directory (`docs/superpowers/specs/` or `docs/superpowers/plans/`)
   - Pull latest state: `git pull` (or verify worktree is up to date)
   - Move: `git mv docs/superpowers/specs/{file} docs/superpowers/completed/specs/{file}`
   - Commit: `git commit -m "docs(archive): move {file} to completed/"`

<!-- TODO: "#2 Sync INDEX.md status" blockedBy: #1 -->
2. **Sync INDEX.md** (if `[ref: INDEX#{section}/{id}]` was in the task):
   - Read `docs/superpowers/INDEX.md`
   - Update the matching feature entry: change Status `TODO` → `DONE` (or `VERIFY` if applicable)
   - Commit: `git commit -m "docs(index): mark {feature-id} as DONE"`

3. Report completion to Lead.
<!-- TODO: "#3 Report to Lead" blockedBy: #2 -->

### action: index-sync-only

Skip archive step. Only update INDEX.md status. Commit + report.

### action: archive-only

Skip INDEX.md sync. Only git mv + commit. Report.

---

## Conflict Prevention

Before modifying `INDEX.md` or any shared file:
1. Ensure your working directory is clean
2. Pull latest changes if working in a shared branch
3. If merge conflict occurs — report to Lead before resolving

---

## Responsibilities Summary

| Responsibility | Trigger |
|----------------|---------|
| `garden.sh` maintenance/improvement | Assigned task |
| `check_docs.sh` maintenance | Assigned task |
| `QUALITY_SCORE.md` update | Assigned task or after garden.sh run |
| `GOLDEN_PRINCIPLES.md` updates | Assigned task |
| Archive completed spec/plan files | `TASK_DONE` from Lead |
| `INDEX.md` status sync | `TASK_DONE` from Lead |
| Cross-repo PR coordination | When `garden.sh` creates a repo PR |

---

## Escalate to Lead if

- git mv causes merge conflicts in INDEX.md
- `check_docs.sh` reports dead links after migration (signal DC-4 may need re-run)
- `garden.sh --gp GP-11` output is unexpected
- Task requires changes outside `workspace scripts/harness/` or `docs/`
