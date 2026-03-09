> **[HOLD]** Multi-Persona Orchestrator(Task 1)는 nice-to-have로 분류되어 HOLD 처리됨.
> Task 2(E2E 테스트), Task 3(mock script), Task 4(INDEX 업데이트)는 현재 플랜([2026-03-09-e2e-and-p1-plan.md](./2026-03-09-e2e-and-p1-plan.md))으로 이전됨.
> 이 문서는 참고용으로만 보존한다.

# Phase 2: Multi-Persona Orchestrator + E2E Verification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** (1) Add Multi-Persona Orchestrator via NanoClaw skill packages. (2) Verify FastAPI callback flow using existing tests.

**Architecture:** Pure Prompt Orchestrator via skill packages — all NanoClaw changes applied through `apply-skill.ts`. HTTP Channel status vocab (`'done'`) is already correct in `add-http` skill. FastAPI tests already exist; run them to verify.

**Tech Stack:** TypeScript (NanoClaw skill packages), Markdown (CLAUDE.md/SKILL.md), Bash (npm test, pytest)

**NanoClaw Convention:** After each skill apply + test, revert all modified source files and commit only the skill package (reverse code injection — see CLAUDE.md).

---

### Task 1: Create `add-multi-persona-orchestrator` Skill Package

**Files:**

- Create: `nanoclaw/.claude/skills/add-multi-persona-orchestrator/SKILL.md`
- Create: `nanoclaw/.claude/skills/add-multi-persona-orchestrator/manifest.yaml`
- Create: `nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/groups/main/CLAUDE.md`
- Create: `nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/dev-agent/SKILL.md`
- Create: `nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/reviewer-agent/SKILL.md`
- Create: `nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/pm-agent/SKILL.md`

**Step 1: Create skill directory structure**

```bash
mkdir -p nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/groups/main
mkdir -p nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/dev-agent
mkdir -p nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/reviewer-agent
mkdir -p nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/pm-agent
```

**Step 2: Create SKILL.md**

Create `nanoclaw/.claude/skills/add-multi-persona-orchestrator/SKILL.md`:

```markdown
---
name: add-multi-persona-orchestrator
description: Use when NanoClaw's Main Agent needs to orchestrate DevAgent, ReviewerAgent, and PMAgent via Claude Agent Teams (TeamCreate). Adds Orchestrator instructions to group CLAUDE.md and Communication Rules to each Persona SKILL.md.
---

# Multi-Persona Orchestrator Skill

## Overview
Configures the Main Agent as an Orchestrator that:
1. Receives task delegations from FastAPI Director
2. Spawns Persona Sub-agents via TeamCreate
3. Synthesizes results and sends final callback

## Sender Model
ipc.ts drops the sender field, so Persona attribution is done via text:
Orchestrator summary explicitly names which Persona contributed what.
Full IPC sender support is deferred to Approach B (separate skill).

## Sub-agent send_message rule
Sub-agents MUST NOT call mcp__nanoclaw__send_message — only the Orchestrator
sends the final result to prevent spurious intermediate callbacks to FastAPI.
```

**Step 3: Create manifest.yaml**

Create `nanoclaw/.claude/skills/add-multi-persona-orchestrator/manifest.yaml`:

```yaml
skill: add-multi-persona-orchestrator
version: 1.0.0
description: "Adds Multi-Persona Orchestrator behavior to Main Agent and Communication Rules to Persona SKILL.md files"
core_version: 0.1.0

adds: []
modifies:
  - groups/main/CLAUDE.md
  - container/skills/dev-agent/SKILL.md
  - container/skills/reviewer-agent/SKILL.md
  - container/skills/pm-agent/SKILL.md

structured:
  npm_dependencies: {}

conflicts: []
depends: []

test: "npm test"
```

**Step 4: Build modify/ files — copy current then add content**

```bash
cp nanoclaw/groups/main/CLAUDE.md \
   nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/groups/main/CLAUDE.md

cp nanoclaw/container/skills/dev-agent/SKILL.md \
   nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/dev-agent/SKILL.md

cp nanoclaw/container/skills/reviewer-agent/SKILL.md \
   nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/reviewer-agent/SKILL.md

cp nanoclaw/container/skills/pm-agent/SKILL.md \
   nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/pm-agent/SKILL.md
```

**Step 5: Append Orchestrator section to modify/groups/main/CLAUDE.md**

Append to the end of `modify/groups/main/CLAUDE.md`:

```markdown

---

## Task Delegation (Orchestrator Mode)

When you receive a message from FastAPI Director (recognized by format:
"Task: ...\nTask ID: ...\nSession ID: ..."), switch to Orchestrator mode:

### Step 1: Analyze the Task

- Determine which Personas are needed: DevAgent (coding), ReviewerAgent (review), PMAgent (reporting)
- Decide execution order:
  - **Sequential**: dependent tasks (e.g., DevAgent writes → ReviewerAgent reviews)
  - **Parallel**: independent tasks
- Not every task needs all Personas — use judgment

### Step 2: Spawn Sub-agents via TeamCreate

For each Persona, use TeamCreate with this prompt structure:

    You are {PersonaName}. Read and follow your skill file:
    /home/node/.claude/skills/{persona-dir}/SKILL.md

    Task: {task description from the delegation message}
    Task ID: {task_id}

    {If sequential: include preceding Persona's output here}

    RULES:
    - Do NOT use mcp__nanoclaw__send_message. Return your result to me directly.
    - Follow the Output Format defined in your SKILL.md.

Persona Directory Mapping:
| Persona       | Directory      | Use For                           |
|---------------|----------------|-----------------------------------|
| DevAgent      | dev-agent      | Writing/modifying/testing code    |
| ReviewerAgent | reviewer-agent | Code review, bug detection        |
| PMAgent       | pm-agent       | Summarizing work, reports         |

### Step 3: Synthesize Results

After all Sub-agents complete:
1. Combine their outputs into a final summary
2. Attribute results explicitly: e.g. "DevAgent: [changes], ReviewerAgent: [verdict]"
3. Include the Task ID for traceability

### Step 4: Deliver Final Result

Send via `mcp__nanoclaw__send_message(text: final_summary)`.
This triggers the HTTP Channel egress → POST to FastAPI callback_url.

**IMPORTANT**:
- Only YOU (Main Agent / Orchestrator) may call `mcp__nanoclaw__send_message` for the final result
- Sub-agents MUST NOT call `send_message` — return results to me directly
```

**Step 6: Append Communication Rules to each Persona SKILL.md**

Append to `modify/container/skills/dev-agent/SKILL.md`:

```markdown

## Communication Rules (Sub-agent Mode)

When running as a sub-agent spawned by an orchestrator:
- Do NOT use `mcp__nanoclaw__send_message` directly — return results to the orchestrator
- Follow the Output Format section for structured results
- If the task requires file creation, write to `/workspace/group/` and reference paths in output
- Keep output concise — the orchestrator synthesizes across all Personas
```

Append the same block to `modify/container/skills/reviewer-agent/SKILL.md` and
`modify/container/skills/pm-agent/SKILL.md`.

**Step 7: Verify modify/ files look correct**

```bash
tail -20 nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/groups/main/CLAUDE.md
tail -10 nanoclaw/.claude/skills/add-multi-persona-orchestrator/modify/container/skills/dev-agent/SKILL.md
```

Expected: Newly added sections visible at end of each file.

**Step 8: Apply the skill**

```bash
cd nanoclaw && npx tsx scripts/apply-skill.ts .claude/skills/add-multi-persona-orchestrator
```

Expected: Skill applied cleanly (all 4 files are markdown; no merge conflicts expected on fresh install).

**Step 9: Verify applied files**

```bash
grep -n "Orchestrator Mode" nanoclaw/groups/main/CLAUDE.md
grep -n "Communication Rules" nanoclaw/container/skills/dev-agent/SKILL.md
grep -n "Communication Rules" nanoclaw/container/skills/reviewer-agent/SKILL.md
grep -n "Communication Rules" nanoclaw/container/skills/pm-agent/SKILL.md
```

Expected: Each grep returns a line number showing the section was added.

**Step 10: Run tests**

```bash
cd nanoclaw && npm test
```

Expected: All tests PASS (no TypeScript source changed, only markdown files).

**Step 11: Revert applied files, commit skill package only**

Per CLAUDE.md reverse code injection rule — revert all applied source files, commit only the skill:

```bash
git checkout -- nanoclaw/groups/main/CLAUDE.md \
                nanoclaw/container/skills/dev-agent/SKILL.md \
                nanoclaw/container/skills/reviewer-agent/SKILL.md \
                nanoclaw/container/skills/pm-agent/SKILL.md
git add nanoclaw/.claude/skills/add-multi-persona-orchestrator/
git commit -m "feat(orchestrator): add multi-persona orchestrator skill package"
```

---

### Task 2: Verify FastAPI Callback Tests (data_flow/01 mock 검증)

**Background:** `test_delegation_e2e.py` and `test_callback_api.py` already cover the
delegation round-trip. No new tests needed — just run them green.

**Step 1: Run existing tests**

```bash
cd backend && uv run pytest tests/api/test_delegation_e2e.py tests/api/test_callback_api.py -v
```

Expected output — all passing:

```
tests/api/test_delegation_e2e.py::TestDelegationFlowE2E::test_full_delegation_round_trip PASSED
tests/api/test_delegation_e2e.py::TestDelegationFlowE2E::test_delegation_with_nanoclaw_failure PASSED
tests/api/test_delegation_e2e.py::TestDelegationFlowE2E::test_callback_for_failed_task PASSED
tests/api/test_callback_api.py::TestNanoClawCallback::test_callback_returns_503_when_stm_not_initialized PASSED
tests/api/test_callback_api.py::TestNanoClawCallback::test_callback_returns_404_for_unknown_task PASSED
tests/api/test_callback_api.py::TestNanoClawCallback::test_callback_updates_task_status_on_success PASSED
...
```

If any test fails, investigate before proceeding.

**Step 2: Commit (if any incidental fixes were needed)**

```bash
git commit -m "test(delegation): verify existing E2E tests pass for mock delegation flow"
```

---

### Task 3: Add Mock Callback Shell Script

**Files:**

- Create: `backend/scripts/mock_callback.sh`

**Note:** The script requires a real pending task_id from the STM — it cannot invent one.
Usage instructions are embedded in the script.

**Step 1: Create the script**

Create `backend/scripts/mock_callback.sh`:

```bash
#!/usr/bin/env bash
# mock_callback.sh — Manually simulate a NanoClaw callback to FastAPI for debugging.
#
# PREREQUISITE: You must have a real pending task in STM.
# How to get one:
#   1. Start FastAPI: cd backend && uv run uvicorn src.main:app
#   2. Connect via WebSocket and send a message that triggers DelegateTaskTool
#   3. Copy the task_id from the FastAPI logs: "Task record: task_id=..."
#   4. Then run this script with that task_id and session_id
#
# Usage:
#   ./scripts/mock_callback.sh <task_id> <session_id> [done|failed]
#
# Example:
#   ./scripts/mock_callback.sh abc-123 session-xyz done

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <task_id> <session_id> [done|failed]"
  echo ""
  echo "PREREQUISITE: task_id must exist in session STM pending_tasks."
  echo "Get it from FastAPI logs after triggering DelegateTaskTool."
  exit 1
fi

TASK_ID="$1"
SESSION_ID="$2"
STATUS="${3:-done}"
BASE_URL="${BACKEND_URL:-http://localhost:8000}"

if [ "$STATUS" = "done" ]; then
  SUMMARY="코드 리뷰 완료 — 보안 결함 1건 발견 (line 45). 수정 권장."
else
  SUMMARY="NanoClaw 컨테이너 타임아웃으로 작업 실패."
fi

echo "Sending $STATUS callback to $BASE_URL/v1/callback/nanoclaw/$SESSION_ID"
echo "  task_id:  $TASK_ID"
echo "  summary:  $SUMMARY"
echo ""

curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X POST "$BASE_URL/v1/callback/nanoclaw/$SESSION_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"task_id\": \"$TASK_ID\",
    \"status\": \"$STATUS\",
    \"summary\": \"$SUMMARY\"
  }"
```

**Step 2: Make executable**

```bash
chmod +x backend/scripts/mock_callback.sh
```

**Step 3: Commit**

```bash
git add backend/scripts/mock_callback.sh
git commit -m "scripts: add mock callback script with correct usage instructions"
```

---

### Task 4: Update PRD INDEX.md

**Files:**

- Modify: `docs/prds/feature/INDEX.md`

**Step 1: Update statuses**

In `docs/prds/feature/INDEX.md`:

- `nanoclaw/03`: `TODO` → `DONE`
- `data_flow/01`: keep `TODO` (full E2E with real NanoClaw not yet verified)

Add a note under data_flow/01:

```
| 01 | [Delegation Flow E2E](./data_flow/task-01-delegation-flow.md) | P0 | TODO | mock 검증 완료 (test_delegation_e2e.py Green). 전체 E2E는 NanoClaw 기동 후 검증 필요. |
```

**Step 2: Commit**

```bash
git add docs/prds/feature/INDEX.md
git commit -m "docs: mark nanoclaw/03 DONE, update data_flow/01 note"
```

---

## Task Dependency Graph

```
Task 1 (add-multi-persona-orchestrator skill) ──→ Task 4 (INDEX)
Task 2 (verify existing E2E tests) ──→ Task 4
Task 3 (mock script) ──→ Task 4 (independent)
```

Tasks 1, 2, 3 are independent. Task 4 is last.
