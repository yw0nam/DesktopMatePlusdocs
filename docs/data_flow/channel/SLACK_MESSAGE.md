# SLACK_MESSAGE Data Flow

Updated: 2026-04-05

## Overview

Slack 채널 메시지 처리에는 두 가지 경로가 있다.

1. **Direct Flow** — 에이전트가 즉시 응답 (delegation 없음)
2. **Delegation Flow** — 에이전트가 NanoClaw에 작업을 위임하고, 완료 후 콜백으로 응답

세션 ID 형식: `slack:{team_id}:{channel_id}:{user_id}` (현재 `user_id`는 상수 `"default"`)

> **Architecture Note**  
> STM 영속성은 LangGraph `MongoDBSaver` checkpointer가 자동 처리한다 — channel_service에 별도 save/load 호출 없음.  
> LTM retrieval/consolidation은 AgentService 내부 middleware가 처리한다 (`ltm_retrieve_hook`, `ltm_consolidation_hook`).  
> `reply_channel`은 STM metadata가 아닌 LangGraph state의 `pending_tasks[task_id]["reply_channel"]`에 저장된다.

---

## Flow 1: Direct Message (No Delegation)

```mermaid
sequenceDiagram
    actor User as User (Slack)
    participant Slack as Slack Server
    participant BE as Backend (FastAPI)
    participant SR as SessionRegistry
    participant Agent as AgentService

    User->>Slack: Send message in channel
    Slack->>BE: POST /v1/channels/slack/events<br/>(x-slack-signature, x-slack-request-timestamp)

    activate BE
    BE->>BE: Verify HMAC-SHA256 signature<br/>& timestamp freshness (±5min)

    alt Invalid signature or stale timestamp
        BE-->>Slack: 403 Forbidden
    end

    BE->>BE: Parse event<br/>(skip: bot message, subtype, non-message type)
    BE-->>Slack: 200 {"ok": true}  ← immediate return

    Note over BE: asyncio.create_task(process_message(...))
    deactivate BE

    activate BE
    BE->>BE: session_lock(session_id) acquired<br/>(TTLCache 600s — prevents concurrent processing)
    BE->>SR: registry.upsert(session_id, user_id, agent_id)

    BE->>Agent: invoke(<br/>  messages=[HumanMessage(text)],<br/>  session_id, persona_id,<br/>  context={"reply_channel": {provider, channel_id}}<br/>)

    Note right of Agent: LangGraph checkpointer auto-loads history
    Note right of Agent: ltm_retrieve_hook fires (middleware)
    Note right of Agent: Agent generates response
    Note right of Agent: LangGraph checkpointer auto-saves messages
    Note right of Agent: ltm_consolidation_hook fires async (every 10 turns)

    Agent-->>BE: {content, ...}

    BE->>Slack: SlackService.send_message(channel_id, content)
    deactivate BE

    Slack-->>User: Display AI reply
```

---

## Flow 2: Delegation Flow (NanoClaw Task)

에이전트가 `DelegateTaskTool`을 사용해 NanoClaw에 작업을 위임하는 경우.

```mermaid
sequenceDiagram
    actor User as User (Slack)
    participant Slack as Slack Server
    participant BE as Backend (FastAPI)
    participant SR as SessionRegistry
    participant Agent as AgentService
    participant NC as NanoClaw

    User->>Slack: Send message in channel
    Slack->>BE: POST /v1/channels/slack/events
    BE->>BE: Verify signature, parse event
    BE-->>Slack: 200 {"ok": true}  ← immediate return

    activate BE
    Note over BE: asyncio.create_task(process_message(...))
    BE->>BE: session_lock(session_id)
    BE->>SR: registry.upsert(session_id, user_id, agent_id)

    BE->>Agent: invoke(<br/>  messages=[HumanMessage(text)],<br/>  context={"reply_channel": {provider, channel_id}}<br/>)
    Note right of Agent: Agent decides to delegate

    Agent->>Agent: DelegateTaskTool:<br/>reads reply_channel from context<br/>stores in pending_tasks[task_id]["reply_channel"]
    Agent->>NC: POST /api/webhooks/fastapi (task payload)
    NC-->>Agent: {task_id} acknowledged

    Note right of Agent: LangGraph saves: pending_tasks + ToolMessage
    Agent-->>BE: {content: "작업 중..."}

    BE->>Slack: send_message(channel_id, "작업 중...")
    deactivate BE

    Note over NC: NanoClaw executes task asynchronously

    NC->>BE: POST /v1/callback/nanoclaw/{session_id}<br/>{task_id, status, summary}

    activate BE
    BE->>Agent: aget_state(config) → pending_tasks
    BE->>BE: find task_record by task_id<br/>→ extract reply_channel
    BE->>Agent: aupdate_state(<br/>  messages=[SystemMessage("[TaskResult:task_id] summary")],<br/>  pending_tasks[task_id].status = "done"<br/>)
    BE-->>NC: 200 {task_id, status, message}

    Note over BE: asyncio.create_task(process_message(text="", ...))
    deactivate BE

    activate BE
    BE->>BE: session_lock(session_id)
    BE->>SR: registry.upsert(session_id, user_id, agent_id)

    BE->>Agent: invoke(<br/>  messages=[],  ← text="" → no HumanMessage<br/>  session_id, ...<br/>)
    Note right of Agent: LangGraph checkpointer loads history<br/>including [TaskResult] SystemMessage
    Note right of Agent: Agent sees TaskResult → generates final reply
    Agent-->>BE: {content: "최종 결과..."}

    BE->>Slack: send_message(channel_id, "최종 결과...")
    deactivate BE

    Slack-->>User: Display final AI reply
```

---

## Flow 3: URL Verification (App Setup, One-Time)

```mermaid
sequenceDiagram
    participant Slack as Slack Server
    participant BE as Backend (FastAPI)

    Slack->>BE: POST /v1/channels/slack/events<br/>{type: "url_verification", challenge: "abc123"}
    BE->>BE: Verify signature
    BE-->>Slack: 200 {"challenge": "abc123"}
```

---

## Key Implementation Details

### Signature Verification

- Algorithm: HMAC-SHA256 over `v0:{timestamp}:{body}`
- Timestamp tolerance: ±5 minutes (replay attack prevention)
- Comparison: `hmac.compare_digest` (timing-safe)

### Session Lock

- `session_lock(session_id)`: `cachetools.TTLCache` 기반 async context manager
- TTL: 600s, maxsize: 1024
- 동일 세션의 동시 처리 방지 (빠른 연속 메시지, callback 재진입)

### reply_channel 저장 위치

- `process_message(context={"reply_channel": ...})` → `agent_service.invoke(context=...)` 전달
- `DelegateTaskTool`이 context에서 읽어 LangGraph state의 `pending_tasks[task_id]["reply_channel"]`에 저장
- Callback 핸들러가 `aget_state()` → `pending_tasks`에서 `reply_channel` 읽어 라우팅 결정

### process_message `text=""` 경로 (Callback)

- `text`가 비어있으면 `HumanMessage` 미추가
- LangGraph checkpointer가 이미 `[TaskResult:task_id]` `SystemMessage`를 포함한 상태로 로드
- 에이전트가 TaskResult를 기반으로 최종 응답 생성

### Error Handling

- `process_message` 예외 시 Slack으로 에러 메시지 전송: `"처리 중 오류가 발생했어. 다시 시도해줘"`
- 에러는 백그라운드 태스크에서 발생하므로 Slack에 `{"ok": true}`가 이미 반환된 이후

---

## Appendix

### PatchNote

2026-04-05: 전면 개정 — STM Service 참조 제거(현재 LangGraph checkpointer 자동 처리), reply_channel 저장 위치 정정(STM metadata → pending_tasks LangGraph state), load_context/save_turn explicit call 제거, LTM middleware 설명 추가.
2026-03-19: 초기 작성.

- [NanoClaw Callback](../../../backend/src/api/routes/callback.py)
- [ADD_CHAT_MESSAGE Data Flow](../chat/ADD_CHAT_MESSAGE.md)
