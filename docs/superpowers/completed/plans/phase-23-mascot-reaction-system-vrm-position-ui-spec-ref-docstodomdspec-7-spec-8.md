### Phase 23: Mascot Reaction System + VRM Position UI — spec-ref: docs/TODO.md#spec-7, #spec-8

<!-- source: docs/TODO.md Spec 7 (2026-04-04), Spec 8 (2026-04-04). -->

- [x] **BE-23-1: TTS speak endpoint 추가** cc:DONE [1fb7a27] — `backend/src/api/routes/tts.py`에 `POST /v1/tts/speak` 추가 (`text` → `{ audio_base64 }`). DoD: Pytest TDD 통과 + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **DH-23-1: ReactionController 구현** cc:DONE [419386d] — `desktopmate-bridge/src/reaction-controller.ts` 신규. Click/Idle(5분)/ScreenContext(`active-win`) 3가지 트리거. `tts-chunk-queue.ts`에 `isBusy()` 추가(채팅 TTS 충돌 방지). `config.yaml`에 `reactions` 섹션 추가. `pnpm add active-win`. DoD: Vitest unit test 통과(click/idle/window 각 트리거) + E2E mock 테스트 통과 + 채팅 TTS 중 reaction skip. Depends: BE-23-1. [target: desktop-homunculus/]
- [x] **BE-23-fix: e2e 버그 수정** cc:DONE [8610cc1] — `invoke()` persona SystemMessage 중복 삽입 방지 (`and not session_id`). `ltm_middleware.py` SystemMessage 중복 주입 방지. `stm.py` session_registry upsert + checkpointer.delete_thread() 추가. DoD: e2e.sh Phase 4/5 PASSED. [target: backend/]
- [x] **DH-23-2: VRM Position Adjustment UI** cc:DONE [491d2be] — `character-settings` MOD `BasicTab.tsx`에 Position X/Y 슬라이더 + 숫자 입력 추가. `useCharacterSettings.ts` posX/posY state 추가. Save 클릭 시만 반영(실시간 미리보기 없음). `translation[2]` 보존 필수. DoD: Vitest unit test 통과 + `/agent-browser` visual verification + 슬라이더 range 실측 확인. Depends: none. [target: desktop-homunculus/]
