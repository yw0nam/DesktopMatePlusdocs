# Known Issues

추후 별도 Phase로 수정할 알려진 기술 부채 목록.

형식: `- [ ] **KI-{N}** [{severity}] {component}: {description}` — 발견 경위, 영향, 권장 조치.

## Error Handling Debt (desktopmate-bridge)

발견: Phase 27 PR review — `pr-review-toolkit:silent-failure-hunter`

- [ ] **KI-1** [HIGH] `tts-chunk-queue.ts`: `.catch` 위치가 `.finally` 뒤에 있어 processor 에러 컨텍스트(sequence, text) 없이 로깅됨. `activeCount` 데크리먼트 후 catch가 실행되므로 `isBusy()` 오관측 가능. → `.catch(...).finally(...)` 순서로 교체, 청크 컨텍스트 포함.
- [ ] **KI-2** [HIGH] `reaction-controller.ts` `speak()`: 빈 `catch {}` — TTS REST 실패, `vrm.speakWithTimeline` 에러, base64 디코딩 실패 등 모든 에러 무음 폐기. → `catch (err)` + `console.warn` (best-effort 의도 유지).
- [ ] **KI-3** [HIGH] `reaction-controller.ts` `startWindowWatcher()`: `.catch(() => {})` 빈 핸들러 — `activeWin()` 플랫폼 에러가 100ms 주기로 무음 실패. → `catch (err)` + `console.warn`.
- [ ] **KI-4** [MEDIUM] `reaction-controller.ts` `speak()`: HTTP `!response.ok` 분기에서 status code 미로깅. → `console.warn` 추가.
- [ ] **KI-5** [MEDIUM] `config-io.ts` `loadConfigFrom()`: YAML 파싱 후 필수 필드 검증 없음 — 누락 필드가 `new WebSocket(undefined)` 같은 다운스트림 에러로 나타남. → zod 스키마로 필드 검증 추가.

## Test Coverage Debt (desktopmate-bridge)

발견: Phase 27 PR review — `pr-review-toolkit:pr-test-analyzer`

- [ ] **KI-6** [HIGH] `service.ts` `spawnCharacter()`: `preferencesLoad` 비undefined 결과가 `vrmSpawn` 옵션으로 전달되는지 미검증. MockAdapter에 `preferencesStore` 시드 추가 필요.
- [ ] **KI-7** [MEDIUM] `service.ts` `sendMessage` RPC: WS OPEN 상태(`readyState=1`)에서 `{ ok: true }` 반환 및 올바른 payload(content, session_id, user_id, agent_id, reference_id) 직렬화 미검증.
- [ ] **KI-8** [MEDIUM] `service.ts` `handleMessage`: `ping` → `pong` 응답 경로 미테스트.
- [ ] **KI-9** [MEDIUM] `service.ts` `handleClose`: close code별 adapter signal 경로 unit test 없음 (`4000`/`1006` → retry, 재시도 소진 → `restart-required`).
- [ ] **KI-10** [LOW] `rpc-flow.test.ts`: `interruptStream` RPC 핸들러 미테스트.
- [ ] **KI-11** [LOW] `tts-flow.test.ts`: `createTestTtsQueue` 헬퍼가 `service.ts` 내부 구현 복사본 — 시그니처 변경 시 silent 분기 가능.
- [ ] **KI-12** [LOW] `signal-flow.test.ts`: 모듈-레벨 상태(`_authFailed`, `_connectionStatus`)가 test suite 간 오염될 수 있음 — 현재는 안전하지만 순서 의존성 존재.

---

> 이 파일은 PR review 에이전트(`pr-review-toolkit`)가 발견한 이슈 중 해당 Phase 스코프 밖 항목을 추적한다.
> 수정 시 체크하고 완료 Phase를 기재한다.
