# Phase 25: desktopmate-bridge WS + Drag 신뢰성 버그 수정

archived: 2026-04-07  
spec-ref: docs/TODO.md#spec-12

## Tasks (all cc:DONE)

- [x] **DH-F1: store.ts resetStreaming 액션 추가** cc:DONE [c0deb22] — `store.ts`에 `resetStreaming` 액션 추가 (isTyping=false, streamingText=null). DoD: 액션 존재 + unit test. Depends: none. [target: desktop-homunculus/]
- [x] **DH-F2: service.ts 무음 실패 + 재시도 + error 핸들러 수정** cc:DONE [2576337] — Fix A(sendWsMessage가 WS 미연결 시 `{ok:false}` 반환) + Fix C(shouldRetry에 1006 추가) + Fix D(connectWithRetry에 error 이벤트 핸들러 추가). DoD: WS 미연결 sendMessage → `{ok:false}`, 1006 재시도 동작, error 이벤트 로깅. Depends: DH-F1. [target: desktop-homunculus/]
- [x] **DH-F3: useSignals.ts isTyping 리셋** cc:DONE [8bebef5] — Fix E: `dm-connection-status` 핸들러에서 disconnected 시 `resetStreaming()` 호출. DoD: 스트리밍 중 연결 끊김 → isTyping 즉시 false. Depends: DH-F1. [target: desktop-homunculus/]
- [x] **DH-F4: ControlBar.tsx Send 버튼 비활성화 + Drag 스케일 수정** cc:DONE [145fd78] — Fix B(disconnected 시 Send 버튼 disabled) + Fix F(Vec2 타입 `?.[0]` + fallback 1.0). DoD: Send 버튼 상태 반영 + 드래그 1:1 비율 동작. Depends: DH-F2, DH-F3. [target: desktop-homunculus/]
- [x] **DH-F5: unit tests + E2E 검증** cc:DONE [145fd78] — 6개 Fix 전부에 대한 unit test 작성 + 기존 E2E (TC-LC, TC-CW) PASS 확인. DoD: 전체 테스트 PASS. Depends: DH-F4. [target: desktop-homunculus/]
