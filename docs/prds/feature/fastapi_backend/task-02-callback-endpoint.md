# Task 02: NanoClaw Callback Endpoint

**Parent**: §1 The Director (FastAPI Backend)
**Priority**: P0
**Depends on**: Task 01 (DelegateTaskTool), 기존 STM Service

---

## Goal

NanoClaw가 작업 완료/실패 시 결과를 전달할 HTTP Webhook Endpoint를 구현한다.

## Scope

- `POST /v1/callback/nanoclaw/{session_id}` 엔드포인트 구현 (`src/api/routes/callback.py`)
- session_id는 URL path parameter로 전달 (DelegateTaskTool이 callback_url에 포함)
- 수신 payload: `{ task_id, status("done"|"failed"), summary }`
- 처리 로직:
  1. `task_id`로 `session.metadata.pending_tasks` 조회
  2. status를 `done` 또는 `failed`로 업데이트
  3. 요약본을 STM chat history에 synthetic message로 삽입
  4. (향후 확장점) Push 알림은 [TODO/task-01](../TODO/task-01-push-notification.md)에서 처리

## Synthetic Message Schema

```json
{
  "role": "system",
  "content": "[TaskResult:{task_id}] 코드 리뷰 완료 - 보안 결함 1건 발견 (line 45)"
}
```

## 실패 보고 경로

`status: "failed"`인 경우에도 동일하게 synthetic message를 삽입한다. 내용에 실패 사유를 포함하여 다음 사용자 발화 시 PersonaAgent가 보고한다.

```json
{
  "role": "system",
  "content": "[TaskFailed:{task_id}] 코드 리뷰 실패 - NanoClaw 컨테이너 타임아웃"
}
```

## Acceptance Criteria

- [ ] Callback endpoint가 `task_id` 기반으로 Task Record를 업데이트한다
- [ ] 성공/실패 모두 synthetic message가 chat history에 삽입된다
- [ ] 존재하지 않는 `task_id`에 대해 404를 반환한다
