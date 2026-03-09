# Phase 2: Multi-Persona Orchestrator + E2E Mock Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable NanoClaw's Main Agent to orchestrate Persona Sub-agents (DevAgent, ReviewerAgent, PMAgent) via TeamCreate, and verify FastAPI callback flow with mock tests.

**Architecture:** Pure Prompt Orchestrator — no NanoClaw source code changes. Group CLAUDE.md defines orchestrator behavior, Persona SKILL.md files define Sub-agent communication rules. FastAPI callback already implemented; we add mock tests only.

**Tech Stack:** Markdown (CLAUDE.md/SKILL.md), Python (pytest, httpx), Bash (curl scripts)

---

### Task 1: Update Persona SKILL.md — DevAgent Communication Rules

**Files:**

- Modify: `nanoclaw/container/skills/dev-agent/SKILL.md`

**Step 1: Read current file and verify structure**

Run: `cat nanoclaw/container/skills/dev-agent/SKILL.md`
Expected: Current SKILL.md with Responsibilities, Workflow, Output Format sections.

**Step 2: Add Communication Rules section**

Append to `nanoclaw/container/skills/dev-agent/SKILL.md`:

```markdown

## Communication Rules (Sub-agent Mode)

When running as a sub-agent spawned by an orchestrator:
- Do NOT use `mcp__nanoclaw__send_message` directly — return results to the orchestrator
- Follow the Output Format section for structured results
- If the task requires file creation, write files to `/workspace/group/` and reference paths in your output
- Keep your output concise — the orchestrator will synthesize across all Personas
```

**Step 3: Verify file is well-formed**

Run: `head -30 nanoclaw/container/skills/dev-agent/SKILL.md`
Expected: Original content preserved with new section appended.

**Step 4: Commit**

```bash
git add nanoclaw/container/skills/dev-agent/SKILL.md
git commit -m "docs(persona): add communication rules to DevAgent SKILL.md"
```

---

### Task 2: Update Persona SKILL.md — ReviewerAgent Communication Rules

**Files:**

- Modify: `nanoclaw/container/skills/reviewer-agent/SKILL.md`

**Step 1: Add Communication Rules section**

Append to `nanoclaw/container/skills/reviewer-agent/SKILL.md`:

```markdown

## Communication Rules (Sub-agent Mode)

When running as a sub-agent spawned by an orchestrator:
- Do NOT use `mcp__nanoclaw__send_message` directly — return results to the orchestrator
- Follow the Output Format section for structured results
- If reviewing files, reference them by path so the orchestrator can include links
- Keep your output concise — the orchestrator will synthesize across all Personas
```

**Step 2: Verify file is well-formed**

Run: `head -30 nanoclaw/container/skills/reviewer-agent/SKILL.md`
Expected: Original content preserved with new section appended.

**Step 3: Commit**

```bash
git add nanoclaw/container/skills/reviewer-agent/SKILL.md
git commit -m "docs(persona): add communication rules to ReviewerAgent SKILL.md"
```

---

### Task 3: Update Persona SKILL.md — PMAgent Communication Rules

**Files:**

- Modify: `nanoclaw/container/skills/pm-agent/SKILL.md`

**Step 1: Add Communication Rules section**

Append to `nanoclaw/container/skills/pm-agent/SKILL.md`:

```markdown

## Communication Rules (Sub-agent Mode)

When running as a sub-agent spawned by an orchestrator:
- Do NOT use `mcp__nanoclaw__send_message` directly — return results to the orchestrator
- Follow the Output Format section for structured results
- Keep your output concise — the orchestrator will synthesize across all Personas
```

**Step 2: Verify file is well-formed**

Run: `head -30 nanoclaw/container/skills/pm-agent/SKILL.md`
Expected: Original content preserved with new section appended.

**Step 3: Commit**

```bash
git add nanoclaw/container/skills/pm-agent/SKILL.md
git commit -m "docs(persona): add communication rules to PMAgent SKILL.md"
```

---

### Task 4: Add Orchestrator Section to Group CLAUDE.md

**Files:**

- Modify: `nanoclaw/groups/main/CLAUDE.md`

**Step 1: Read current CLAUDE.md**

Run: `wc -l nanoclaw/groups/main/CLAUDE.md`
Expected: ~247 lines.

**Step 2: Add Task Delegation section**

Append the following to `nanoclaw/groups/main/CLAUDE.md` (before the "Managing Groups" section, after "Container Mounts"):

```markdown

---

## Task Delegation (Orchestrator Mode)

When you receive a message from FastAPI Director (recognized by the format below), switch to Orchestrator mode:

```

Task: <description>
Task ID: <uuid>
Session ID: <session_id>

```

### Step 1: Analyze the Task

- Determine which Personas are needed: DevAgent (coding), ReviewerAgent (review), PMAgent (reporting)
- Decide execution order:
  - **Sequential**: dependent tasks (e.g., DevAgent writes code → ReviewerAgent reviews it)
  - **Parallel**: independent tasks (e.g., DevAgent + PMAgent can work simultaneously)
- Not every task needs all Personas. Use your judgment — simple tasks may only need DevAgent.

### Step 2: Spawn Sub-agents via TeamCreate

For each Persona, use `TeamCreate` with this prompt structure:

```

You are {PersonaName}. Read and follow your skill file at:
/home/node/.claude/skills/{persona-dir}/SKILL.md

Task: {task description from the delegation message}
Task ID: {task_id}

{If sequential: include preceding Persona's results here}

RULES:

- Do NOT use mcp__nanoclaw__send_message. Return your result to me directly.
- Follow the Output Format defined in your SKILL.md.

```

**Persona Directory Mapping:**

| Persona | Directory | Use For |
|---------|-----------|---------|
| DevAgent | `dev-agent` | Writing/modifying code, running tests |
| ReviewerAgent | `reviewer-agent` | Code review, bug detection |
| PMAgent | `pm-agent` | Summarizing work, creating reports |

### Step 3: Collect & Synthesize Results

After all Sub-agents complete:
1. Combine their structured outputs into a single summary
2. Note any conflicts between Persona outputs (e.g., DevAgent says "done" but ReviewerAgent found issues)
3. Include actionable next steps if applicable

### Step 4: Deliver Final Result

Send the synthesized summary using `mcp__nanoclaw__send_message`:

```

mcp__nanoclaw__send_message(text: "<final synthesized summary>", sender: "Orchestrator")

```

This triggers the HTTP Channel egress to POST the result back to the FastAPI callback URL.

**IMPORTANT:**
- Only YOU (the Main Agent / Orchestrator) may call `mcp__nanoclaw__send_message` for the final result
- Sub-agents must NOT call `send_message` — their output goes through you
- Include the Task ID in your summary for traceability
```

**Step 3: Verify section was added correctly**

Run: `grep -n "Orchestrator Mode" nanoclaw/groups/main/CLAUDE.md`
Expected: Line number where section was added.

**Step 4: Commit**

```bash
git add nanoclaw/groups/main/CLAUDE.md
git commit -m "docs(orchestrator): add task delegation section to main group CLAUDE.md"
```

---

### Task 5: Write Callback E2E Test — Happy Path

**Files:**

- Create: `backend/tests/api/test_callback_e2e.py`
- Reference: `backend/src/api/routes/callback.py`, `backend/src/models/callback.py`

**Step 1: Write the test file**

```python
"""E2E mock tests for NanoClaw callback endpoint."""

import pytest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from src.main import app


@pytest.fixture
def client():
    """Create test client."""
    return TestClient(app)


@pytest.fixture
def mock_stm_service():
    """Mock STM service with a pending task."""
    service = MagicMock()
    service.get_session_metadata.return_value = {
        "user_id": "test-user",
        "agent_id": "test-agent",
        "pending_tasks": [
            {
                "task_id": "task-001",
                "description": "Review auth-fix branch",
                "status": "running",
                "created_at": "2026-03-09T00:00:00Z",
            }
        ],
    }
    return service


class TestCallbackHappyPath:
    """Happy path: NanoClaw sends success callback."""

    def test_callback_updates_task_status(self, client, mock_stm_service):
        """Callback with status=done updates task record and injects synthetic message."""
        with patch("src.api.routes.callback.get_stm_service", return_value=mock_stm_service):
            response = client.post(
                "/v1/callback/nanoclaw/session-123",
                json={
                    "task_id": "task-001",
                    "status": "done",
                    "summary": "코드 리뷰 완료 - 보안 결함 1건 발견 (line 45)",
                },
            )

        assert response.status_code == 200
        data = response.json()
        assert data["task_id"] == "task-001"
        assert data["status"] == "done"

        # Verify STM metadata was updated
        mock_stm_service.update_session_metadata.assert_called_once()
        call_args = mock_stm_service.update_session_metadata.call_args
        assert call_args[0][0] == "session-123"
        pending = call_args[0][1]["pending_tasks"]
        assert pending[0]["status"] == "done"

        # Verify synthetic message was injected
        mock_stm_service.add_chat_history.assert_called_once()
        chat_args = mock_stm_service.add_chat_history.call_args
        assert chat_args[1]["session_id"] == "session-123"
        messages = chat_args[1]["messages"]
        assert len(messages) == 1
        assert "[TaskResult:task-001]" in messages[0].content


class TestCallbackFailurePath:
    """Failure path: NanoClaw sends failed callback."""

    def test_callback_handles_failure(self, client, mock_stm_service):
        """Callback with status=failed injects TaskFailed synthetic message."""
        with patch("src.api.routes.callback.get_stm_service", return_value=mock_stm_service):
            response = client.post(
                "/v1/callback/nanoclaw/session-123",
                json={
                    "task_id": "task-001",
                    "status": "failed",
                    "summary": "NanoClaw 컨테이너 타임아웃",
                },
            )

        assert response.status_code == 200

        # Verify TaskFailed prefix
        mock_stm_service.add_chat_history.assert_called_once()
        messages = mock_stm_service.add_chat_history.call_args[1]["messages"]
        assert "[TaskFailed:task-001]" in messages[0].content


class TestCallback404:
    """404 path: Unknown task_id."""

    def test_callback_unknown_task_returns_404(self, client, mock_stm_service):
        """Callback with non-existent task_id returns 404."""
        with patch("src.api.routes.callback.get_stm_service", return_value=mock_stm_service):
            response = client.post(
                "/v1/callback/nanoclaw/session-123",
                json={
                    "task_id": "nonexistent-task",
                    "status": "done",
                    "summary": "Should not be found",
                },
            )

        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()


class TestCallbackServiceUnavailable:
    """503 path: STM service not initialized."""

    def test_callback_no_stm_returns_503(self, client):
        """Callback when STM service is None returns 503."""
        with patch("src.api.routes.callback.get_stm_service", return_value=None):
            response = client.post(
                "/v1/callback/nanoclaw/session-123",
                json={
                    "task_id": "task-001",
                    "status": "done",
                    "summary": "irrelevant",
                },
            )

        assert response.status_code == 503
```

**Step 2: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/api/test_callback_e2e.py -v`
Expected: All 4 tests PASS. (The callback endpoint is already implemented.)

**Step 3: Commit**

```bash
git add backend/tests/api/test_callback_e2e.py
git commit -m "test(callback): add E2E mock tests for NanoClaw callback endpoint"
```

---

### Task 6: Create Mock Callback Shell Script

**Files:**

- Create: `backend/scripts/mock_callback.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
# mock_callback.sh — Send a fake NanoClaw callback to FastAPI for manual testing
#
# Usage:
#   ./scripts/mock_callback.sh                    # Happy path (done)
#   ./scripts/mock_callback.sh failed             # Failure path
#   ./scripts/mock_callback.sh done session-456   # Custom session
#
# Prerequisites: FastAPI running on localhost:8000 with an active session

set -euo pipefail

STATUS="${1:-done}"
SESSION_ID="${2:-test-session}"
TASK_ID="${3:-task-$(date +%s)}"
BASE_URL="${BACKEND_URL:-http://localhost:8000}"

if [ "$STATUS" = "done" ]; then
  SUMMARY="코드 리뷰 완료 - 보안 결함 1건 발견 (line 45). 수정 권장."
else
  SUMMARY="NanoClaw 컨테이너 타임아웃으로 작업 실패."
fi

echo "Sending $STATUS callback to $BASE_URL/v1/callback/nanoclaw/$SESSION_ID"
echo "  task_id: $TASK_ID"
echo "  summary: $SUMMARY"
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

Run: `chmod +x backend/scripts/mock_callback.sh`

**Step 3: Commit**

```bash
git add backend/scripts/mock_callback.sh
git commit -m "scripts: add mock callback script for manual E2E testing"
```

---

### Task 7: Update PRD INDEX.md

**Files:**

- Modify: `docs/prds/feature/INDEX.md`

**Step 1: Update statuses**

Change in `docs/prds/feature/INDEX.md`:

- `nanoclaw/03`: `TODO` → `DONE`
- `data_flow/01`: `TODO` → `DONE`

**Step 2: Commit**

```bash
git add docs/prds/feature/INDEX.md
git commit -m "docs: mark nanoclaw/03 and data_flow/01 as DONE"
```

---

## Task Dependency Graph

```
Task 1 (DevAgent SKILL.md)    ─┐
Task 2 (ReviewerAgent SKILL.md) ├─→ Task 4 (Orchestrator CLAUDE.md) ─→ Task 7 (INDEX update)
Task 3 (PMAgent SKILL.md)     ─┘
                                    Task 5 (E2E tests) ─→ Task 7
                                    Task 6 (mock script) ─→ Task 7
```

Tasks 1-3 are independent (parallelizable). Task 4 depends on 1-3. Tasks 5-6 are independent of 1-4. Task 7 is final.
