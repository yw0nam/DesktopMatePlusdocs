# DesktopMatePlus — Lead Agent Coordination

> **Lead Agent Rule**: This agent delegates and coordinates ONLY. Never writes code directly.
> All implementation is delegated to `developer` agent via Agent Teams.

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

- [ ] **DH-F1: Chat Bar Drag Fix** — ControlBar.tsx 이벤트 처리 수정 (button→div, preventDefault, DRAG_SCALE 튜닝). DoD: 드래그 핸들로 Webview 위치 이동 가능. Depends: none. [target: desktop-homunculus/]
- [ ] **DH-F2: TTS Sequential Playback** — service.ts에 TtsChunkQueue 구현 (sequence reordering buffer, 3s timeout, flush on stream_end). DoD: sequence 역순 도착 시에도 올바른 순서로 재생 + 단위 테스트. Depends: none. [target: desktop-homunculus/]
- [ ] **DH-F3: Screen Capture - Service Layer** — node-screenshots + sharp 설치, RPC methods 추가 (listWindows, captureScreen, captureWindow). DoD: RPC 호출로 캡쳐 이미지 base64 반환. Depends: none. [target: desktop-homunculus/]
- [ ] **DH-F4: Screen Capture - UI** — ControlBar에 캡쳐 toggle + 모드 선택 (전체화면/윈도우) UI 추가. DoD: toggle ON/OFF + 모드 전환 + 윈도우 목록 표시. Depends: DH-F3. [target: desktop-homunculus/]
- [ ] **DH-F5: Screen Capture - Message Integration** — sendMessage RPC에 images 파라미터 연결, 메시지 전송 시 캡쳐 이미지 자동 첨부. DoD: 캡쳐 모드 ON + Send → 이미지가 chat_message에 포함. Depends: DH-F3, DH-F4. [target: desktop-homunculus/]

### Phase 13: FE Design Agent — Agent Team 추가

<!-- spec-ref: ~/.gstack/projects/yw0nam-D/spow12-master-design-20260331-155718.md -->

- [x] **DA-S1: Create .claude/agents/design-agent.md** cc:DONE — agent 정의 파일 생성. DoD: name/description/model/skills/lifecycle/guardrails 포함, FE feature 판별 기준 명시. Depends: none. [target: DesktopMatePlus/]
- [x] **DA-S2: Update CLAUDE.md — Agent Teams + Lead flow** cc:DONE — design-agent 테이블 행 추가, Lead 흐름에 FE 분기 추가, docs/faq/ 링크. DoD: CLAUDE.md Agent Teams 테이블 + 흐름 다이어그램 반영. Depends: DA-S1. [target: DesktopMatePlus/]
- [x] **DA-S3: Create docs/faq/fe-design-agent-workflow.md** cc:DONE — FAQ 문서화. DoD: "언제 design-agent를 스폰하는가", "E2E scaffold vs unit test 경계", "design/{branch} PR 흐름" 포함. Depends: DA-S1. [target: DesktopMatePlus/]
- [x] **DA-S4: Update Plans.md DA-xxx task conventions** cc:DONE — DA 태스크 형식 예시 + cc:TODO DA 컨벤션 문서화. DoD: Plans.md 상단 Repos 테이블 + 태스크 형식에 DA 관련 내용 반영. Depends: DA-S2. [target: DesktopMatePlus/]
- [ ] **DA-S5: design-agent 파일럿 실행** — Phase 12 DH-F3(Screen Capture) 기준으로 실제 동작 검증. DoD: HTML mockup + ScreenCapture 컴포넌트 스펙 + E2E scaffold(signal setup + describe/it) 3개 파일 생성 확인. Depends: DA-S1, DA-S2. [target: desktop-homunculus/]

## Completed
