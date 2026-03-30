# TODO 01: Push 알림

**Status**: 보류
**Priority**: P2
**Depends on**: fastapi_backend/task-02, frontend/task-01

---

## 문제

현재 Pull 방식 — 사용자가 다음 발화를 해야 위임 결과를 받는다. "Alive" 컨셉과 충돌할 수 있음.

## 방향

Callback 수신 시 WebSocket을 통해 FE에 알림 push. WebSocket은 이미 있으므로 기술적 난이도 낮음.

## 필요 사항

- FastAPI callback handler에서 WebSocket push 호출 (hook point는 task-02에서 준비)
- FE 알림 UI 구현 (토스트? 말풍선?)
- PersonaAgent가 push로 보고할지, 다음 턴에서 보고할지 중복 방지 정책

## 트리거 시점

FE 알림 UI 디자인 확정 후 구현.
