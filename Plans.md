# DesktopMatePlus — Lead Agent Coordination

> **Lead Agent Rule**: This agent delegates and coordinates ONLY. Never writes code directly.
> All implementation is delegated to `developer` agent via Agent Teams.

## Repos

| Short | Repo | Stack | Constraint |
|-------|------|-------|------------|
| BE | `backend/` | Python / FastAPI / uv | — |
| NC | `nanoclaw/` | Node.js / TypeScript | skill-as-branch only (no direct source edit) |
| FE | `desktop-homunculus/` | Rust / Bevy + TypeScript MOD | separate git repo |

## Active Cross-Repo Tasks

<!-- cc:TODO format: [ ] **TASK-ID: description** — summary. DoD: criteria. Depends: id or none. spec-ref: docs/superpowers/specs/{file}.md. [ref: INDEX#{section}/{id}] (feature tasks only). [target: repo/] -->

### Phase 12: Desktop Homunculus FE UX Improvements

<!-- spec-ref: ~/.gstack/projects/yw0nam-D/spow12-master-design-20260331-104740.md -->

- [ ] **DH-F1: Chat Bar Drag Fix** — ControlBar.tsx 이벤트 처리 수정 (button→div, preventDefault, DRAG_SCALE 튜닝). DoD: 드래그 핸들로 Webview 위치 이동 가능. Depends: none. [target: desktop-homunculus/]
- [ ] **DH-F2: TTS Sequential Playback** — service.ts에 TtsChunkQueue 구현 (sequence reordering buffer, 3s timeout, flush on stream_end). DoD: sequence 역순 도착 시에도 올바른 순서로 재생 + 단위 테스트. Depends: none. [target: desktop-homunculus/]
- [ ] **DH-F3: Screen Capture - Service Layer** — node-screenshots + sharp 설치, RPC methods 추가 (listWindows, captureScreen, captureWindow). DoD: RPC 호출로 캡쳐 이미지 base64 반환. Depends: none. [target: desktop-homunculus/]
- [ ] **DH-F4: Screen Capture - UI** — ControlBar에 캡쳐 toggle + 모드 선택 (전체화면/윈도우) UI 추가. DoD: toggle ON/OFF + 모드 전환 + 윈도우 목록 표시. Depends: DH-F3. [target: desktop-homunculus/]
- [ ] **DH-F5: Screen Capture - Message Integration** — sendMessage RPC에 images 파라미터 연결, 메시지 전송 시 캡쳐 이미지 자동 첨부. DoD: 캡쳐 모드 ON + Send → 이미지가 chat_message에 포함. Depends: DH-F3, DH-F4. [target: desktop-homunculus/]

## Completed
