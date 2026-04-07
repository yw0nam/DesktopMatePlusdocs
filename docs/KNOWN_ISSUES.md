# Known Issues

PR review 에이전트(`pr-review-toolkit`)가 발견한 스코프 밖 기술 부채 추적.  
각 이슈 상세는 해당 sub-repo의 `docs/known_issues/` 개별 파일에 기록.

형식: `- [ ] **KI-{N}** [{severity}] {component}: {one-line summary} → [상세](link)`

---

## Backend (`backend/`)

현재 없음.

---

## NanoClaw (`nanoclaw/`)

현재 없음.

---

## Desktop Homunculus (`desktop-homunculus/`)

### Error Handling Debt
발견: Phase 27 (silent-failure-hunter)

- [ ] **KI-1** [HIGH] `tts-chunk-queue.ts`: `.catch`가 `.finally` 뒤에 위치 — processor 에러 컨텍스트 없음, `isBusy()` 오관측 가능 → [상세](../desktop-homunculus/docs/known_issues/issue_tts-chunk-catch-ordering.md)
- [ ] **KI-2** [HIGH] `reaction-controller.ts` `speak()`: 빈 `catch {}` — TTS/VRM/네트워크 에러 전부 무음 폐기 → [상세](../desktop-homunculus/docs/known_issues/issue_reaction-speak-silent-catch.md)
- [ ] **KI-3** [HIGH] `reaction-controller.ts` `startWindowWatcher()`: `.catch(() => {})` — 100ms 주기 에러 무음 폐기 → [상세](../desktop-homunculus/docs/known_issues/issue_reaction-window-watcher-silent-catch.md)
- [ ] **KI-4** [MEDIUM] `reaction-controller.ts` `speak()`: HTTP 비정상 응답 시 status code 미로깅 → [상세](../desktop-homunculus/docs/known_issues/issue_reaction-http-non-ok-no-log.md)
- [ ] **KI-5** [MEDIUM] `config-io.ts`: YAML 필드 검증 없음 — 필드 누락이 다운스트림 TypeError로 표면화 → [상세](../desktop-homunculus/docs/known_issues/issue_config-io-no-field-validation.md)

### Test Coverage Debt
발견: Phase 27 (pr-test-analyzer)

- [ ] **KI-6** [HIGH] `service.ts` `spawnCharacter()`: `preferencesLoad` 비undefined 결과가 `vrmSpawn`에 전달되는지 미검증 → [상세](../desktop-homunculus/docs/known_issues/issue_spawn-character-preferences-load-not-tested.md)
- [ ] **KI-7** [MEDIUM] `rpc-flow.test.ts`: `sendMessage` WS OPEN 경로 및 payload 직렬화 미검증 → [상세](../desktop-homunculus/docs/known_issues/issue_send-message-ws-open-not-tested.md)
- [ ] **KI-8** [MEDIUM] `signal-flow.test.ts`: `ping → pong` 경로 미테스트 → [상세](../desktop-homunculus/docs/known_issues/issue_ping-pong-not-tested.md)
- [ ] **KI-9** [MEDIUM] `service.ts` `handleClose()`: close-code별 adapter signal 경로 unit test 없음 → [상세](../desktop-homunculus/docs/known_issues/issue_handle-close-unit-test-missing.md)
- [ ] **KI-10** [LOW] `rpc-flow.test.ts`: `interruptStream` RPC 핸들러 미테스트 → [상세](../desktop-homunculus/docs/known_issues/issue_interrupt-stream-not-tested.md)
- [ ] **KI-11** [LOW] `tts-flow.test.ts`: `createTestTtsQueue`가 service.ts 내부 구현 복사 → [상세](../desktop-homunculus/docs/known_issues/issue_create-tts-queue-impl-copy.md)
- [ ] **KI-12** [LOW] `signal-flow.test.ts`: 모듈-레벨 상태 오염 가능성 (순서 의존성) → [상세](../desktop-homunculus/docs/known_issues/issue_signal-flow-module-state-contamination.md)

---

## Workspace Root (`DesktopMatePlus/`)

현재 없음.
