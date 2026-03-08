# Task 02: Direct Access (IPC 파일 직접 작성)

**Parent**: §4 The Observers & Bypasses
**Priority**: P2
**Depends on**: 없음

---

## Goal

Unity/FastAPI를 거치지 않고 NanoClaw에 직접 명령을 주입할 수 있는 경로를 문서화하고 검증한다.

## Scope

- `ipc/{group}/tasks/`에 task JSON 파일을 직접 작성하면 기존 IPC watcher가 처리
- 별도 채널 메커니즘 불필요 — NanoClaw의 기존 IPC 인프라를 그대로 활용
- 디버깅/테스트 용도의 CLI 스크립트 작성 (선택)

## Acceptance Criteria

- [ ] IPC 파일 직접 작성으로 NanoClaw task가 실행된다
- [ ] 기존 채널(Slack, HTTP)과 충돌 없이 동작한다
