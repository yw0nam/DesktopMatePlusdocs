> **[HOLD]** Multi-Persona Orchestrator는 nice-to-have 기능으로 분류되어 HOLD 처리됨.
> `data_flow/01` E2E 섹션(§5)은 현재 플랜([2026-03-09-e2e-and-p1-plan.md](./2026-03-09-e2e-and-p1-plan.md))으로 이전됨.
> 이 문서는 참고용으로만 보존한다.

# Phase 2 Design: Multi-Persona Orchestrator + E2E Mock Verification

**Date**: 2026-03-09 (revised)
**Scope**: `nanoclaw/03` (Multi-Persona Execution) + `data_flow/01` (E2E Mock Verification)
**Approach**: A — Pure Prompt Orchestrator (NanoClaw 소스 변경 없음, skill 패키지만)

---

## Summary

기존 인프라(TeamCreate, send_message, HTTP Channel, Callback Endpoint)가 모두 준비된 상태.
**skill 패키지를 통해** Group CLAUDE.md와 Persona SKILL.md를 업데이트하여 Multi-Persona
Orchestrator를 구현한다. NanoClaw 소스 코드는 직접 수정하지 않는다.
FastAPI 측 E2E 검증은 기존 테스트 실행으로 커버한다 (신규 테스트 불필요).

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| NanoClaw 파일 변경 방식 | Skill 패키지 (apply-skill.ts) | workspace 규칙: NanoClaw 소스 직접 수정 금지 |
| Status 오탈자 수정 | add-http 스킬 (이미 포함) | http.ts는 이미 `'done'` 사용 중. 별도 스킬 불필요 |
| Orchestrator 구현 방식 | CLAUDE.md 지침만 | 인프라 이미 준비됨. 불안정 시 Approach B(code 자동주입)로 fallback |
| sender 필드 모델 | Text attribution | ipc.ts가 sender 필드를 드롭함 (confirmed). Orchestrator summary에 Persona 이름 포함. 전체 sender 지원은 Approach B로 defer |
| Sub-agent send_message | 금지 | callback으로 중간 메시지가 전송되는 것을 방지. Main Agent만 최종 결과 전송 |
| E2E 검증 범위 | 기존 테스트 실행 | `test_delegation_e2e.py`가 이미 full mock round-trip 커버 |
| Cross-Runtime 대비 | TODO/task-04에 기록 | 현재는 Claude Agent Teams 전용 |

---

## 1. HTTP Channel Status Vocabulary (이미 수정됨)

`add-http` skill의 `http.ts`는 이미 `status: 'done' | 'failed'`를 사용한다.
별도의 fix 스킬은 불필요. `add-http` 스킬 적용 시 올바른 상태 어휘가 자동으로 포함된다.

- L18: `status: 'done' | 'failed'` ✓
- L280: `status: 'done'` ✓ (FastAPI `Literal["done", "failed"]` 호환)

---

## 2. Orchestrator 지침 (groups/main/CLAUDE.md)

`groups/main/CLAUDE.md`에 Task Delegation 섹션을 추가한다.
**적용 방식**: `add-multi-persona-orchestrator` skill 패키지 (apply-skill.ts 경유)

### 추가 내용

```markdown
## Task Delegation (Orchestrator Mode)

When you receive a message from FastAPI Director (recognized by format:
"Task: ...\nTask ID: ...\nSession ID: ..."), switch to Orchestrator mode:

### Step 1: Analyze the Task

- Determine which Personas are needed: DevAgent (coding), ReviewerAgent (review), PMAgent (reporting)
- Decide execution order:
  - Sequential: dependent tasks (e.g., DevAgent writes → ReviewerAgent reviews)
  - Parallel: independent tasks
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
2. Attribute each result to the responsible Persona explicitly:
   e.g. "DevAgent: [수정 내역], ReviewerAgent: [리뷰 내용]"
3. Include the Task ID for traceability

### Step 4: Deliver Final Result

Send via mcp__nanoclaw__send_message(text: final_summary).
This triggers the HTTP Channel egress → POST to FastAPI callback_url.

IMPORTANT:
- Only YOU (Main Agent) may call mcp__nanoclaw__send_message for the final result
- Sub-agents MUST NOT call send_message — return results to me directly
```

### sender 필드 설계 결정

**제약 확인**: `ipc.ts` L83이 `sendMessage(chatJid, text)`만 호출 — sender 필드 드롭 확인됨.
ipc.ts + sendMessage 인터페이스 수정 없이는 IPC sender를 통한 Persona 구분 불가능.

**현재 모델 (text attribution)**:
Orchestrator의 최종 summary에 Persona 이름이 명시적으로 포함된다. PRD AC "IPC sender로
Persona 구분"은 text attribution으로 충족한다.

**Approach B (ipc.ts sender 전달) — deferred**:
ipc.ts, sendMessage 인터페이스, http.ts 수정 필요. sender field가 critical해지면
별도 skill 패키지로 구현한다.

### 설계 근거

- `container-runner.ts`가 이미 `container/skills/`를 `/home/node/.claude/skills/`로 동기화
- TeamCreate prompt에 SKILL.md 경로만 전달 (context window 절약)
- Sub-agent의 send_message 금지로 중간 callback 방지

---

## 3. Persona SKILL.md 업데이트

`container/skills/{dev-agent,reviewer-agent,pm-agent}/SKILL.md` 각각에 Communication Rules 추가.
**적용 방식**: `add-multi-persona-orchestrator` skill 패키지에 포함

### 공통 추가 섹션

```markdown
## Communication Rules (Sub-agent Mode)

When running as a sub-agent spawned by an orchestrator:
- Do NOT use `mcp__nanoclaw__send_message` directly — return results to the orchestrator
- Follow the Output Format section for structured results
- If the task requires file creation, write to /workspace/group/ and reference paths in output
- Keep output concise — the orchestrator synthesizes across all Personas
```

### 변경하지 않는 것

- 기존 Responsibilities, Workflow, Output Format 유지
- allowed-tools 변경 없음
- 각 Persona의 고유 역할 정의 유지

---

## 4. Egress Flow (확인)

```
Main Agent → mcp__nanoclaw__send_message(text: summary)
  → IPC file: { type: "message", chatJid: "http:{base64_callback_url}", text: summary }
    → ipc.ts: sendMessage(chatJid, text)  ← sender 필드는 여기서 드롭됨 (known limitation)
      → router.ts → HTTP Channel (ownsJid: "http:")
        → http.ts sendMessage(jid, text)
          → extractCallbackUrl(jid) → base64 decode
            → POST {callback_url} { task_id, status: "done", summary: text }
              → FastAPI callback.py → STM synthetic message 삽입
```

`add-http` skill의 status vocab이 이미 올바르게 설정되어 있어 완전히 동작 가능.

### jidToTaskId 매핑

- Webhook 수신 시: `jidToTaskId.set(jid, task_id)`
- sendMessage 시: `jidToTaskId.get(jid)` → task_id 사용 후 Map에서 삭제
- 변경 없음 — 현재 구현으로 충분

---

## 5. data_flow/01 — E2E 검증

**기존 테스트가 이미 커버**:

- `backend/tests/api/test_delegation_e2e.py`: DelegateTaskTool → mock NanoClaw → callback → STM full round-trip (3개 시나리오)
- `backend/tests/api/test_callback_api.py`: callback endpoint 개별 케이스

신규 pytest 테스트는 불필요. 기존 테스트 Green 확인으로 FastAPI 측 mock 검증 완료.

**data_flow/01 DONE 조건**: 기존 테스트 Green + 실제 NanoClaw 실행 후 E2E 검증.
단순 기존 테스트 통과는 "mock 검증 완료"이며 data_flow/01은 DONE이 아닌 IN_PROGRESS로 유지.

---

## 6. Non-Goals

- NanoClaw TypeScript 소스 직접 수정
- ipc.ts sender 전달 수정 (Approach B, 명시적 task 없는 한 defer)
- NanoClaw 실제 실행을 포함한 전체 E2E (data_flow/01 full scope)
- Push Notification (TODO/task-01)
- Background Sweep (fastapi_backend/task-03)
- Cross-Runtime Sub-Agent (TODO/task-04)

---

## 7. Acceptance Criteria

### HTTP Channel Status Vocab (add-http 스킬에 이미 포함)

- [x] `add-http` skill의 `http.ts`가 `status: 'done'`을 전송한다 (FastAPI `Literal["done","failed"]` 호환)

### nanoclaw/03

- [ ] `add-multi-persona-orchestrator` skill apply 완료, npm test Green
- [ ] `groups/main/CLAUDE.md`에 Task Delegation 섹션이 포함된다
- [ ] Persona SKILL.md 3개에 Communication Rules가 추가된다
- [ ] Orchestrator 지침: Sub-agent send_message 금지가 명시된다
- [ ] Orchestrator 지침: 최종 summary에 Persona attribution이 포함된다

### data_flow/01 (mock 검증)

- [ ] `uv run pytest tests/api/test_delegation_e2e.py tests/api/test_callback_api.py -v` Green
- [ ] 전체 E2E (NanoClaw 실제 실행)는 NanoClaw 기동 후 별도 검증 시 DONE 마킹
