# Task 01: DelegateTaskTool 구현

**Parent**: §1 The Director (FastAPI Backend)
**Priority**: P0
**Depends on**: 기존 Agent Service (LangGraph)

---

## Goal

PersonaAgent(LangGraph)가 무거운 작업을 NanoClaw로 위임할 수 있는 LangGraph Tool을 구현한다.

## Context

기존 Agent Service는 LangGraph 기반으로 동작 중이며, memory tool(add/search/delete/update)이 이미 구현되어 있다. `DelegateTaskTool`은 동일한 패턴으로 추가되는 신규 Tool이다.

## Scope

- `src/services/agent_service/tools/delegate/` 디렉토리 생성
- `DelegateTaskTool` LangGraph Tool 구현:
  - `task_id(uuid)` 생성
  - `session.metadata.pending_tasks`에 Task Record 추가 (status: `running`)
  - NanoClaw HTTP Channel로 `POST /api/webhooks/fastapi` fire-and-forget 전송
    - Payload: `{ task, task_id, session_id, callback_url, context(STM/LTM) }`
  - Tool 반환값: "팀에 작업을 지시했습니다" 류의 확인 메시지
- PersonaAgent System Prompt에 위임 가이드라인 주입 (어떤 작업을 위임할지)

## Out of Scope

- 위임 경계 정책의 세부 규칙 정의 (TODO로 보류)
- NanoClaw 측 수신 처리 (core_bridge task)

## Task Record Schema

```json
{
  "task_id": "uuid-v4",
  "description": "auth-fix 브랜치 코드 리뷰",
  "status": "running",
  "created_at": "ISO8601"
}
```

## Acceptance Criteria

- [ ] PersonaAgent가 무거운 작업 요청 시 DelegateTaskTool을 호출한다
- [ ] Task Record가 `session.metadata.pending_tasks`에 정상 저장된다
- [ ] NanoClaw로 HTTP POST가 fire-and-forget으로 전송된다
- [ ] 사용자에게 위임 확인 응답이 스트리밍된다 (응답 블로킹 없음)
