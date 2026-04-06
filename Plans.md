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

### Phase 21: 워크플로우 문서 모순 해소 — spec-ref: docs/TODO.md#spec-6

<!-- source: docs/TODO.md Spec 6 (2026-04-03). 7개 모순 항목 수정. -->

- [x] **WF-1: Agent definition 파일 수정** cc:DONE — `.claude/agents/` 내 4개 파일 일관성 수정. ① `quality-agent.md` Constraints에 "PR 생성은 run-quality-agent.sh 담당" 명시 ② `create-pr` 스킬 디렉토리 삭제 ③ `pr-merge-agent.md` quality PR 블록 로직 → AUTO_FIX/ACKNOWLEDGE/NEEDS_LEAD 분류로 교체, `run-quality-agent.sh` PR body 직접 체크 안내 제거 ④ `pm-agent.md` Lifecycle Step 4 "PM writes Plans.md" → "PM writes docs/TODO.md, Plans.md는 Lead 책임" ⑤ `pr-merge-agent.md` 용어 "봇/사람 리뷰어" → "GitHub Bot Reviewer / GitHub Human Reviewer". DoD: 5개 항목 반영 완료. [target: DesktopMatePlus/]
- [x] **WF-2: CLAUDE.md·FAQ·PR 템플릿 수정** cc:DONE — ① `CLAUDE.md` Agent Teams Flow에 "APPROVE 후 worker가 /ship" 타이밍 명시 ② `CLAUDE.md` Worktree Rules + `docs/faq/fe-design-agent-workflow.md`에 브랜치 prefix 규칙 (`{prefix}/p{N}-t{id}`, prefix ∈ `{feat,fix,docs,refactor,chore,test,ci,build}`) 및 design-agent → worker 브랜치 인계 흐름 추가 ③ `.github/pull_request_template.md` 첫 번째 체크박스를 "i already confirm E2E test is passed"로 변경 ④ `safety-guardrails.md` quality-agent 행에 "(AI agent 기준)" 주석 추가. DoD: 4개 항목 반영 완료. Depends: none. [target: DesktopMatePlus/]

### Phase 22: Quality Debt 해소 — source: quality-2026-04-03.md

<!-- source: docs/reports/quality-2026-04-03.md (2026-04-03). GP-3/4/13 위반 + garden.sh 버그 + 아카이브 정리. -->

- [x] **QA-1: BE GP-4 하드코딩 URL 해소** cc:DONE — `backend/` 내 하드코딩 URL 5개를 `yaml_files/` YAML 설정 또는 환경변수로 이전. 대상: `vllm_omni.py:20` (base_url), `tts_factory.py:38` (IRODORI_URL), `disconnect_handler.py:11` (BACKEND_URL), `agent_factory.py:46` (openai_api_base), `delegate_task.py:15` (NANOCLAW_URL). DoD: GP-4 PASS + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **QA-2: BE GP-3 bare print 제거** cc:DONE — `ltm_factory.py:40,50,52`, `vllm_omni.py:264,272` bare print → loguru. DoD: GP-3 PASS + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **QA-3: DH-MOD GP-13 console.log + 파일 크기** cc:DONE — ① `tts-chunk-queue.ts:85,104` console.log 제거 (프로덕션 코드) ② `ControlBar.test.tsx` (445줄) → 400줄 이하로 분리. DoD: GP-13-console PASS + GP-13-size PASS. Depends: none. [target: desktop-homunculus/]
- [x] **QA-4: garden.sh 버그 수정 + scripts/ 예외 처리** cc:DONE — ① GP-13 console.log 체크에서 `mods/*/scripts/` 디렉토리 제외 ② `update_quality_score()` 함수가 `QUALITY_SCORE.md` Violations Summary 섹션을 실제 위반 수로 갱신하도록 수정. DoD: GP-13-console이 scripts/ 파일을 스캔하지 않음 + QUALITY_SCORE.md Violations Summary가 정확히 갱신됨. Depends: none. [target: DesktopMatePlus/]
- [x] **QA-5: Plans.md 아카이브 + docs/superpowers check_docs 제외** cc:DONE — ① Plans.md Phase 12~20 완료 Phase → `docs/archive/plans-2026-04.md`로 이전 ② `scripts/check_docs.sh`에서 `docs/superpowers/` 디렉토리를 dead link 및 oversized 체크 제외 목록에 추가. DoD: Plans.md cc:DONE Phase 5개 미만 잔존 + GP-12 PASS + check_docs.sh superpowers 스캔 안 함. Depends: none. [target: DesktopMatePlus/]

### Phase 23: Mascot Reaction System + VRM Position UI — spec-ref: docs/TODO.md#spec-7, #spec-8

<!-- source: docs/TODO.md Spec 7 (2026-04-04), Spec 8 (2026-04-04). -->

- [x] **BE-23-1: TTS speak endpoint 추가** cc:DONE [1fb7a27] — `backend/src/api/routes/tts.py`에 `POST /v1/tts/speak` 추가 (`text` → `{ audio_base64 }`). DoD: Pytest TDD 통과 + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **DH-23-1: ReactionController 구현** cc:DONE [419386d] — `desktopmate-bridge/src/reaction-controller.ts` 신규. Click/Idle(5분)/ScreenContext(`active-win`) 3가지 트리거. `tts-chunk-queue.ts`에 `isBusy()` 추가(채팅 TTS 충돌 방지). `config.yaml`에 `reactions` 섹션 추가. `pnpm add active-win`. DoD: Vitest unit test 통과(click/idle/window 각 트리거) + E2E mock 테스트 통과 + 채팅 TTS 중 reaction skip. Depends: BE-23-1. [target: desktop-homunculus/]
- [x] **BE-23-fix: e2e 버그 수정** cc:DONE [8610cc1] — `invoke()` persona SystemMessage 중복 삽입 방지 (`and not session_id`). `ltm_middleware.py` SystemMessage 중복 주입 방지. `stm.py` session_registry upsert + checkpointer.delete_thread() 추가. DoD: e2e.sh Phase 4/5 PASSED. [target: backend/]
- [x] **DH-23-2: VRM Position Adjustment UI** cc:DONE [491d2be] — `character-settings` MOD `BasicTab.tsx`에 Position X/Y 슬라이더 + 숫자 입력 추가. `useCharacterSettings.ts` posX/posY state 추가. Save 클릭 시만 반영(실시간 미리보기 없음). `translation[2]` 보존 필수. DoD: Vitest unit test 통과 + `/agent-browser` visual verification + 슬라이더 range 실측 확인. Depends: none. [target: desktop-homunculus/]

### Phase 24: desktopmate-bridge 백엔드 연결 E2E 테스트 — spec-ref: docs/TODO.md#spec-11

<!-- source: docs/TODO.md Spec 11 (2026-04-06). P0. Reconnect/Settings Save 버그 + harsh E2E. -->
<!-- /autoplan restore point: /home/spow12/.gstack/projects/yw0nam-DesktopMatePlusdocs/master-autoplan-restore-20260406-095446.md -->

- [x] **DH-24-1: config-io.ts 추출** cc:DONE [5dcd3c1] — `src/config-io.ts` 신규 파일에 `applyConfigToDisk(config, input, configPath)` + `loadConfigFrom(configPath)` 추출. service.ts import chain 없음 필수. DoD: 기존 unit test 통과 + config-io.ts에 별도 unit test. Depends: none. [target: desktop-homunculus/]
- [x] **DH-24-2: connection-lifecycle E2E + config-write E2E** cc:DONE [6cf562b] — `tests/e2e/connection-lifecycle.test.ts` (TC-LC-01~08, 실제 FastAPI WS) + `tests/e2e/config-write.test.ts` (TC-CW-01~07). WS helper 함수(`openWs`, `collectMessages`, `authorizedWs`)를 `tests/e2e/helpers/ws.ts`로 추출하여 공유. **TC-LC-02 조건부 skip 필수**: `const backendSkipsTokenValidation = true; // TODO: backend token validation not implemented` 상수 선언 후 `it.skipIf(backendSkipsTokenValidation, ...)` 패턴 사용 — unconditional skip 금지 (backend에 token validation 구현 시 flag만 제거하면 복활). DoD: `pnpm test:e2e` 전체 PASS. Depends: DH-24-1. [target: desktop-homunculus/]
- [x] **DH-24-3: Playwright UI E2E** cc:DONE [5235229] — `tests/e2e/ui-browser.spec.ts` (TC-UI-01~05). `@playwright/test`를 `mods/desktopmate-bridge/ui/package.json` devDependencies에 추가 필수. `VITE_TEST_MODE=true` mock-sdk alias + Playwright 브라우저 테스트. `playwright.config.ts`에 `reporter: [['list'], ['html']]` + `use: { baseURL: 'http://localhost:5173' }` 명시 — Playwright 미설치 시 명확한 에러 출력 보장 (silent fail 방지). DoD: `pnpm playwright test` 전체 PASS. Depends: DH-24-2. [target: desktop-homunculus/]
- [x] **DH-24-4: 전체 E2E 실행 + 버그 수정** cc:DONE [f82e2cc] — TC-LC-*, TC-CW-*, TC-UI-* 전체 PASS 확인. 실패 시 TypeScript MOD 레이어(service.ts, ui/) 범위 내에서 버그 수정. Bevy/CEF 엔진 레이어 수정 불필요. DoD: 모든 20개 TC PASS (TC-LC-02 제외 시 skip 허용) + Reconnect/Settings Save 정상 동작. Depends: DH-24-3. [target: desktop-homunculus/]

<!-- reviewer: /autoplan CONDITIONAL PASS 2026-04-06 — see review report below -->

## GSTACK REVIEW REPORT — Phase 24 /autoplan (2026-04-06)

### Verdict: CONDITIONAL PASS

All premises valid. Spec architecture is sound. 5 issues identified — 3 already applied to task descriptions above. 2 require user confirmation before implementation.

---

### CEO Review

**Premises challenge:**

| # | Premise | Assessment |
|---|---------|------------|
| 1 | Tests connect directly to FastAPI WS — no Bevy/SDK/RPC | VALID. `websocket.test.ts` already proves this pattern works |
| 2 | "Functional" = authorize_success + stream_end completed | VALID. Sufficient behavioral contract |
| 3 | config.yaml file write is in E2E scope | VALID. The spec correctly avoids mocking file I/O |
| 4 | Error paths tested via real FastAPI WS direct manipulation | VALID. Pure TypeScript, no Bevy runtime needed |
| 5 | Real FastAPI backend required, local only, CI excluded | VALID. Correct tradeoff |

**Premise 5 nuance:** TC-LC-04 (stream interrupt → reconnect) is the TSM bug's core scenario. If the backend has a race condition on interrupted streams, this test is the one that will catch it. The 60s timeout is correct — 30s was too tight per design doc's own note.

**Dream state delta:**

```
CURRENT: reconnect.test.ts (mock-only) — zero WS behavior coverage
THIS PLAN: 20 TCs covering full WS lifecycle, config I/O, and UI flows
12-MONTH IDEAL: CI-compatible E2E with mock FastAPI (not real backend required)
```

**NOT in scope (deferred):**
- CI integration (requires mock FastAPI server)
- Backend token validation (TODO in backend — TC-LC-02 is a skip until then)
- Bevy/CEF engine-level TSM fix (out of MOD scope — if all TCs pass, that's the boundary)

**What already exists:**
- `websocket.test.ts`: `openWs`, `collectMessages`, `authorizedWs`, `hasMsgOfType`, `findMsg` helpers — reuse directly
- `vitest.e2e.config.ts`: auto-includes `tests/e2e/**/*.test.ts` — new files included automatically
- `tests/e2e/sessions.test.ts`: REST session CRUD pattern — TC-LC-08 can follow this pattern

**CEO Dual Voices:** Codex unavailable. Single-reviewer mode.

**Phase 1 complete.** Passing to Phase 2 (Design — UI scope detected).

---

### Design Review

**Scope:** `ui-browser.spec.ts` tests the React UI (`ControlBar`, Settings panel) via Playwright.

**Pass 1 — Information hierarchy:** The mock-sdk → Vite alias → React app chain is correct. The UI sees mock signals exactly as it would see real SDK signals. Architecture sound.

**Pass 2 — Missing states:**
- TC-UI-01 covers disconnected state ✓
- TC-UI-02 covers reconnecting (in-flight) + connected transition ✓
- TC-UI-05 covers disconnected-after-failure ✓
- **MISSING**: `restart-required` state not covered. The `ConnectionStatus` type has 3 states (`connected | disconnected | restart-required`). `restart-required` occurs after 3 failed retries. No TC validates this state in the UI. This is a MEDIUM gap — the UI renders this state but it's untested.

**Pass 3 — Interaction timing:**
- TC-UI-02: `reconnect` RPC is fire-and-forget in `service.ts` (returns `{ok: true}` before auth completes). Mock RPC in `rpc.ts` awaits the actual WS auth and emits `dm-connection-status` signal. This means the signal emission happens inside the browser (Playwright context), not from Node. This is the correct design.
- **CONCERN**: `window.__signalBus__` must be initialized BEFORE the React app's `useEffect` hooks run. The mock `index.ts` sets `window.__signalBus__ = new SignalBus()` synchronously at module load. Since the Vite alias replaces `@hmcs/sdk` at bundle time, the mock loads before any component mounts. Timing is fine.

**Pass 4 — Specificity:** TCs describe specific UI text assertions (`"✔ Connected"`, `"↺ Reconnecting…"`, `"✔ Saved"`). These must match the actual React component strings exactly. Worker must verify these match `ControlBar.tsx` and Settings component strings before writing assertions.

**Design litmus scorecard:**

| Dimension | Score | Notes |
|-----------|-------|-------|
| Information hierarchy | 8/10 | All key states covered |
| Missing states | 6/10 | `restart-required` state not in TCs |
| Interaction timing | 8/10 | Fire-and-forget correctly handled |
| Specificity | 7/10 | UI text strings need field verification |
| Error paths | 8/10 | TC-UI-05 covers invalid URL flow |
| Accessibility | N/A | Testing not in scope |

**Phase 2 complete.** Passing to Phase 3 (Eng).

---

### Eng Review

**Architecture ASCII diagram:**

```
service.ts (existing)
  ├── loadConfig() ──────────────► config.yaml
  ├── updateConfig handler ───────► [EXTRACT] config-io.ts
  │     applyConfigToDisk()              ├── writeFileSync
  │     loadConfigFrom()                 └── js-yaml (standalone)
  └── connectWithRetry() ─────────► FastAPI WS

tests/e2e/
  ├── helpers/ws.ts (NEW) ─────────► shared: openWs, collectMessages, authorizedWs
  ├── connection-lifecycle.test.ts (NEW) ─► FastAPI WS (TC-LC-01~08)
  ├── config-write.test.ts (NEW) ──► config-io.ts + tmpdir (TC-CW-01~07)
  └── ui-browser.spec.ts (NEW) ────► Playwright → Vite dev server → mock-sdk → FastAPI WS

ui/test/mock-sdk/ (NEW)
  ├── index.ts ────────────────────► @hmcs/sdk alias (signals, EventBus)
  └── rpc.ts ──────────────────────► @hmcs/sdk/rpc alias (direct WS to FastAPI)
```

**Scope challenge — actual code examined:**

1. `service.ts:162-186` (`updateConfig` handler): Logic to extract is clear. 8 lines. Low risk.
2. `service.ts:354` (`startRpcServer` is awaited synchronously) — return value is server handle, not awaited for lifecycle. TODO comment exists. Not a blocker.
3. `service.ts:360` (`const vrm = await spawnCharacter()`) — top-level await confirmed. config-io.ts MUST NOT import service.ts. Design doc correctly flags this.
4. `vitest.e2e.config.ts` — only 3 lines. New test files auto-included. No config changes needed for DH-24-2.
5. `websocket.test.ts:91` — `"returns authorize_success for any token (token validation is TODO in backend)"` — TC-LC-02's auth failure scenario is vacuously passing. **Must add `.skip` guard.**

**Test diagram — codepath to coverage:**

| Codepath | Type | Test File | TC | Gap? |
|----------|------|-----------|----|----|
| WS connect → authorize → stream_end | E2E | connection-lifecycle | TC-LC-01 | Covered |
| WS close → new WS → re-authorize | E2E | connection-lifecycle | TC-LC-01,06 | Covered |
| Bad auth token → authorize_error | E2E | connection-lifecycle | TC-LC-02 | Vacuous if backend skips auth |
| Rapid re-connect × 5 | E2E | connection-lifecycle | TC-LC-03 | Covered |
| Stream interrupted mid-stream → new session | E2E | connection-lifecycle | TC-LC-04 | Covered — core TSM scenario |
| 3 concurrent connections, session isolation | E2E | connection-lifecycle | TC-LC-05 | Backend assumption unverified |
| Reconnect × 3 (button repeat scenario) | E2E | connection-lifecycle | TC-LC-06 | Covered |
| Auth-less chat → error | E2E | connection-lifecycle | TC-LC-07 | Covered |
| Session continuity after reconnect | E2E | connection-lifecycle | TC-LC-08 | Covered (REST + WS) |
| applyConfigToDisk writes fields | E2E | config-write | TC-CW-01 | Covered |
| Untouched fields preserved | E2E | config-write | TC-CW-02 | Covered |
| Round-trip fidelity | E2E | config-write | TC-CW-03 | Covered |
| Empty string token | E2E | config-write | TC-CW-04 | Covered |
| Idempotent write | E2E | config-write | TC-CW-05 | Covered |
| New WS URL reflected in loadConfig | E2E | config-write | TC-CW-06 | Covered |
| Config write + real WS connect | E2E | config-write | TC-CW-07 | Covered (needs FastAPI) |
| UI: initial disconnected state | Playwright | ui-browser | TC-UI-01 | Covered |
| UI: Reconnect button → connected | Playwright | ui-browser | TC-UI-02 | Covered |
| UI: Settings Save → chat works | Playwright | ui-browser | TC-UI-03 | Covered |
| UI: double-click debounce | Playwright | ui-browser | TC-UI-04 | Covered |
| UI: invalid URL → disconnected | Playwright | ui-browser | TC-UI-05 | Covered |
| UI: restart-required state | Playwright | ui-browser | MISSING | **GAP** |
| config-io unit test | Unit | tests/unit/ | (implied by DH-24-1 DoD) | Implied |

**Critical issues:**

**[ISSUE-1] TC-LC-02 vacuous pass — HIGH**
`websocket.test.ts:91` confirms backend currently returns `authorize_success` for all tokens. TC-LC-02 asserts `authorize_error` on bad token — this will either (a) never trigger and the test will timeout, or (b) pass vacuously if the assertion is wrong. The design doc prescribes a conditional skip. Task description must make this explicit.
**Mitigation applied:** DH-24-4 DoD updated: `(TC-LC-02 제외 시 skip 허용)`.

**[ISSUE-2] `@playwright/test` dependency missing — HIGH**
`ui/package.json` has no Playwright dependency. DH-24-3 must add `@playwright/test` to `mods/desktopmate-bridge/ui/package.json` devDependencies before any Playwright code can run.
**Mitigation applied:** DH-24-3 task description updated with explicit `@playwright/test` mention.

**[ISSUE-3] WS helpers DRY violation — MEDIUM**
`connection-lifecycle.test.ts` and `config-write.test.ts` both need `openWs`/`collectMessages`/`authorizedWs`. Copying creates divergence risk. Extract to `tests/e2e/helpers/ws.ts`.
**Mitigation applied:** DH-24-2 task description updated.

**[ISSUE-4] DH-24-4 scope unbounded — MEDIUM**
"실패 시 버그 수정" is open-ended. If the TSM/IMKit error is a Bevy/CEF thread conflict (engine-layer), fixing it is out of MOD scope and could block indefinitely. Scope must be bounded.
**Mitigation applied:** DH-24-4 task description scoped to TypeScript MOD layer only.

**[ISSUE-5] TC-LC-03 parallelism risk — LOW**
Spec says "순차 실행 (parallel 금지)" but doesn't specify `for...of` explicitly. A worker might use `Promise.all`. Not in task description. Low risk since the spec doc is clear.
**Mitigation:** No task change needed — spec doc is explicit. Log as low risk.

**[ISSUE-6] TC-LC-05 session isolation assumption — LOW**
Assumes `session_id` omission → independent session per WS connection. Fallback assertion provided. Acceptable risk.

**Failure modes registry:**

| Risk | Severity | Mitigation |
|------|----------|------------|
| TC-LC-02 vacuous green | HIGH | `.skip` guard + conditional |
| `@playwright/test` missing | HIGH | Added to DH-24-3 task |
| DH-24-4 scope creep to Bevy layer | HIGH | Scoped to MOD layer |
| WS helpers copy-paste drift | MEDIUM | Shared helpers/ws.ts |
| TC-LC-05 concurrent session assumption | LOW | Fallback assertion in spec |
| TC-LC-03 accidental parallel | LOW | Spec explicit, dev reads spec |
| UI text string mismatch | LOW | Worker must verify against component |
| `restart-required` state untested | LOW | Out of Phase 24 scope — DEFERRED |

**Phase 3 complete.** Passing to Phase 3.5 (DX).

---

### DX Review

**DX scope:** Test infrastructure (Playwright, mock-sdk) — developer-facing tooling.

**Developer journey:**

| Stage | What developer does | Pain points |
|-------|---------------------|-------------|
| 1. Setup DH-24-1 | Extract config-io.ts | Clear spec, low risk |
| 2. Setup DH-24-2 | Create tests + shared helpers | Need to verify backend is up |
| 3. Setup DH-24-3 | Add Playwright, mock-sdk, vite alias | Multiple new files, non-trivial |
| 4. Run DH-24-4 | Full E2E run | Backend must be up on :5500 |

**DX scorecard:**

| Dimension | Score | Notes |
|-----------|-------|-------|
| Getting started | 7/10 | `pnpm test:e2e` pattern already exists; Playwright adds complexity |
| Setup friction | 6/10 | 5 new files + 1 new dep for DH-24-3 — non-trivial but well-specified |
| Error messages | 8/10 | Timeout messages in `collectMessages` show collected messages |
| Documentation | 8/10 | Design doc is very complete; TCs have detailed implementation notes |
| Escape hatches | 8/10 | `FASTAPI_URL` env var, `.skip` guards, `os.tmpdir()` isolation |
| Idempotency | 9/10 | `afterEach` cleanup specified; `applyConfigToDisk` idempotent test included |

**DX concern: Playwright webServer config**
The spec gives `playwright.config.ts` sketch with `webServer: pnpm dev --mode test`. The worker must know:
- `playwright.config.ts` lives in `mods/desktopmate-bridge/ui/`
- `pnpm dev` in that dir uses `ui/vite.config.ts`
- `VITE_TEST_MODE=true` must be in `webServer.env` or the pnpm dev command
- `@playwright/test` should go in `ui/package.json` not `mods/desktopmate-bridge/package.json`

These are all derivable from the spec. DX score acceptable.

**TTHW (time to hello world for test setup):** ~30 min for DH-24-1, ~45 min for DH-24-2, ~60 min for DH-24-3. Reasonable.

**Phase 3.5 complete.** Proceeding to Final Gate.

---

### Cross-Phase Themes

1. **TC-LC-02 vacuous green** — flagged in CEO (scope note) and Eng (issue-1). High-confidence signal. Mitigated by `.skip` guard.
2. **Scope boundary: MOD layer vs Bevy engine** — flagged in CEO (dream state) and Eng (issue-4). Worker needs this explicit.

---

### Decision Audit Trail

| # | Phase | Decision | Classification | Principle | Rationale | Rejected |
|---|-------|----------|----------------|-----------|-----------|----------|
| 1 | CEO | Accept 3 test files + config-io.ts scope | Mechanical | P1 | P0 bug, zero coverage | Omnibus single file |
| 2 | CEO | Accept CI exclusion | Mechanical | P3 | No mock FastAPI available | Force CI |
| 3 | Eng | Extract WS helpers to `tests/e2e/helpers/ws.ts` | Mechanical | P5 | DRY, clear reuse | Copy per file |
| 4 | Eng | TC-LC-02: mandate `.skip` guard | Mechanical | P1 | Backend doesn't validate tokens | Leave test as-is |
| 5 | Eng | `@playwright/test` → `ui/package.json` | Mechanical | P5 | playwright.config.ts is in ui/ | Add to mod root |
| 6 | Eng | DH-24-4 scope = MOD layer only | Mechanical | P3 | Engine-layer fix out of scope | Open-ended "fix anything" |
| 7 | Design | `restart-required` state: defer | Mechanical | P3 | Not the bug scenario; DEFERRED | Include in Phase 24 |

---

## Completed

<!-- Phases 12–17, 19–20: archived to docs/archive/plans-2026-04.md on 2026-04-03 -->
