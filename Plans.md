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

<!-- BE 태스크 DoD 표준: 신규 BE-* 태스크는 `bash backend/scripts/e2e.sh` PASSED를 DoD 체크리스트에 포함해야 함. 기존 cc:DONE 태스크에는 소급 적용하지 않음. -->

<!-- Phases 12–17, 19–20: archived to docs/archive/plans-2026-04.md on 2026-04-03 -->

### Phase 18: OpenSpace 시범 도입 (backend) — 유저 지시 시 진행

<!-- triggered by: user request only. Do NOT start autonomously. -->
<!-- OpenSpace: 로컬 실행. Dashboard backend: http://localhost:7788, Frontend: http://localhost:3789 -->
<!-- Cloud 미사용 (OPENSPACE_API_KEY 불필요). 모든 스킬은 로컬 저장. -->
<!-- LLM: 로컬 vLLM (http://192.168.0.41:5535, OpenAI-compatible API). OPENSPACE_LLM_API_BASE=http://192.168.0.41:5535/v1, OPENSPACE_LLM_API_KEY=token-abc123, OPENSPACE_MODEL=openai/chat_model -->

- [ ] **INFRA-1: OpenSpace MCP 설정 (backend)** cc:TODO — `OpenSpace/` repo를 backend worker용 MCP 서버로 등록 (로컬 전용, cloud 미사용). `.claude/settings.json`에 openspace MCP 추가, `OPENSPACE_HOST_SKILL_DIRS`를 backend skills 경로로 지정. Dashboard: backend `http://localhost:7788`, frontend `http://localhost:3789`. DoD: worker가 openspace MCP 도구 호출 가능. Depends: none. [target: DesktopMatePlus/]
- [ ] **INFRA-2: OpenSpace host_skills 배치** cc:TODO — `delegate-task/SKILL.md` + `skill-discovery/SKILL.md`를 backend worker가 참조할 수 있는 위치에 복사. DoD: worker가 skill-discovery로 기존 스킬 검색 가능. Depends: INFRA-1. [target: backend/]
- [ ] **INFRA-3: 효과 측정 기준 정의** cc:TODO — 토큰 사용량 비교(Phase 17 대비), 자동 캡처된 스킬 수, 스킬 재사용률 지표 정의. DoD: 측정 기준 문서 작성. Depends: INFRA-1. [target: DesktopMatePlus/]
- [ ] **INFRA-4: 파일럿 태스크 실행 + 평가** cc:TODO — backend 태스크 2~3개를 OpenSpace 적용 worker로 실행, Phase 17 동일 유형 태스크와 비교. DoD: 효과 측정 보고서 작성. Depends: INFRA-2, INFRA-3. [target: backend/]

### Phase 26: Quality Debt 해소 (2026-04-07) — source: quality-2026-04-07.md

- [x] **QD-1: quality-agent uv PATH 수정** cc:DONE [0148233] — `scripts/run-quality-agent.sh` 또는 `scripts/garden.sh`에서 uv PATH 설정 추가. GP-1/GP-2/GP-10 backend 검사 전부 uv 미발견으로 스킵되는 문제 해결. DoD: `scripts/garden.sh` 실행 시 backend lint/test/structural 전부 동작. Depends: none. [target: DesktopMatePlus/]
- [x] **QD-2: Phase 25 아카이브** cc:DONE [0148233] — Phase 25 (cc:DONE 5개) 아카이브 처리. DoD: Plans.md에 archived 링크만 남음. Depends: none. [target: DesktopMatePlus/]
- [x] **QD-3: dead link 수정** cc:DONE [0148233] — `docs/data_flow/chat/ADD_CHAT_MESSAGE.md`의 삭제된 파일 참조 2개 수정/제거. DoD: `scripts/check_docs.sh` dead link 0. Depends: none. [target: DesktopMatePlus/]
- [x] **QD-4: oversized doc 분리** cc:DONE [0148233] — `docs/faq/desktop-homunculus-mod-system.md` 259줄 → 200줄 이하로 분리. DoD: 200줄 한도 준수. Depends: none. [target: DesktopMatePlus/]
- [x] **QD-5: E2E test 파일 분할** cc:DONE [825aca2] — `desktopmate-bridge/tests/e2e/connection-lifecycle.test.ts` 416→371줄, TC-LC-08 → `session-continuity.test.ts`로 분리. DoD: GP-13 file size 위반 0. Depends: none. [target: desktop-homunculus/]
- [x] **QD-6: ControlBar.test.tsx 파일 분할** cc:DONE [825aca2] — `desktopmate-bridge/tests/ControlBar.test.tsx` 432→351줄, DH-BUG-13 reconnect 테스트 → `ControlBar.reconnect.test.tsx`로 분리. DoD: GP-13 file size 위반 0. Depends: none. [target: desktop-homunculus/]
- [x] **QD-7: DH PR #14 리뷰 + 머지** cc:DONE — `fix/sweep-2026-04-07` post-merge sweep MERGED (2026-04-07). Reviewer PASS (12/12). Depends: none. [target: desktop-homunculus/]

### Phase 27: desktopmate-bridge SDK Adapter Pattern — spec-ref: docs/TODO.md#spec-13

- [ ] **DH-A1: sdk-adapter.ts 인터페이스 정의** cc:TODO — SdkAdapter 인터페이스 8개 오퍼레이션 (spawnVrm, sendSignal, onRpcCall, speakWithTimeline 등). DoD: 타입 체크 PASS. Depends: none. [target: desktop-homunculus/]
- [ ] **DH-A2: real-adapter.ts 구현** cc:TODO — @hmcs/sdk 래핑하는 production adapter. DoD: 기존 service.ts와 동일 동작. Depends: DH-A1. [target: desktop-homunculus/]
- [ ] **DH-A3: mock-adapter.ts 구현** cc:TODO — 순수 JS mock (EventEmitter signal, 로컬 RPC, VRM no-op) + 테스트 헬퍼 (onMockSignal, callMockRpc, resetMockAdapter). DoD: `HMCS_MOCK=1 pnpm test` unit PASS. Depends: DH-A1. [target: desktop-homunculus/]
- [ ] **DH-A4: service.ts 리팩토** cc:TODO — adapter 파라미터 주입 + isMain 가드 + connectAndServe/handleMessage named export. DoD: `HMCS_MOCK=1 pnpm test` 전체 PASS + 기존 E2E PASS. Depends: DH-A2, DH-A3. [target: desktop-homunculus/]
- [ ] **DH-A5: 신규 E2E 테스트** cc:TODO — signal-flow.test.ts + rpc-flow.test.ts + tts-flow.test.ts. Worker가 backend 직접 기동. DoD: `pnpm test:e2e` 전체 PASS. Depends: DH-A4. [target: desktop-homunculus/]

### Phase 28: backend E2E 마이그레이션 — spec-ref: docs/TODO.md#spec-14

- [ ] **BE-E1: tests/e2e/ 디렉토리 + conftest.py** cc:TODO — LogReader, e2e_session fixture, require_backend fixture 생성. pyproject.toml에 e2e marker 추가. DoD: `uv run pytest -m e2e --collect-only` 성공. Depends: none. [target: backend/]
- [ ] **BE-E2: WebSocket E2E 마이그레이션** cc:TODO — test_websocket_e2e.py 신규 (TTS chunk 3중 검증 포함). DoD: backend 기동 + pytest PASS. Depends: BE-E1. [target: backend/]
- [ ] **BE-E3: STM/LTM/Misc E2E 마이그레이션** cc:TODO — test_stm_e2e.py + test_ltm_e2e.py + test_misc_e2e.py 신규. DoD: pytest PASS. Depends: BE-E1. [target: backend/]
- [ ] **BE-E4: e2e.sh 교체 + examples 삭제** cc:TODO — scripts/e2e.sh Phase 4를 `pytest -m e2e --tb=long`으로 교체. examples/ 구 스크립트 4개 삭제. DoD: `bash scripts/e2e.sh` 전체 PASS. Depends: BE-E2, BE-E3. [target: backend/]

### Phase 25: desktopmate-bridge WS + Drag 신뢰성 버그 수정 — spec-ref: docs/TODO.md#spec-12 — [archived](docs/archive/phase-25-desktopmate-bridge-ws-drag.md)

### Phase 21: 워크플로우 문서 모순 해소 — spec-ref: docs/TODO.md#spec-6 — [archived](docs/superpowers/completed/plans/phase-21--spec-ref-docstodomdspec-6.md)
### Phase 22: Quality Debt 해소 — source: quality-2026-04-03.md — [archived](docs/superpowers/completed/plans/phase-22-quality-debt-source-quality-2026-04-03md.md)
### Phase 23: Mascot Reaction System + VRM Position UI — spec-ref: docs/TODO.md#spec-7, #spec-8 — [archived](docs/superpowers/completed/plans/phase-23-mascot-reaction-system-vrm-position-ui-spec-ref-docstodomdspec-7-spec-8.md)
### Phase 24: desktopmate-bridge 백엔드 연결 E2E 테스트 — spec-ref: docs/TODO.md#spec-11 — [archived](docs/superpowers/completed/plans/phase-24-desktopmate-bridge-e2e-spec-ref-docstodomdspec-11.md)
