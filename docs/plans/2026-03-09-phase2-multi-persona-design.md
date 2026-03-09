# Phase 2 Design: Multi-Persona Orchestrator + E2E Mock Verification

**Date**: 2026-03-09
**Scope**: `nanoclaw/03` (Multi-Persona Execution) + `data_flow/01` (E2E Mock)
**Approach**: A — Pure Prompt Orchestrator (code 변경 없음)

---

## Summary

기존 인프라(TeamCreate, send_message, HTTP Channel, Callback Endpoint)가 모두 준비된 상태.
NanoClaw 소스 코드 변경 없이, **CLAUDE.md 지침 + Persona SKILL.md 업데이트**만으로 Multi-Persona Orchestrator를 구현한다.
FastAPI 측 E2E 검증은 mock callback으로 독립 수행한다.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Orchestrator 구현 방식 | CLAUDE.md 지침만 | 인프라 이미 준비됨. 코드 변경 0으로 빠른 검증 |
| sender 필드 | Prompt 안내 방식 | ipc-mcp-stdio.ts에 이미 sender 파라미터 존재. 불안정 시 Approach B(code 자동주입)로 fallback |
| Sub-agent send_message | 금지 | callback으로 중간 메시지가 전송되는 것을 방지. Main Agent만 최종 결과 전송 |
| E2E 검증 범위 | FastAPI mock만 | NanoClaw 실제 실행은 별도. curl/pytest로 callback 흐름 검증 |
| Cross-Runtime 대비 | TODO/task-04에 기록 | 현재는 Claude Agent Teams 전용. 향후 MCP 기반 runtime-agnostic 지원 예정 |

---

## 1. Orchestrator 지침 (groups/main/CLAUDE.md)

`groups/main/CLAUDE.md`에 Task Delegation 섹션을 추가한다.

### 추가 내용

```markdown
## Task Delegation (Orchestrator Mode)

When you receive a message from FastAPI Director (format: "Task: ...\nTask ID: ...\nSession ID: ..."),
switch to Orchestrator mode:

### Step 1: Analyze the Task
- Determine which Personas are needed: DevAgent, ReviewerAgent, PMAgent
- Decide execution order:
  - Sequential: dependent tasks (e.g., DevAgent → ReviewerAgent)
  - Parallel: independent tasks

### Step 2: Spawn Sub-agents via TeamCreate
For each Persona, use TeamCreate with this prompt:

    You are {PersonaName}. Read and follow: /home/node/.claude/skills/{persona-dir}/SKILL.md

    Task: {task description}
    Task ID: {task_id}

    {preceding results if sequential}

    RULES:
    - Do NOT use mcp__nanoclaw__send_message. Return your result to me directly.
    - Follow the output format in your SKILL.md.

### Step 3: Collect & Synthesize
After all Sub-agents complete, synthesize their outputs into a final report.

### Step 4: Deliver Final Result
Use mcp__nanoclaw__send_message(text: final_summary) to send the result.
This triggers the HTTP Channel egress → POST to FastAPI callback_url.

Do NOT include sender field in the final message — the channel handles routing automatically.

### Persona Directory Mapping
| Persona | Skill Directory |
|---------|----------------|
| DevAgent | dev-agent |
| ReviewerAgent | reviewer-agent |
| PMAgent | pm-agent |
```

### 설계 근거

- `container-runner.ts`가 이미 `container/skills/`를 `/home/node/.claude/skills/`로 동기화
- TeamCreate prompt에 SKILL.md 경로만 전달 (context window 절약)
- Sub-agent의 send_message 사용을 명시적으로 금지하여 중간 callback 방지

---

## 2. Persona SKILL.md 업데이트

`container/skills/{dev-agent,reviewer-agent,pm-agent}/SKILL.md` 각각에 Communication Rules 추가.

### 공통 추가 섹션

```markdown
## Communication Rules (Sub-agent Mode)

When running as a sub-agent spawned by an orchestrator:
- Do NOT use `mcp__nanoclaw__send_message` directly
- Return your results to the orchestrator via your normal output
- Follow the Output Format section for structured results
- If the task requires file creation, write files to /workspace/group/ and reference paths in your output
```

### 변경하지 않는 것

- 기존 Responsibilities, Workflow, Output Format 유지
- allowed-tools 변경 없음
- 각 Persona의 고유 역할 정의 유지

---

## 3. Egress Flow (확인)

```
Main Agent → mcp__nanoclaw__send_message(text: summary)
  → IPC file: { type: "message", chatJid: "http:{base64_callback_url}", text: summary }
    → NanoClaw host (router.ts) → HTTP Channel (ownsJid matches "http:")
      → http.ts sendMessage(jid, text)
        → extractCallbackUrl(jid) → base64 decode
          → POST {callback_url} { task_id, status: "success", summary: text }
```

### jidToTaskId 매핑

- Webhook 수신 시: `jidToTaskId.set(jid, task_id)`
- sendMessage 시: `jidToTaskId.get(jid)` → task_id 사용 후 Map에서 삭제
- **변경 없음** — 현재 구현으로 충분

### Fallback: sender 불안정 시

sender 필드가 실제 실행에서 누락되는 경우, Approach B로 전환:

- NanoClaw skill 패키지 작성: `add-persona-sender`
- agent-runner가 TeamCreate prompt에 sender를 자동 prefix 주입
- ipc-mcp-stdio.ts에서 sender 미설정 시 환경변수 기반 fallback 추가

---

## 4. data_flow/01 — E2E Mock 검증

FastAPI callback 처리만 mock으로 독립 검증. NanoClaw 실제 실행은 범위 밖.

### 테스트 시나리오

| # | Scenario | Input | Expected |
|---|----------|-------|----------|
| 1 | Happy Path | POST callback with status="done" | Task record updated, synthetic `[TaskResult:{id}]` message in STM |
| 2 | Failure Path | POST callback with status="failed" | Task record updated, synthetic `[TaskFailed:{id}]` message in STM |
| 3 | 404 Unknown task | POST callback with non-existent task_id | HTTP 404 |

### 구현물

- `backend/tests/api/test_callback_e2e.py`: pytest 기반 통합 테스트
- `backend/scripts/mock_callback.sh`: curl 기반 수동 검증 스크립트

---

## 5. Non-Goals (명시적 제외)

- NanoClaw 소스 코드 변경 (agent-runner, container-runner 등)
- NanoClaw 실제 실행을 포함한 전체 E2E
- Push Notification (TODO/task-01)
- Background Sweep (fastapi_backend/task-03, Phase 4)
- Cross-Runtime Sub-Agent (TODO/task-04)

---

## 6. Acceptance Criteria

### nanoclaw/03

- [ ] Orchestrator 지침이 `groups/main/CLAUDE.md`에 추가된다
- [ ] Main Agent가 task를 분석하여 TeamCreate로 Sub-agent를 spawn할 수 있다 (지침 기반)
- [ ] Sub-agent에게 Persona SKILL.md 경로와 task context가 prompt로 전달된다
- [ ] Sub-agent는 send_message를 직접 사용하지 않고 결과를 반환한다
- [ ] 최종 결과가 Main Agent의 send_message를 통해 Egress로 전송된다
- [ ] IPC 메시지의 sender 필드로 Persona 구분이 가능하다 (Orchestrator가 설정)

### data_flow/01

- [ ] Happy path: callback → synthetic message 삽입 → 검증
- [ ] Failure path: failed callback → TaskFailed message 삽입 → 검증
- [ ] 404 path: unknown task_id → 404 → 검증
