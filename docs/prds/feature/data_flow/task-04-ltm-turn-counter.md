# data_flow/04 — LTM Turn Counter Fix

**Priority**: P1
**Status**: TODO
**Discovered**: 2026-03-09 (during data_flow/03 verification)

---

## Problem

현재 `AgentService.save_memory()`의 turn counter 계산:

```python
current_turn = len(history) // 2  # 전체 메시지 쌍
```

PRD 요구사항은 **user message only**로 turn을 계산해야 한다.
현재 방식은 assistant/synthetic 메시지까지 포함하여 계산하므로, synthetic message가 많을수록 turn counter가 과다 계산된다.

## Acceptance Criteria

- [ ] turn counter가 `HumanMessage` (user) 메시지만 카운트한다
- [ ] `AIMessage`, `SystemMessage` (synthetic 포함)은 카운트에 포함되지 않는다
- [ ] 기존 LTM consolidation 동작(interval, history slice 등)은 변경 없음
- [ ] 관련 테스트 (`tests/services/test_ltm_consolidation.py`) 업데이트 및 통과

## Implementation Note

`src/services/agent_service/service.py` `save_memory()` 내:

```python
# Before
current_turn = len(history) // 2

# After
from langchain_core.messages import HumanMessage
current_turn = sum(1 for msg in history if isinstance(msg, HumanMessage))
```

history slice 계산도 함께 검토 필요:
현재 `history[last_consolidated * 2:]` — turn counter 방식 변경 시 slice 기준도 맞춰야 함.
