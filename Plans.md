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

### Phase 16: Irodori TTS 교체 + Emoji Emotion + 버그 수정

<!-- spec-ref: ~/.gstack/projects/yw0nam-DesktopMatePlusdocs/spow12-master-design-20260401-170837.md -->

- [x] **BE-FEAT-1: IrodoriTTSService 클라이언트** cc:DONE [9766cb2] — `src/services/tts_service/irodori_tts.py` + `src/configs/tts/irodori.py` 구현. TTSService ABC 준수 (generate_speech/list_voices/is_healthy). httpx.Client로 POST /synthesize (multipart form: text, reference_audio?, seconds, num_steps, cfg_scale_text, cfg_scale_speaker, seed) → WAV bytes. 서버 다운 시 None 반환 (graceful degradation). TTSFactory에 `irodori` 타입 추가. DoD: /synthesize 호출 성공 + is_healthy() 정상 + structural tests 통과. Depends: none. [target: backend/]

- [x] **BE-FEAT-2: Emoji 기반 Emotion 시스템 교체 + Fish Speech 제거** cc:DONE [PR#7] — Fish Speech 제거 (`fish_speech.py`, `fish_local.py`, TTSFactory `fish_local_tts` 케이스). `yaml_files/tts_rules.yml` 교체: emotion_motion_map 이모지 키(😊😭😠😮 등)로 변경, rules에서 `\([^)]*\)` 제거 규칙 삭제. `AgentTTSTextProcessor.process_text()`의 괄호 감정 파싱 → 이모지 감지로 교체 (EmotionMotionMapper.known_emojis 참조). `personas.yml`에 EMOJI_ANNOTATIONS.md 이모지 annotation 가이드 주입 (Agent가 이모지 출력). DoD: 이모지 포함 텍스트 → emotion_tag 추출 → 올바른 keyframes + sh scripts/lint.sh 통과 + Agent가 이모지 실제 출력. Depends: BE-FEAT-1. [target: backend/]

- [x] **DH-BUG-14: dm-stream-token / dm-tts-chunk 역할 분리** cc:DONE [0260b12] — `useSignals.ts`: dm-stream-token 구독 추가 (appendStreamChunk), dm-tts-chunk에서 text append 제거. DoD: stream_token만 텍스트 표시, tts_chunk는 트리거하지 않음. store.test.ts 동시 수신 시나리오 추가. Depends: Phase 15 PR 머지. [target: desktop-homunculus/]

- [x] **DH-BUG-15: handleDragStart mouseup listener leak** cc:DONE [PR#5] — `ControlBar.tsx`: dragPending ref 추가. await wv.info() 전에 dragPending=true, await 완료 후 dragPending이 false면 listeners 부착 생략. drag handle div에 onMouseUp으로 dragPending=false 처리. DoD: await 중 mouseup 시 listeners 부착하지 않음. 단위 테스트 추가. Depends: none. [target: desktop-homunculus/]

- [x] **DH-BUG-16: TtsChunkQueue reset() in-flight chain 미취소** cc:DONE [PR#5] — `tts-chunk-queue.ts`: generation counter 추가. reset() 시 generation++. scheduleProcessor()에서 generation 캡처해 실행 시점에 비교, 불일치 시 processor 호출 스킵. DoD: reset() 후 in-flight chunk processor 미호출. flush() 중 reset() 시나리오 포함 단위 테스트. Depends: none. [target: desktop-homunculus/]

### Phase 17: Irodori Multi-Voice + Backend Verification

<!-- spec-ref: ~/.gstack/projects/yw0nam-DesktopMatePlusdocs/spow12-master-design-20260401-213056.md -->

- [x] **BE-FEAT-3: IrodoriTTSService Multi-Voice 지원** cc:DONE [3c883af] — `IrodoriTTSConfig.reference_audio_path` → `ref_audio_dir` 교체. `IrodoriTTSService.__init__` 파라미터 교체(`reference_audio_path` 제거). `_scan_voices()`: `{ref_audio_dir}/{voice_name}/merged_audio.mp3` 스캔 → `_available_voices` 저장. `generate_speech(reference_id=...)` 실제 동작: `{ref_audio_dir}/{reference_id}/merged_audio.mp3` 로드 + POST /synthesize 전송. 잘못된 reference_id → None 반환. `list_voices()` → 스캔 결과 반환. `list_voices()` no-reference mode → `[]`. `src/services/tts_service/tts_factory.py` + `yaml_files/services/tts_service/irodori.yml` 동시 업데이트. DoD: `uv run pytest tests/services/test_irodori_tts.py tests/services/test_list_voices.py -v` 전체 통과 + `scripts/check-task.sh -k irodori` PASSED. Depends: none. [target: backend/]

- [x] **BE-DOC-1: Backend Task Verification 표준화** cc:DONE [315dd13] — `scripts/check-task.sh` 신규 작성: Phase1(lint.sh) + Phase2(pytest `-k <keyword>`) + Phase3(랜덤 포트 5000-9999로 backend 자동 시작 → health 대기 30s → `realtime_tts_streaming_demo.py --ws-url ws://localhost:{PORT}/...` 실행 → 로그 ERROR 확인 → backend 자동 종료). `backend/AGENTS.md`에 "Task Completion Checklist (DoD)" 섹션 추가 (TDD 흐름 + check-task.sh 실행 + PASSED 확인). DoD: `scripts/check-task.sh -k irodori` 실행 시 PASSED 출력. Depends: none. [target: backend/]

### Phase 18: OpenSpace 시범 도입 (backend) — 유저 지시 시 진행

<!-- triggered by: user request only. Do NOT start autonomously. -->
<!-- OpenSpace: 로컬 실행. Dashboard backend: http://localhost:7788, Frontend: http://localhost:3789 -->
<!-- Cloud 미사용 (OPENSPACE_API_KEY 불필요). 모든 스킬은 로컬 저장. -->
<!-- LLM: 로컬 vLLM (http://192.168.0.41:5535, OpenAI-compatible API). OPENSPACE_LLM_API_BASE=http://192.168.0.41:5535/v1, OPENSPACE_LLM_API_KEY=token-abc123, OPENSPACE_MODEL=openai/chat_model -->

- [ ] **INFRA-1: OpenSpace MCP 설정 (backend)** cc:TODO — `OpenSpace/` repo를 backend worker용 MCP 서버로 등록 (로컬 전용, cloud 미사용). `.claude/settings.json`에 openspace MCP 추가, `OPENSPACE_HOST_SKILL_DIRS`를 backend skills 경로로 지정. Dashboard: backend `http://localhost:7788`, frontend `http://localhost:3789`. DoD: worker가 openspace MCP 도구 호출 가능. Depends: none. [target: DesktopMatePlus/]
- [ ] **INFRA-2: OpenSpace host_skills 배치** cc:TODO — `delegate-task/SKILL.md` + `skill-discovery/SKILL.md`를 backend worker가 참조할 수 있는 위치에 복사. DoD: worker가 skill-discovery로 기존 스킬 검색 가능. Depends: INFRA-1. [target: backend/]
- [ ] **INFRA-3: 효과 측정 기준 정의** cc:TODO — 토큰 사용량 비교(Phase 17 대비), 자동 캡처된 스킬 수, 스킬 재사용률 지표 정의. DoD: 측정 기준 문서 작성. Depends: INFRA-1. [target: DesktopMatePlus/]
- [ ] **INFRA-4: 파일럿 태스크 실행 + 평가** cc:TODO — backend 태스크 2~3개를 OpenSpace 적용 worker로 실행, Phase 17 동일 유형 태스크와 비교. DoD: 효과 측정 보고서 작성. Depends: INFRA-2, INFRA-3. [target: backend/]

### Phase 19: Agent E2E Verification Pipeline

<!-- spec-ref: ~/.gstack/projects/yw0nam-DesktopMatePlusdocs/spow12-master-design-20260402-142307.md -->
<!-- DoD 표준: 각 backend 태스크 완료 시 bash backend/scripts/e2e.sh PASSED 필수 -->
<!-- NOTE: BE-E2E-1 ∥ DH-PROBE-1 — 두 태스크는 의존성 없으므로 병렬 실행 가능 -->

- [x] **BE-E2E-1: backend/scripts/e2e.sh 작성 + run.sh BACKEND_PORT 지원** cc:DONE [e6c23dd] — run.sh에 BACKEND_PORT env var 또는 --port 인자 지원 추가. e2e.sh 구현 요건: (1) `set -euo pipefail` 선언 (2) Phase1: nc로 MongoDB+Qdrant 확인 — 호스트/포트는 yaml_files에서 읽기(localhost 하드코딩 금지, run.sh 기존 `_check_mongodb`/`_check_qdrant` 패턴 재사용) (3) Phase1.5: TTS 서버 확인 — 없으면 WARNING+SKIP (4) Phase2: 7000-8999 랜덤 포트로 `bash scripts/run.sh --bg` 실행, `.run.pid`로 PID 추적, `.run.logdir`로 LOG_DIR 읽기(`LOG_DIR=$LOG_DIR` env 주입 방식 금지) (5) Phase3: health wait 30s — kill -0 PID(프로세스 생존) + curl -sf /health(HTTP 200) 동시 체크, PID 죽으면 즉시 FAILED (6) Phase4: 모든 examples를 BACKEND_PORT 주입하여 실행, exit code≠0이면 FAILED (7) Phase5: `grep -E '\|\s+ERROR\s+\|' | grep -v 'uvicorn\.error'` 로그 확인 (8) Phase6: cleanup — `trap 'bash scripts/run.sh --stop || true; exit 1' ERR INT TERM` 패턴, 정상 종료도 run.sh --stop 호출 (9) Phase7: 전체 PASSED/FAILED summary 출력. DoD: `bash backend/scripts/e2e.sh` → PASSED 출력 (MongoDB/Qdrant 사전 실행 전제). Depends: none. [target: backend/]

- [x] **BE-E2E-2: backend examples 재작성 (args 방식)** cc:DONE [e6c23dd] — examples/test_stm.py(--base-url, STM add/get/clear 라운드트립), examples/test_ltm.py(--base-url, LTM store/search 라운드트립, Qdrant 미실행 시 SKIP — Phase7 summary에 "LTM SKIPPED (Qdrant not running)" 출력), examples/test_websocket.py(--ws-url, 2-turn 대화 stream_end 확인 — `asyncio.wait_for(stream_end, timeout=30.0)` 또는 동등한 timeout 처리 필수) 3개 작성. 모두 assert 실패 시 sys.exit(1). 기존 stm_api_demo.py, multiturn_session_test.py deprecated 처리. DoD: 3개 파일 모두 --base-url/--ws-url 인자 필수, 하드코딩(5500, 5600) 없음, `bash backend/scripts/e2e.sh` PASSED. Depends: BE-E2E-1. [target: backend/]

- [x] **DH-PROBE-1: DH MOD standalone 실행 가능 여부 확인** cc:DONE — desktop-homunculus/mods/desktopmate-bridge/ 에서 pnpm dev로 Bevy 없이 브라우저 접근 가능한지 확인. 가능 시: 실행 방법 + data-testid 선택자 목록 문서화. 불가 시: 불가 사유 + TODO 문서화. DoD: 확인 결과 docs/ 또는 CLAUDE.md에 기록. Depends: none. [target: desktop-homunculus/]

- [x] **DH-E2E-1: DH MOD E2E 프로토콜 작성** cc:DONE — DH-PROBE-1 가능 결론 시에만 진행. **e2e.sh는 shell-automatable phases만 담당**: `set -euo pipefail` → pnpm dev 시작(4000-4499 랜덤 포트, stdout에 포트 출력) → HTTP 200 대기 → console.error 없음 확인 → pnpm dev stop → PASSED/FAILED 출력. **UI 검증(Agent browse)은 e2e.sh와 분리된 별도 프로토콜**: Agent가 DH-E2E-1 완료 후 수동으로 browse 실행(페이지 로드 + SettingsPanel 렌더링 + send button → backend 메시지 전송 → output 렌더링 확인) — e2e.sh exit code와 무관. DoD(DH standalone 가능): `bash desktop-homunculus/scripts/e2e.sh` PASSED + Agent browse 프로토콜 문서화. DoD(DH standalone 불가): CONDITIONAL TODO 표시 + 이유 문서화. Depends: DH-PROBE-1. [target: desktop-homunculus/]

- [x] **WS-E2E-1: workspace root scripts/e2e.sh 작성** cc:DONE [66409d6] — `set -euo pipefail`. backend/scripts/e2e.sh → desktop-homunculus/scripts/e2e.sh 순차 실행. **shell-automatable phases만 포함** (DH UI browse 검증은 Agent 별도 프로토콜, 이 스크립트 scope 외). DoD(DH standalone 가능): `bash scripts/e2e.sh` → backend PASSED + DH shell phases PASSED. DoD(DH standalone 불가): `bash scripts/e2e.sh` → backend PASSED + DH CONDITIONAL TODO 출력. Depends: BE-E2E-1, DH-E2E-1. [target: DesktopMatePlus/]

- [x] **DOC-E2E-1: Plans.md DoD 템플릿 표준화** cc:DONE [66409d6] — 신규 backend Plans.md 태스크 템플릿에 "bash backend/scripts/e2e.sh PASSED 필수" 명시. backend/AGENTS.md(또는 동등 문서)에 DoD 체크리스트 추가. 기존 cc:DONE 태스크 소급 제외. DoD: Plans.md 표준 주석 업데이트 + backend/AGENTS.md DoD 체크리스트 작성 완료. Depends: BE-E2E-1. [target: DesktopMatePlus/]

### Phase 20: Agent Harness Quality Upgrade

<!-- spec-ref: docs/TODO.md#spec-1-reviewermd-b-evaluator-패턴, #spec-2-docstodomd-전환, #spec-3-background-quality-agent--gardensh-개선, #spec-4-golden_principlesmd-일관성-수정 -->
<!-- Phase 20 office-hours: 2026-04-03 (보강: 2026-04-03) -->

- [x] **WS-REV-1: reviewer.md B+ Evaluator 패턴** cc:DONE — `.claude/agents/reviewer.md`에 4기준 채점 추가(correctness/security/maintainability/test coverage, 0-3점, 임계값 2/3 미달 시 FAIL). "관대하게 평가 금지" 명시. `/qa` 조건부 실행(browser-testable 변경 시) 규칙 추가. DoD: 4기준 체크리스트 + 임계값 FAIL 로직 + /qa 조건 명시. Depends: none. [target: DesktopMatePlus/]

- [x] **WS-DOC-2: CLAUDE.md PRD Tracking → docs/TODO.md 전환** cc:DONE — `CLAUDE.md` PRD Tracking 섹션에서 superpowers 언급 제거 → `docs/TODO.md` 기반 흐름으로 교체. `docs/CLAUDE.md` superpowers 링크도 TODO.md로 교체. DoD: CLAUDE.md + docs/CLAUDE.md 모두 docs/TODO.md를 가리킴. Depends: none. [target: DesktopMatePlus/]

- [x] **WS-QA-1: Background Quality Agent 신설 + garden.sh 개선** cc:DONE — `.claude/agents/quality-agent.md` 작성. garden.sh DH MOD 체크 + 위반위치 + docs/reports/ 경로 통일. QUALITY_SCORE.md UNCHECKED + Violations Summary. docs/reports/.gitkeep 추가. Depends: none. [target: DesktopMatePlus/]

- [ ] **WS-GP-1: GOLDEN_PRINCIPLES.md 일관성 수정** cc:TODO — `docs/GOLDEN_PRINCIPLES.md` 수정. GP-9 브랜치 참조 `feat/claude_harness` → `develop`으로 업데이트. GP-11/12 superpowers 기반 아카이브 규칙 → docs/TODO.md 기반으로 변경. DH MOD GP 추가(GP-13 또는 GP-2 확장): TS console.log 금지 + 파일크기 ≤ 400줄 (garden.sh DH 체크 기준과 일치). **주의: CONTRIBUTING 규칙상 PR 생성 + human approval 필수 — 직접 커밋 금지.** garden.sh archive freshness 감지 로직 업데이트는 Phase 21+에서 판단. DoD: GP-9/11/12 텍스트 현행 일치 + DH GP 항목 존재 + PR+human approval로 머지됨. Depends: none. [target: DesktopMatePlus/]

- [x] **WS-CQ-1: cq 강제 사용 제거 → docs/faq 문서화 규칙 대체** cc:DONE — safety-guardrails.md R00-CQ 규칙 제거. worker.md/reviewer.md/quality-agent.md에서 cq.query()/cq.propose() 스텝 제거. CLAUDE.md "cq Knowledge Sharing" 섹션 제거. 대체: "비자명한 학습은 docs/faq/에 문서화" 규칙 명시. settings.json cq env/allowedTools는 유지(수동 사용 가능). DoD: R00-CQ 삭제 + agent .md cq 스텝 제거 + CLAUDE.md cq 섹션 제거. Depends: none. [target: DesktopMatePlus/]

## Completed
