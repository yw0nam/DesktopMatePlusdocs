# DesktopMatePlus — Lead Agent Coordination

> **Lead Agent Rule**: This agent delegates and coordinates ONLY. Never writes code directly.
> All implementation is delegated to `worker` agent via Agent Teams.

## Repos

| Short | Repo | Stack | Constraint |
|-------|------|-------|------------|
| BE | `backend/` | Python / FastAPI / uv | — |
| NC | `nanoclaw/` | Node.js / TypeScript | skill-as-branch only (no direct source edit) |
| FE | `desktop-homunculus/` | Rust / Bevy + TypeScript MOD | separate git repo |

## Task ID Conventions

| Prefix | Meaning | Agent | Notes |
|--------|---------|-------|-------|
| `BE-*` | Backend task | worker (BE) | FastAPI / Python |
| `NC-*` | NanoClaw task | worker (NC) | skill-as-branch only |
| `DH-F*` | desktop-homunculus feature | worker (FE) | FE visible UI |
| `DA-S*` | Design Agent setup/docs | worker (docs) | DesktopMatePlus root |
| `DA-*` | Design Agent FE feature | design-agent → worker (FE) | Use when PM spec targets `desktop-homunculus/` + UI change |

### DA-xxx 태스크 작성 규칙

`DA-` prefix는 design-agent가 개입하는 FE feature 태스크에 사용한다.

형식:
```
- [ ] **DA-{N}: {feature name}** — {summary}. DoD: {criteria}. Depends: {id or none}. [target: desktop-homunculus/]
```

DA 태스크 Phase에는 다음 2개 태스크 유형을 함께 작성한다:

1. **DA-{N}-design**: design-agent 산출물 태스크 (mockup + spec + E2E scaffold)
   - DoD: `design/{feature}/` 브랜치에 3개 artifacts 존재 + DESIGN_READY 신호
2. **DA-{N}-impl**: worker 구현 태스크 (design-agent PR base로 구현)
   - DoD: E2E scaffold assertion 구현 + unit test 통과 + /review APPROVE
   - Depends: DA-{N}-design

## Active Cross-Repo Tasks

<!-- cc:TODO format: [ ] **TASK-ID: description** — summary. DoD: criteria. Depends: id or none. spec-ref: docs/superpowers/specs/{file}.md. [ref: INDEX#{section}/{id}] (feature tasks only). [target: repo/] -->

### Phase 12: Desktop Homunculus FE UX Improvements (REVERTED — redesign needed)

<!-- spec-ref: ~/.gstack/projects/yw0nam-D/spow12-master-design-20260331-104740.md -->
<!-- NOTE: All Phase 12 code reverted (commit 8712cd3). Needs redesign with backend integration testing before re-implementation. -->

- [x] **DH-F1: Chat Bar Drag Fix** cc:DONE [a779aad] — ControlBar.tsx 이벤트 처리 수정 (button→div, preventDefault, DRAG_SCALE 튜닝). DoD: 드래그 핸들로 Webview 위치 이동 가능. Depends: none. [target: desktop-homunculus/]
- [x] **DH-F2: TTS Sequential Playback** cc:DONE [eb142b9] — service.ts에 TtsChunkQueue 구현 (sequence reordering buffer, 3s timeout, flush on stream_end). DoD: sequence 역순 도착 시에도 올바른 순서로 재생 + 단위 테스트. Depends: none. [target: desktop-homunculus/]
- [x] **DH-F3: Screen Capture - Service Layer** cc:DONE [b4e27ab] — node-screenshots + sharp 설치, RPC methods 추가 (listWindows, captureScreen, captureWindow). DoD: RPC 호출로 캡쳐 이미지 base64 반환. Depends: none. [target: desktop-homunculus/]
- [x] **DH-F4: Screen Capture - UI** cc:DONE [24f38df] — ControlBar에 캡쳐 toggle + 모드 선택 (전체화면/윈도우) UI 추가. DoD: toggle ON/OFF + 모드 전환 + 윈도우 목록 표시. Depends: DH-F3. [target: desktop-homunculus/]
- [x] **DH-F5: Screen Capture - Message Integration** cc:DONE [beeec85] — sendMessage RPC에 images 파라미터 연결, 메시지 전송 시 캡쳐 이미지 자동 첨부. DoD: 캡쳐 모드 ON + Send → 이미지가 chat_message에 포함. Depends: DH-F3, DH-F4. [target: desktop-homunculus/]

### Phase 12 후속: Backend 버그

- [x] **BE-BUG-1: Session Continuity Error** cc:DONE [bad7ef8] — 동일 session_id로 두 번째 메시지 전송 시 `"메시지 처리 중 오류가 발생했습니다."` 반환 후 stream_end 없이 종료. 원인: `stream()`이 매 턴 SystemMessage(persona) prepend → 중간에 SystemMessage 삽입 → LLM API 400. Fix: 신규 세션(empty session_id)에서만 persona inject. DoD: `sessions.test.ts` 11/11 E2E 통과. Depends: none. [target: backend/]

### Phase 13: FE Design Agent — Agent Team 추가

<!-- spec-ref: ~/.gstack/projects/yw0nam-D/spow12-master-design-20260331-155718.md -->

- [x] **DA-S1: Create .claude/agents/design-agent.md** cc:DONE — agent 정의 파일 생성. DoD: name/description/model/skills/lifecycle/guardrails 포함, FE feature 판별 기준 명시. Depends: none. [target: DesktopMatePlus/]
- [x] **DA-S2: Update CLAUDE.md — Agent Teams + Lead flow** cc:DONE — design-agent 테이블 행 추가, Lead 흐름에 FE 분기 추가, docs/faq/ 링크. DoD: CLAUDE.md Agent Teams 테이블 + 흐름 다이어그램 반영. Depends: DA-S1. [target: DesktopMatePlus/]
- [x] **DA-S3: Create docs/faq/fe-design-agent-workflow.md** cc:DONE — FAQ 문서화. DoD: "언제 design-agent를 스폰하는가", "E2E scaffold vs unit test 경계", "design/{branch} PR 흐름" 포함. Depends: DA-S1. [target: DesktopMatePlus/]
- [x] **DA-S4: Update Plans.md DA-xxx task conventions** cc:DONE — DA 태스크 형식 예시 + cc:TODO DA 컨벤션 문서화. DoD: Plans.md 상단 Repos 테이블 + 태스크 형식에 DA 관련 내용 반영. Depends: DA-S2. [target: DesktopMatePlus/]
- [x] **DA-S5: design-agent 파일럿 실행** cc:DONE — Phase 12 DH-F4(Screen Capture UI) 기준으로 실제 동작 검증. DoD: HTML mockup + ScreenCaptureUI 컴포넌트 스펙 + E2E scaffold(signal setup + describe/it) 3개 파일 생성 확인. Depends: DA-S1, DA-S2. [target: desktop-homunculus/]

### Phase 14: desktopmate-bridge 버그 수정 (Adversarial Review 후속)

<!-- source: /ship adversarial review — desktop-homunculus PR #2 (2026-04-01) -->

- [x] **DH-BUG-2: Token leak via getStatus RPC + dm-config signal** cc:DONE [09fa4f5] — `service.ts:424` `getStatus`가 `fastapi_token`을 평문으로 반환, `broadcastConfig`도 `dm-config` signal에 토큰 포함. 구독 모드 인식 가능. DoD: getStatus/broadcastConfig에서 token 필드 제거. Depends: none. [target: desktop-homunculus/]
- [x] **DH-BUG-3: TtsChunkQueue flush 동시성 버그** cc:DONE [b2c3fc8] — `tts-chunk-queue.ts` `flush()`가 모든 청크를 fire-and-forget으로 dispatch → VRM `speakWithTimeline` 동시 호출 → 오디오 겹침/뒤섞임. DoD: processor 호출을 순차 직렬화(await each), 단위 테스트 추가. Depends: none. [target: desktop-homunculus/]
- [x] **DH-BUG-4: JSON.parse try/catch 누락** cc:DONE [7b83421] — `service.ts:303` WebSocket 프레임 파싱에 try/catch 없음 → 잘못된 프레임 수신 시 메시지 처리 중단되지만 UI는 "connected" 유지. DoD: try/catch 추가 + 파싱 실패 시 `dm-connection-status` error 신호 전송. Depends: none. [target: desktop-homunculus/]
- [x] **DH-BUG-5: connectWithRetry 구 WebSocket 미취소** cc:DONE [7b83421] — `service.ts:466` reconnect 시 기존 `_ws` close 이벤트가 재발화하여 두 개의 연결 경로 생성 가능. DoD: reconnect 전 기존 _ws.onclose = null 처리. Depends: none. [target: desktop-homunculus/]
- [x] **DH-BUG-6: URL 파라미터 미인코딩** cc:DONE [298dd76] — `api.ts:1543` `user_id`/`agent_id`/`session_id` 직접 문자열 보간 → 특수문자 포함 시 쿼리 스트링 오염. DoD: URLSearchParams 사용으로 교체. Depends: none. [target: desktop-homunculus/]
- [x] **DH-BUG-7: captureScreen 빈 모니터 배열 미방어** cc:DONE [298dd76] — `screen-capture.ts:210` `monitors[0]` 접근 시 빈 배열 가드 없음 → headless 환경에서 TypeError 크래시. DoD: 빈 배열 체크 + 명확한 에러 메시지. Depends: none. [target: desktop-homunculus/]
- [x] **DH-BUG-8: open-chat TOCTOU — 동일 Webview 두 인스턴스** cc:DONE [298dd76] — `open-chat.ts:93` `isClosed()` 체크와 `close()` 호출이 서로 다른 `new Webview(entity)` 인스턴스 사용 → 체크 후 외부에서 닫힌 경우 `close()` 예외 → 실패 토스트 표시. DoD: 단일 인스턴스로 재사용. Depends: none. [target: desktop-homunculus/]

### Phase 15: desktopmate-bridge + Fish Speech 버그 수정 (2026-04-01 리뷰 결과)

<!-- source: reviewer 리뷰 — make debug 실행 테스트 후 5개 버그 + fish_speech 추가 2개 발견 -->

- [x] **DH-BUG-9: TTS 동시 재생** cc:DONE [a624ed0] — `waitForCompletion: false → true`. Depends: none. [target: desktop-homunculus/]
- [x] **BE-BUG-2: Fish Speech 에러 로그 복원** cc:DONE [3fe1836] — except 블록 logger.error 주석 복원. Depends: none. [target: backend/]
- [x] **BE-BUG-3: Fish Speech TTS 직렬 큐 워커** cc:DONE [3fe1836] — `FishSpeechTTS` asyncio.Queue + `_serial_worker` 코루틴, timeout 120s, main.py lifespan 연결. Depends: BE-BUG-2. [target: backend/]
- [x] **BE-BUG-4: stream_token WS 미전달** cc:DONE [3fe1836] — `_put_token_event` 후 `_put_event`로 WS 클라이언트에도 forward. Depends: none. [target: backend/]
- [x] **DH-BUG-10: stream_token FE 미표시** cc:DONE [a624ed0] — `stream_token` → `dm-stream-token` signal, `useSignals.ts` 구독 추가. Depends: BE-BUG-4. [target: desktop-homunculus/]
- [x] **DH-BUG-11: images 타입 불일치** cc:DONE [a624ed0] — captureImages() ImageContent 객체 반환, RPC schema + api.ts 타입 동기화. Depends: none. [target: desktop-homunculus/]
- [x] **DH-BUG-12: Webview drag 스케일 오류 + async 레이스** cc:DONE [a624ed0] — 동적 scale 계산, RAF throttle (latestMoveRef 패턴). Depends: none. [target: desktop-homunculus/]
- [x] **DH-BUG-13: Reconnect 버튼** cc:DONE [f628053] — service.ts reconnect RPC, api.ts reconnect(), ControlBar ReconnectButton 컴포넌트 (isReconnecting 상태). Depends: none. [target: desktop-homunculus/]

## Completed
