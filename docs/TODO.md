# DesktopMatePlus — Feature TODO

PM agent가 office-hours 상담 후 작성. Lead가 Plans.md로 가져가 태스크화한다.

---

## Active TODO

| # | Feature | Priority | Status | Spec |
|---|---------|----------|--------|------|
| 6 | 워크플로우 문서 모순 해소 | P1 | DONE | [spec](#spec-6-워크플로우-문서-모순-해소) |
| 7 | Mascot Reaction System | P1 | DONE | [spec](#spec-7-mascot-reaction-system) |
| 8 | VRM Position Adjustment UI | P2 | DONE | [spec](#spec-8-vrm-position-adjustment-ui) |
| 9 | E2E 테스트 확장 (TTS + LTM) | P2 | TODO | [spec](#spec-9-e2e-테스트-확장) |
| 10 | VRM 런타임 교체 UI | P2 | TODO | [spec](#spec-10-vrm-런타임-교체-ui) |
| 11 | desktopmate-bridge 백엔드 연결 E2E 테스트 | P0 | TODO | [spec](#spec-11-backend-connection-e2e-테스트) |

---

## Specs

### Spec 6~8: DONE (아카이브)

완료된 스펙 상세는 → [docs/archive/todo-2026-04.md](./archive/todo-2026-04.md) 참조.
- Spec 6: 워크플로우 문서 모순 해소 (PR #5)
- Spec 7: Mascot Reaction System (PR #9, #11)
- Spec 8: VRM Position Adjustment UI (PR #8)

### Spec 9: E2E 테스트 확장 (TTS + LTM)

**출처**: 2026-04-05 Lead-User 논의. Phase 23 신규 기능 e2e 커버리지 보강.

**대상 레포**: `backend/`

**구현 목표**:

1. **`test_tts_speak.py` 신규** — `POST /v1/tts/speak` 엔드포인트 E2E 검증
   - `text` 파라미터로 호출 → `audio_base64` 키 존재 + 값 비어있지 않음 확인
   - TTS 서버 미실행 시 SKIP (Phase 1.5 결과 활용)
   - Reaction 트리거가 결국 이 엔드포인트를 호출하므로 Reaction E2E 커버 간주

2. **`test_ltm.py` 확장** — LTM 통합 시나리오 추가
   - 기존: store → search
   - 추가: store 후 WebSocket 1턴 대화 → 응답에 LTM 메모리 반영 여부 확인

**DoD**:
- `test_tts_speak.py` e2e.sh Phase 4에 추가, TTS 서버 있을 때 PASSED
- `test_ltm.py` WebSocket 통합 시나리오 PASSED (Qdrant 있을 때)
- `bash backend/scripts/e2e.sh` 전체 PASSED

---

### Spec 10: VRM 런타임 교체 UI

**출처**: 2026-04-05 PM office-hours. **대상**: `desktop-homunculus` (`character-settings` MOD)

**Design Doc**: `~/.gstack/projects/yw0nam-nanoclaw/spow12-develop-design-20260405-092715.md`

**구현 목표**: `character-settings` Basic 탭에 VRM 모델 드롭다운 추가. `assets.list({ type: "vrm" })` 목록 표시, Save 시 despawn → spawn → `setLinkedVrm` 시퀀스로 교체. Persona/scale/posX/posY 보존. `isSwapping` 가드로 이중 클릭 방지.

**변경 파일**: `useCharacterSettings.ts` (swap 로직) · `BasicTab.tsx` (`<select>`) · `App.tsx` (props)

**[BLOCKER]**: `setLinkedVrm` 호출 시 webview re-mount 여부 worker가 먼저 확인. Re-mount 시 persona/transform을 `preferences`에 먼저 쓰는 방식으로 변경.

**DoD**: 드롭다운 렌더링 · VRM 교체 · Persona/transform 보존 · Vitest unit test · `/agent-browser` visual verification. [target: desktop-homunculus/]

### Spec 11: desktopmate-bridge 백엔드 연결 E2E 테스트

**출처**: 2026-04-06 PM office-hours. Reconnect/Settings Save 버튼 클릭 시 TSM/IMKit 에러 + 앱 비기능 버그.

**대상 레포**: `desktop-homunculus` (desktopmate-bridge MOD, ui/)

**버그 재현**:
```
TSM AdjustCapsLockLEDForKeyTransitionHandling - _ISSetPhysicalKeyboardCapsLockLED Inhibit
error messaging the mach port for IMKCFRunLoopWakeUpReliable
```
→ 앱 완전 비기능 상태. 기존 테스트(reconnect.test.ts)는 mock-only — 실제 재연결 검증 없음.

**구현 목표**: 3개 신규 E2E 테스트 파일 + `applyConfigToDisk` 추출

**신규 파일 구성**:

| 파일 | TC 수 | 요구사항 |
|------|-------|---------|
| `tests/e2e/connection-lifecycle.test.ts` | 8 | 실제 FastAPI WS 필요 |
| `tests/e2e/config-write.test.ts` | 7 | FastAPI 불필요 (TC-CW-07 제외) |
| `tests/e2e/ui-browser.spec.ts` (Playwright) | 5 | FastAPI + Chromium |

**선행 리팩터**: `src/config-io.ts` 신규 — `applyConfigToDisk(config, input, configPath)` + `loadConfigFrom(configPath)` 추출. service.ts와 import chain 없음.

**TC 주요 케이스**:
- TC-LC-04: 스트림 중간 WS 끊김 → 재연결 후 채팅 완료 (TSM 버그 핵심)
- TC-LC-06: 3연속 reconnect + 매 회 채팅 완료 (버튼 반복 클릭 시나리오)
- TC-UI-02: Playwright — Reconnect 버튼 클릭 → "✔ Connected" (실제 FastAPI auth)
- TC-UI-03: Playwright — Settings Save 클릭 → "✔ Saved" → 채팅 가능
- TC-UI-05: Playwright — 잘못된 URL → 재연결 실패 흐름 검증

**Playwright Mock 전략**:
- `VITE_TEST_MODE=true` 시 `@hmcs/sdk` / `@hmcs/sdk/rpc`를 `ui/test/mock-sdk/`로 alias
- Mock RPC: 실제 FastAPI WS에 연결, auth 성공 시 `dm-connection-status: connected` signal 발행
- Mock Signals: EventBus 기반, `page.evaluate`로 수동 trigger 가능

**DoD**:
- `src/config-io.ts` 추출 (service.ts import chain 없음)
- TC-LC-01 ~ TC-LC-08: `pnpm test:e2e` 전체 PASS (실제 FastAPI 백엔드)
- TC-CW-01 ~ TC-CW-07: `pnpm test:e2e` 전체 PASS
- TC-UI-01 ~ TC-UI-05: `pnpm playwright test` 전체 PASS
- Reconnect 클릭 후 10s 이내 "✔ Connected" (TC-UI-02)
- **이 모든 케이스 PASS 후에만 Reconnect/Settings Save 버그를 DONE으로 표시 가능**

**Design Doc**: `~/.gstack/projects/yw0nam-DesktopMatePlusdocs/spow12-master-design-20260406-092637.md`

[target: desktop-homunculus/]

---

## Completed

Spec 1~5 (Phase 20 완료) → [docs/archive/todo-2026-04.md](./archive/todo-2026-04.md)

Spec 6 (Phase 21 완료, 2026-04-03) — 워크플로우 문서 모순 해소. PR #5 (docs/p21-twf → master) 머지 완료.

Spec 7 (Phase 23 완료, 2026-04-04) — Mascot Reaction System. BE PR #11 (TTS speak endpoint) + DH PR #9 (ReactionController) 머지 완료.

Spec 8 (Phase 23 완료, 2026-04-04) — VRM Position Adjustment UI. DH PR #8 (Position X/Y sliders) 머지 완료.
