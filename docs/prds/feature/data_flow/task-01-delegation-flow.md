# Task 01: Non-Blocking Delegation Flow (E2E)

**Parent**: §6 Interaction Flow
**Priority**: P0
**Depends on**: fastapi_backend/task-01, fastapi_backend/task-02, core_bridge/task-01

---

## Goal

Unity → FastAPI(PersonaAgent) → NanoClaw → Callback → 다음 턴 보고의 전체 비동기 위임 흐름을 E2E로 연결한다.

## Flow

```
1. Unity: "auth-fix 브랜치 코드 리뷰 좀 해줘."
2. FastAPI(PersonaAgent): DelegateTaskTool 트리거
   → task_id 생성 → pending_tasks에 추가 (running)
   → 스트리밍 응답: "코드 리뷰 팀에 작업을 지시했습니다."
3. FastAPI → NanoClaw: POST /api/webhooks/fastapi (fire-and-forget)
   → NanoClaw: 202 Accepted
4. NanoClaw 내부: Persona 순차 실행
5. NanoClaw → FastAPI: POST /api/callback/nanoclaw
   → task_id + status + summary
6. FastAPI: pending_tasks 업데이트 + synthetic message 삽입
7. 다음 사용자 발화 시: PersonaAgent가 system 메시지를 읽어 보고
```

## Integration Test Scenarios

### Happy Path

- [ ] 위임 요청 → NanoClaw 실행 → callback 수신 → 다음 턴에서 결과 보고

### Failure: NanoClaw Callback 누락

- [ ] TTL 초과 → Background Sweep이 failed 마킹 → 다음 턴에서 실패 보고

### Failure: NanoClaw에서 error 반환

- [ ] Callback의 `status: "failed"` → synthetic message 삽입 → 다음 턴에서 실패 사유 보고

## Acceptance Criteria

- [ ] 전체 E2E 흐름이 non-blocking으로 동작한다
- [ ] PersonaAgent가 위임 중에도 사용자와 대화를 계속할 수 있다
- [ ] 성공/실패 모두 다음 턴에서 적절히 보고된다
