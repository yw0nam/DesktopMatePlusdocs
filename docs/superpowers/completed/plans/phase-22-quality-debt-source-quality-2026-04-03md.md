### Phase 22: Quality Debt 해소 — source: quality-2026-04-03.md

<!-- source: docs/reports/quality-2026-04-03.md (2026-04-03). GP-3/4/13 위반 + garden.sh 버그 + 아카이브 정리. -->

- [x] **QA-1: BE GP-4 하드코딩 URL 해소** cc:DONE — `backend/` 내 하드코딩 URL 5개를 `yaml_files/` YAML 설정 또는 환경변수로 이전. 대상: `vllm_omni.py:20` (base_url), `tts_factory.py:38` (IRODORI_URL), `disconnect_handler.py:11` (BACKEND_URL), `agent_factory.py:46` (openai_api_base), `delegate_task.py:15` (NANOCLAW_URL). DoD: GP-4 PASS + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **QA-2: BE GP-3 bare print 제거** cc:DONE — `ltm_factory.py:40,50,52`, `vllm_omni.py:264,272` bare print → loguru. DoD: GP-3 PASS + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **QA-3: DH-MOD GP-13 console.log + 파일 크기** cc:DONE — ① `tts-chunk-queue.ts:85,104` console.log 제거 (프로덕션 코드) ② `ControlBar.test.tsx` (445줄) → 400줄 이하로 분리. DoD: GP-13-console PASS + GP-13-size PASS. Depends: none. [target: desktop-homunculus/]
- [x] **QA-4: garden.sh 버그 수정 + scripts/ 예외 처리** cc:DONE — ① GP-13 console.log 체크에서 `mods/*/scripts/` 디렉토리 제외 ② `update_quality_score()` 함수가 `QUALITY_SCORE.md` Violations Summary 섹션을 실제 위반 수로 갱신하도록 수정. DoD: GP-13-console이 scripts/ 파일을 스캔하지 않음 + QUALITY_SCORE.md Violations Summary가 정확히 갱신됨. Depends: none. [target: DesktopMatePlus/]
- [x] **QA-5: Plans.md 아카이브 + docs/superpowers check_docs 제외** cc:DONE — ① Plans.md Phase 12~20 완료 Phase → `docs/archive/plans-2026-04.md`로 이전 ② `scripts/check_docs.sh`에서 `docs/superpowers/` 디렉토리를 dead link 및 oversized 체크 제외 목록에 추가. DoD: Plans.md cc:DONE Phase 5개 미만 잔존 + GP-12 PASS + check_docs.sh superpowers 스캔 안 함. Depends: none. [target: DesktopMatePlus/]
