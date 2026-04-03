# Plans Archive — Phase 12–20

Archived from `Plans.md` on 2026-04-03. All tasks cc:DONE.

---

### Phase 12: Desktop Homunculus FE UX Improvements (REVERTED — redesign needed)

- [x] **DH-F1: Chat Bar Drag Fix** cc:DONE [a779aad]
- [x] **DH-F2: TTS Sequential Playback** cc:DONE [eb142b9]
- [x] **DH-F3: Screen Capture - Service Layer** cc:DONE [b4e27ab]
- [x] **DH-F4: Screen Capture - UI** cc:DONE [24f38df]
- [x] **DH-F5: Screen Capture - Message Integration** cc:DONE [beeec85]

### Phase 12 후속: Backend 버그

- [x] **BE-BUG-1: Session Continuity Error** cc:DONE [bad7ef8]

### Phase 13: FE Design Agent — Agent Team 추가

- [x] **DA-S1: Create .claude/agents/design-agent.md** cc:DONE
- [x] **DA-S2: Update CLAUDE.md — Agent Teams + Lead flow** cc:DONE
- [x] **DA-S3: Create docs/faq/fe-design-agent-workflow.md** cc:DONE
- [x] **DA-S4: Update Plans.md DA-xxx task conventions** cc:DONE
- [x] **DA-S5: design-agent 파일럿 실행** cc:DONE

### Phase 14: desktopmate-bridge 버그 수정

- [x] **DH-BUG-2: Token leak via getStatus RPC + dm-config signal** cc:DONE [09fa4f5]
- [x] **DH-BUG-3: TtsChunkQueue flush 동시성 버그** cc:DONE [b2c3fc8]
- [x] **DH-BUG-4: JSON.parse try/catch 누락** cc:DONE [7b83421]
- [x] **DH-BUG-5: connectWithRetry 구 WebSocket 미취소** cc:DONE [7b83421]
- [x] **DH-BUG-6: URL 파라미터 미인코딩** cc:DONE [298dd76]
- [x] **DH-BUG-7: captureScreen 빈 모니터 배열 미방어** cc:DONE [298dd76]
- [x] **DH-BUG-8: open-chat TOCTOU — 동일 Webview 두 인스턴스** cc:DONE [298dd76]

### Phase 15: desktopmate-bridge + Fish Speech 버그 수정

- [x] **DH-BUG-9: TTS 동시 재생** cc:DONE [a624ed0]
- [x] **BE-BUG-2: Fish Speech 에러 로그 복원** cc:DONE [3fe1836]
- [x] **BE-BUG-3: Fish Speech TTS 직렬 큐 워커** cc:DONE [3fe1836]
- [x] **BE-BUG-4: stream_token WS 미전달** cc:DONE [3fe1836]
- [x] **DH-BUG-10: stream_token FE 미표시** cc:DONE [a624ed0]
- [x] **DH-BUG-11: images 타입 불일치** cc:DONE [a624ed0]
- [x] **DH-BUG-12: Webview drag 스케일 오류 + async 레이스** cc:DONE [a624ed0]
- [x] **DH-BUG-13: Reconnect 버튼** cc:DONE [f628053]

### Phase 16: Irodori TTS 교체 + Emoji Emotion + 버그 수정

- [x] **BE-FEAT-1: IrodoriTTSService 클라이언트** cc:DONE [9766cb2]
- [x] **BE-FEAT-2: Emoji 기반 Emotion 시스템 교체 + Fish Speech 제거** cc:DONE [PR#7]
- [x] **DH-BUG-14: dm-stream-token / dm-tts-chunk 역할 분리** cc:DONE [0260b12]
- [x] **DH-BUG-15: handleDragStart mouseup listener leak** cc:DONE [PR#5]
- [x] **DH-BUG-16: TtsChunkQueue reset() in-flight chain 미취소** cc:DONE [PR#5]

### Phase 17: Irodori Multi-Voice + Backend Verification

- [x] **BE-FEAT-3: IrodoriTTSService Multi-Voice 지원** cc:DONE [3c883af]
- [x] **BE-DOC-1: Backend Task Verification 표준화** cc:DONE [315dd13]

### Phase 19: Agent E2E Verification Pipeline

- [x] **BE-E2E-1: backend/scripts/e2e.sh 작성 + run.sh BACKEND_PORT 지원** cc:DONE [e6c23dd]
- [x] **BE-E2E-2: backend examples 재작성 (args 방식)** cc:DONE [e6c23dd]
- [x] **DH-PROBE-1: DH MOD standalone 실행 가능 여부 확인** cc:DONE
- [x] **DH-E2E-1: DH MOD E2E 프로토콜 작성** cc:DONE
- [x] **WS-E2E-1: workspace root scripts/e2e.sh 작성** cc:DONE [66409d6]
- [x] **DOC-E2E-1: Plans.md DoD 템플릿 표준화** cc:DONE [66409d6]

### Phase 20: Agent Harness Quality Upgrade

- [x] **WS-REV-1: reviewer.md B+ Evaluator 패턴** cc:DONE
- [x] **WS-DOC-2: CLAUDE.md PRD Tracking → docs/TODO.md 전환** cc:DONE
- [x] **WS-QA-1: Background Quality Agent 신설 + garden.sh 개선** cc:DONE
- [x] **WS-GP-1: GOLDEN_PRINCIPLES.md 일관성 수정** cc:DONE [PR#3 merged 2496b78]
- [x] **WS-CQ-1: cq 강제 사용 제거 → docs/faq 문서화 규칙 대체** cc:DONE
