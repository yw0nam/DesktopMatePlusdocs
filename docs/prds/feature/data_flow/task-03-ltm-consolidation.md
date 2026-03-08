# Task 03: LTM Consolidation 턴 기반 트리거

**Parent**: §6 Interaction Flow
**Priority**: P1
**Depends on**: 기존 LTM Service, fastapi_backend/task-02

---

## Goal

Agent Service의 턴 처리 흐름에서 LTM consolidation 조건을 체크하고, synthetic message가 포함된 chat history를 자연스럽게 처리한다.

## Scope

- Turn counter는 user message에서만 increment
- Consolidation 조건: `current_turn - ltm_last_consolidated_at_turn >= 10`
- Consolidation 대상: 해당 구간의 chat history (synthetic message 포함)
- Consolidation은 기존 `LTMService.add_memory()` 활용, 백그라운드 실행

## Acceptance Criteria

- [ ] Turn counter가 user message에서만 증가한다
- [ ] 10턴 간격으로 LTM consolidation이 트리거된다
- [ ] Synthetic message(TaskResult/TaskFailed)가 consolidation 대상에 포함된다
- [ ] Consolidation이 응답 지연을 유발하지 않는다
