# DelegateTask Flow

Updated: 2026-04-05

## Overview

`DelegateTaskTool`은 AgentService가 무거운 작업을 NanoClaw에 위임할 때 사용한다.
WebSocket 채팅과 Slack 채널 양쪽에서 동일한 흐름으로 동작한다.

위임 흐름:
1. Agent → `DelegateTaskTool` 호출 → NanoClaw에 작업 전송
2. NanoClaw가 비동기로 작업 수행
3. NanoClaw → Backend callback → LangGraph state에 결과 주입 → 원 채널에 최종 응답

`reply_channel`은 STM metadata가 아닌 LangGraph state의 `pending_tasks[task_id]["reply_channel"]`에 저장된다.

---

## Phase 1: Task Delegation

```mermaid
sequenceDiagram
    participant LLM as LLM (Claude)
    participant Tool as DelegateTaskTool
    participant NC as NanoClaw
    participant LG as LangGraph State

    LLM->>Tool: _arun(task="...")

    Tool->>Tool: task_id = uuid4()
    Tool->>Tool: reply_channel = runtime.context.get("reply_channel")\n(None if WebSocket, {provider, channel_id} if Slack)

    Tool->>Tool: task_record = {\n  task_id, description, status: "running",\n  created_at, reply_channel\n}

    Tool->>NC: POST /api/webhooks/fastapi\n{task, task_id, callback_url: "/v1/callback/nanoclaw/{task_id}"}

    alt NanoClaw 응답 성공
        NC-->>Tool: 200 OK
        Tool-->>LG: Command(update={\n  pending_tasks: [..., task_record],\n  messages: [ToolMessage("팀에 작업을 지시했습니다.")]\n})
    else NanoClaw 통신 실패
        Tool-->>LG: Command(update={\n  pending_tasks: [..., task_record],\n  messages: [ToolMessage("NanoClaw과의 통신에 실패했습니다.")]\n})
    end

    Note over LG: LangGraph checkpointer saves state
```

---

## Phase 2: NanoClaw Callback

```mermaid
sequenceDiagram
    participant NC as NanoClaw
    participant CB as Callback Route\n/v1/callback/nanoclaw/{session_id}
    participant LG as LangGraph State
    participant Channel as Origin Channel\n(Slack or WebSocket)

    NC->>CB: POST /v1/callback/nanoclaw/{session_id}\n{task_id, status: "done"|"failed", summary}

    CB->>LG: aget_state(config={thread_id: session_id})
    LG-->>CB: state.pending_tasks

    CB->>CB: find task_record where task_id matches
    alt task_record not found
        CB-->>NC: 404 Task not found
    end

    CB->>CB: prefix = "TaskResult" if status=="done" else "TaskFailed"
    CB->>LG: aupdate_state(\n  messages=[SystemMessage("[{prefix}:{task_id}] {summary}")],\n  pending_tasks[task_id].status = status\n)

    alt reply_channel 있음 (Slack 등 채널 요청)
        CB->>Channel: asyncio.create_task(\n  process_message(text="", session_id, provider, channel_id, ...)\n)
        Note over Channel: text="" → HumanMessage 미추가\nLangGraph가 [TaskResult] SystemMessage 포함한 상태 로드\nAgent가 최종 응답 생성 → Slack 전송
    else reply_channel 없음 (WebSocket 요청)
        Note over CB: WS 클라이언트는 별도 polling 또는\n다음 메시지에서 결과 확인
    end

    CB-->>NC: 200 {task_id, status, message}
```

---

## reply_channel 유무에 따른 차이

| 채널 | reply_channel | Callback 후 동작 |
|------|--------------|-----------------|
| Slack | `{provider: "slack", channel_id: "C..."}` | `process_message(text="")` → Slack 자동 전송 |
| WebSocket | `None` | state 갱신만. 클라이언트가 다음 메시지에서 결과 수신 |

---

## LangGraph State 스키마 (관련 필드)

```python
# CustomAgentState (state.py)
pending_tasks: list[PendingTask]

# PendingTask (TypedDict)
{
    "task_id": str,
    "description": str,
    "status": "running" | "done" | "failed",
    "created_at": str,  # ISO 8601 UTC
    "reply_channel": {"provider": str, "channel_id": str} | None,
}
```

---

## Appendix

- 구현: `backend/src/services/agent_service/tools/delegate/delegate_task.py`
- Callback 라우트: `backend/src/api/routes/callback.py`
- State 스키마: `backend/src/services/agent_service/state.py`
- NanoClaw webhook: `POST /api/webhooks/fastapi` (NanoClaw HTTP Channel)
- timeout: 5s (httpx AsyncClient — 초과 시 실패 메시지, 태스크는 계속 pending_tasks에 유지됨)
