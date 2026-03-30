# PM Agent Design

**Date**: 2026-03-29
**Status**: Approved

---

## Problem

The Lead Agent currently handles both planning (Phase 1–3: brainstorm → spec → plan) and execution coordination (Phase 4–7: distribute → execute → review). This creates two issues:

1. **No parallel spec work**: Lead cannot design the next feature while executing the current one.
2. **No stakeholder review before execution**: Specs go from Lead to implementation without asking the implementing teams whether the spec is actually feasible.

---

## Solution

Add a **PM Agent** as a permanent Agent Team member. PM owns Phase 1–3 (spec design + planning), collects feasibility approval from all relevant teammates, then hands off to Lead Agent. Lead Agent owns Phase 4–7 only.

---

## Team Structure

```
[Always-on Agent Team]

pm-agent         ← NEW: spec design, planning, teammate review loop
lead-agent       ← UPDATED: receives SPEC_READY, executes Phase 4–7 only
backend-team     ← UPDATED: handles SPEC_REVIEW_REQUEST + task execution
nanoclaw-team    ← UPDATED: handles SPEC_REVIEW_REQUEST + task execution
dh-team          ← UPDATED: handles SPEC_REVIEW_REQUEST + task execution
```

---

## PM Agent Workflow

```
User brings feature idea
        ↓
PM: superpowers:brainstorming with user
        ↓
PM: write spec.md (docs/superpowers/specs/{date}-{feature}-design.md)
        ↓
PM: write Plans.md (cc:TODO tasks with [target:] markers)
        ↓
PM: SendMessage SPEC_REVIEW_REQUEST → relevant teammates (round 1)
        ↓
Collect SPEC_REVIEW_RESPONSE from each teammate
    All APPROVED?
        YES → SendMessage SPEC_READY → Lead Agent
        NO  → apply CHANGES_REQUESTED concerns
              → update spec.md + Plans.md
              → report changes to user + get confirmation
              → SendMessage SPEC_REVIEW_REQUEST (round N+1)
              → repeat until all APPROVED
```

---

## Message Protocol

### PM → Teammate: SPEC_REVIEW_REQUEST

```
SPEC_REVIEW_REQUEST
from: pm-agent
to: {team-name}
round: {N}
spec: docs/superpowers/specs/{date}-{feature}-design.md
plans: Plans.md (cc:TODO section)
question: "Is this spec feasible from {repo}/ perspective? Any constraints or conflicts?"
```

Only send to teammates whose repo has `[target: {repo}/]` tasks in Plans.md.

### Teammate → PM: SPEC_REVIEW_RESPONSE

```
SPEC_REVIEW_RESPONSE
from: {team-name}
verdict: APPROVED | CHANGES_REQUESTED
concerns:
  - (if CHANGES_REQUESTED) specific problem + suggested fix
```

**Review criteria for teammates:**
- Implementation feasibility within their repo
- Conflicts with existing constraints (GP violations, architectural rules)
- Missing dependencies or interface gaps

**Out of scope for teammates:** design taste, style preferences, unrelated improvements.

### PM → Lead: SPEC_READY

Sent only after all relevant teammates return APPROVED.

```
SPEC_READY
from: pm-agent
spec: docs/superpowers/specs/{date}-{feature}-design.md
plans: Plans.md
approved-by: {team-name}, {team-name}, ...
notes: (summary of major concerns addressed during review loop)
```

---

## Lead Agent Changes

Lead no longer runs Phase 1–3. Upon receiving `SPEC_READY`:

1. Read the referenced spec and Plans.md
2. Proceed directly to Phase 4 (TaskCreate for shared task list)
3. Execute Phase 4–7 as before

---

## Teammate Changes

Teammates gain one new responsibility: responding to `SPEC_REVIEW_REQUEST` from PM Agent.

When `SPEC_REVIEW_REQUEST` arrives via SendMessage:
1. Pause current task briefly
2. Read `spec` and Plans.md tasks tagged `[target: my-repo/]`
3. Assess: implementation feasibility + constraint conflicts only
4. Respond immediately with `SPEC_REVIEW_RESPONSE`
5. Resume current task

---

## What Changes

| File | Change |
|------|--------|
| `.claude/skills/pm-workflow/SKILL.md` | **CREATE** — full PM Agent workflow |
| `.claude/skills/planning-workflow/SKILL.md` | **MODIFY** — Phase 1–3 delegated to PM Agent; Lead starts from SPEC_READY |
| `.claude/skills/teammate-workflow/SKILL.md` | **MODIFY** — add SPEC_REVIEW_REQUEST handling section |

---

## Success Criteria

- PM Agent completes spec + Plans.md and sends SPEC_REVIEW_REQUEST to relevant teammates without involving Lead Agent
- Teammates respond with APPROVED or CHANGES_REQUESTED with specific concerns
- PM loops until all teammates approve, then sends SPEC_READY to Lead
- Lead Agent starts Phase 4 only after receiving SPEC_READY — never before
- Teammates can handle SPEC_REVIEW_REQUEST mid-execution without losing task context
