# Task 03: Background Sweep Task

**Parent**: §1 The Director (FastAPI Backend)
**Priority**: P1
**Depends on**: Task 01 (DelegateTaskTool)

---

## Goal

NanoClaw가 callback을 보내지 못한 경우(네트워크 장애, 컨테이너 크래시 등)를 대비하여, TTL 초과 Task를 자동으로 `failed` 처리하는 백그라운드 작업을 구현한다.

## Scope

- FastAPI lifespan에서 주기적으로 실행되는 asyncio background task
- `pending_tasks` 중 `created_at + TTL`을 초과한 `running` 상태 Task를 스캔
- 조건 충족 시 `status: "failed"` 마킹 + synthetic message 삽입
- TTL 값은 설정 가능 (기본값: 10분)
- 스캔 주기도 설정 가능 (기본값: 60초)

## Acceptance Criteria

- [ ] Background task가 FastAPI lifespan과 함께 시작/종료된다
- [ ] TTL 초과 task가 `failed`로 마킹된다
- [ ] 마킹 시 실패 사유 synthetic message가 삽입된다
- [ ] 이미 `done` 또는 `failed`인 task는 건너뛴다
- [ ] TTL, 스캔 주기가 config에서 설정 가능하다
