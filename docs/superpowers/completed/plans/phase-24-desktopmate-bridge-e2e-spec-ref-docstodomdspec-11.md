### Phase 24: desktopmate-bridge 백엔드 연결 E2E 테스트 — spec-ref: docs/TODO.md#spec-11

<!-- source: docs/TODO.md Spec 11 (2026-04-06). P0. Reconnect/Settings Save 버그 + harsh E2E. -->
<!-- /autoplan restore point: /home/spow12/.gstack/projects/yw0nam-DesktopMatePlusdocs/master-autoplan-restore-20260406-095446.md -->

- [x] **DH-24-1: config-io.ts 추출** cc:DONE [5dcd3c1] — `src/config-io.ts` 신규 파일에 `applyConfigToDisk(config, input, configPath)` + `loadConfigFrom(configPath)` 추출. service.ts import chain 없음 필수. DoD: 기존 unit test 통과 + config-io.ts에 별도 unit test. Depends: none. [target: desktop-homunculus/]
- [x] **DH-24-2: connection-lifecycle E2E + config-write E2E** cc:DONE [6cf562b] — `tests/e2e/connection-lifecycle.test.ts` (TC-LC-01~08, 실제 FastAPI WS) + `tests/e2e/config-write.test.ts` (TC-CW-01~07). WS helper 함수(`openWs`, `collectMessages`, `authorizedWs`)를 `tests/e2e/helpers/ws.ts`로 추출하여 공유. **TC-LC-02 조건부 skip 필수**: `const backendSkipsTokenValidation = true; // TODO: backend token validation not implemented` 상수 선언 후 `it.skipIf(backendSkipsTokenValidation, ...)` 패턴 사용 — unconditional skip 금지 (backend에 token validation 구현 시 flag만 제거하면 복활). DoD: `pnpm test:e2e` 전체 PASS. Depends: DH-24-1. [target: desktop-homunculus/]
- [x] **DH-24-3: Playwright UI E2E** cc:DONE [5235229] — `tests/e2e/ui-browser.spec.ts` (TC-UI-01~05). `@playwright/test`를 `mods/desktopmate-bridge/ui/package.json` devDependencies에 추가 필수. `VITE_TEST_MODE=true` mock-sdk alias + Playwright 브라우저 테스트. `playwright.config.ts`에 `reporter: [['list'], ['html']]` + `use: { baseURL: 'http://localhost:5173' }` 명시 — Playwright 미설치 시 명확한 에러 출력 보장 (silent fail 방지). DoD: `pnpm playwright test` 전체 PASS. Depends: DH-24-2. [target: desktop-homunculus/]
- [x] **DH-24-4: 전체 E2E 실행 + 버그 수정** cc:DONE [f82e2cc] — TC-LC-*, TC-CW-*, TC-UI-* 전체 PASS 확인. 실패 시 TypeScript MOD 레이어(service.ts, ui/) 범위 내에서 버그 수정. Bevy/CEF 엔진 레이어 수정 불필요. DoD: 모든 20개 TC PASS (TC-LC-02 제외 시 skip 허용) + Reconnect/Settings Save 정상 동작. Depends: DH-24-3. [target: desktop-homunculus/]

<!-- reviewer: /autoplan CONDITIONAL PASS 2026-04-06 — see review report below -->
