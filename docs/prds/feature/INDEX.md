# Feature Task Index

**Source PRD**: [required_feature_refined.md](./required_feature_refined.md)
**Architecture**: Decoupled Director-Artisan (FastAPI + NanoClaw + Unity)
**Last Updated**: 2026-03-09

---

## Overview

FastAPI(Director)가 사용자와의 실시간 대화를 처리하고, 무거운 작업은 NanoClaw(Artisan)로 fire-and-forget 위임한다. Unity는 Dumb UI로서 렌더링만 담당한다.

배포 컴포넌트는 3개: **FastAPI**, **NanoClaw**, **Unity**.

---

## Implementation Status

### fastapi_backend — §1 The Director

기존 WebSocket, STM/LTM, TTS, VLM, Agent Service는 구현 완료. 아래는 새 아키텍처를 위한 추가 작업.

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [DelegateTaskTool](./fastapi_backend/task-01-delegate-task-tool.md) | P0 | DONE | PersonaAgent가 NanoClaw로 작업을 위임하는 LangGraph Tool |
| 02 | [Callback Endpoint](./fastapi_backend/task-02-callback-endpoint.md) | P0 | DONE | NanoClaw 결과 수신 + synthetic message 삽입 |
| 03 | [Background Sweep](./fastapi_backend/task-03-background-sweep.md) | P1 | TODO | TTL 초과 task를 failed 처리하는 주기적 스캔 |

### nanoclaw — §2 The Artisan Team

NanoClaw 내부의 HTTP 채널 추가 + 멀티 페르소나 실행 로직.

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [HTTP Channel](./core_bridge/task-01-http-channel.md) | P0 | DONE | NanoClaw에 HTTP 채널 추가 (Ingress/Egress) |
| 02 | [Persona Skills](./nanoclaw_swarm/task-01-persona-skills.md) | P0 | DONE | DevAgent, ReviewerAgent, PMAgent Skill 파일 작성 |
| 03 | [Multi-Persona Execution](./nanoclaw_swarm/task-02-single-container-multi-persona.md) | P0 | TODO | Sub-Agent Driven(TeamCreate) Persona 실행 로직 |

### data_flow — §3 Interaction Flow

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [Delegation Flow E2E](./data_flow/task-01-delegation-flow.md) | P0 | TODO | 위임 → 실행 → callback → 보고 전체 흐름 통합 테스트 |
| 02 | [TTS Flow](./data_flow/task-02-tts-flow.md) | P1 | VERIFY | 기존 구현 검증/보완. 스트리밍 → 문장 감지 → TTS → Unity push |
| 03 | [LTM Consolidation](./data_flow/task-03-ltm-consolidation.md) | P1 | VERIFY | 기존 메커니즘 존재. turn counter를 user message only로 수정 + synthetic message 포함 검증 |

### Appendix: 검증 항목 (코드 변경 없음)

별도 task가 아닌 E2E 테스트 시 확인할 체크리스트.

- [ ] **Unity Dumb UI** ([상세](./unity/task-01-dumb-ui.md)): 위임 결과가 일반 대화와 동일하게 렌더링된다. Unity는 NanoClaw를 직접 인식하지 않는다.
- [ ] **Direct Access** ([상세](./observer/task-02-direct-access.md)): `ipc/{group}/tasks/`에 파일 직접 작성으로 NanoClaw task가 실행된다 (기존 IPC 동작 확인).

### observer — 독립 사이드카

| # | Task | Priority | Status | Description |
|---|---|---|---|---|
| 01 | [IPC Observer](./observer/task-01-ipc-observer.md) | P2 | TODO | Staging 패턴으로 IPC를 Slack 등에 미러링 |

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
  └─→ nanoclaw/01 (HTTP Channel) ──→ nanoclaw/02 (Persona Skills)
  └─→ fastapi_backend/02 (Callback)      └─→ nanoclaw/03 (Multi-Persona)
       └─→ fastapi_backend/03 (Sweep)
       └─→ data_flow/01 (E2E Integration)
                └─→ data_flow/02 (TTS 검증)
                └─→ data_flow/03 (LTM Consolidation)

observer/01 — 독립 (어느 시점에든 구현 가능)
TODO/* — 기본 흐름 안정화 후
```

## Suggested Build Order

1. **Phase 1** (P0 병렬): `fastapi_backend/01` + `nanoclaw/01` + `nanoclaw/02`
2. **Phase 2** (P0 연결): `fastapi_backend/02` + `nanoclaw/03`
3. **Phase 3** (P0 통합): `data_flow/01` (E2E) — mock callback script로 FastAPI 독립 테스트 가능
4. **Phase 4** (P1): `fastapi_backend/03` + `data_flow/02` + `data_flow/03`
5. **Phase 5** (P2): `observer/*` + `TODO/*`
