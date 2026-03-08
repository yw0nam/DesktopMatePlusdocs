# Feature Task Index

**Source PRD**: [required_feature_refined.md](./required_feature_refined.md)
**Architecture**: Decoupled Director-Artisan (FastAPI + NanoClaw + Unity)
**Last Updated**: 2026-03-08

---

## Overview

FastAPI(Director)가 사용자와의 실시간 대화를 처리하고, 무거운 작업은 NanoClaw(Artisan)로 fire-and-forget 위임한다. Unity는 Dumb UI로서 렌더링만 담당한다.

---

## Implementation Status

### fastapi_backend — §1 The Director

기존 WebSocket, STM/LTM, TTS, VLM, Agent Service는 구현 완료. 아래는 새 아키텍처를 위한 추가 작업.

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [DelegateTaskTool](./fastapi_backend/task-01-delegate-task-tool.md) | P0 | TODO | PersonaAgent가 NanoClaw로 작업을 위임하는 LangGraph Tool |
| 02 | [Callback Endpoint](./fastapi_backend/task-02-callback-endpoint.md) | P0 | TODO | NanoClaw 결과 수신 + synthetic message 삽입 |
| 03 | [Background Sweep](./fastapi_backend/task-03-background-sweep.md) | P1 | TODO | TTL 초과 task를 failed 처리하는 주기적 스캔 |

### core_bridge — §2 The Core Bridge

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [HTTP Channel](./core_bridge/task-01-http-channel.md) | P0 | TODO | NanoClaw에 Fastify HTTP 채널 추가 (Ingress/Egress) |

### nanoclaw_swarm — §3 The Artisan Team

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [Persona Skills](./nanoclaw_swarm/task-01-persona-skills.md) | P0 | TODO | DevAgent, ReviewerAgent, PMAgent Skill 파일 작성 |
| 02 | [Multi-Persona Execution](./nanoclaw_swarm/task-02-single-container-multi-persona.md) | P0 | TODO | Sub-Agent Driven(TeamCreate) Persona 실행 로직 |

### observer — §4 The Observers & Bypasses

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [IPC Observer](./observer/task-01-ipc-observer.md) | P2 | TODO | Staging 패턴으로 IPC를 Slack 등에 미러링 |
| 02 | [Direct Access](./observer/task-02-direct-access.md) | P2 | TODO | IPC 파일 직접 작성으로 NanoClaw 명령 주입 |

### unity — §5 The Dumb UI

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [Dumb UI](./unity/task-01-dumb-ui.md) | P1 | TODO | 기존 렌더링 동작 유지 검증 + 위임 결과 표시 |

### data_flow — §6 Interaction Flow

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [Delegation Flow E2E](./data_flow/task-01-delegation-flow.md) | P0 | TODO | 위임 → 실행 → callback → 보고 전체 흐름 통합 테스트 |
| 02 | [TTS Flow](./data_flow/task-02-tts-flow.md) | P1 | TODO | 스트리밍 → 문장 감지 → TTS → Unity push 검증 |
| 03 | [LTM Consolidation](./data_flow/task-03-ltm-consolidation.md) | P1 | TODO | 턴 기반 LTM consolidation + synthetic message 처리 |

### TODO — 미결 사항

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [Push Notification](./TODO/task-01-push-notification.md) | P2 | HOLD | Callback 수신 시 Unity로 즉시 알림 |
| 02 | [Delegation Policy](./TODO/task-02-delegation-policy.md) | P1 | HOLD | 위임 vs 직접 처리 경계 규칙 정의 |
| 03 | [Barge-in Interrupt](./TODO/task-03-barge-in-interrupt.md) | P2 | HOLD | 사용자 끼어들기 시 파이프라인 즉시 중단 |
| 04 | [Cross-Runtime Sub-Agent](./TODO/task-04-cross-runtime-subagent.md) | P2 | HOLD | MCP 기반 runtime-agnostic Sub-agent delegation |

---

## Dependency Graph

```
fastapi_backend/01 (DelegateTaskTool)
  └─→ core_bridge/01 (HTTP Channel) ──→ nanoclaw_swarm/01 (Persona Skills)
  └─→ fastapi_backend/02 (Callback)       └─→ nanoclaw_swarm/02 (Multi-Persona)
       └─→ fastapi_backend/03 (Sweep)
       └─→ data_flow/01 (E2E Integration)
                └─→ data_flow/02 (TTS 검증)
                └─→ data_flow/03 (LTM Consolidation)

observer/01, observer/02 — 독립 (어느 시점에든 구현 가능)
unity/01 — data_flow/01 완료 후 검증
TODO/* — 기본 흐름 안정화 후
```

## Suggested Build Order

1. **Phase 1** (P0 병렬): `fastapi_backend/01` + `core_bridge/01` + `nanoclaw_swarm/01`
2. **Phase 2** (P0 연결): `fastapi_backend/02` + `nanoclaw_swarm/02`
3. **Phase 3** (P0 통합): `data_flow/01` (E2E)
4. **Phase 4** (P1): `fastapi_backend/03` + `data_flow/02` + `data_flow/03` + `unity/01`
5. **Phase 5** (P2): `observer/*` + `TODO/*`
