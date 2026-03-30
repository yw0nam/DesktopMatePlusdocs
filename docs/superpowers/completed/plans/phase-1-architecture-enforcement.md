# Phase 1: 아키텍처 강제 (Architecture Enforcement)

> Archived from Plans.md — completed 2026-03-28

- [x] **Backend 커스텀 린터 / 구조적 테스트** — `tests/structural/test_architecture.py` (9 tests: import layering, file size, conventions), ruff 규칙 추가 (UP/SIM/RUF/A/TID), `scripts/lint.sh` 통합 (2026-03-27)

<!-- NanoClaw 구조적 테스트 — nanoclaw/src/structural/architecture.test.ts -->
<!-- spec: docs/superpowers/specs/2026-03-27-nanoclaw-structural-tests-design.md -->

<!-- cc:DONE -->
- [x] **NC-S1: T4 console.log 금지** — `src/**/*.ts` (test/d.ts 제외)에 `console.*` 미존재 검증. DoD: `npm test` NC-S1 그린. spec-ref: docs/superpowers/completed/specs/2026-03-27-nanoclaw-structural-tests-design.md. [target: nanoclaw/]
- [x] **NC-S2: T3 파일 LOC 제한** — `src/**/*.ts` 400줄 상한, `index.ts` 800줄 특례, `KNOWN_LARGE_FILES` 초기값 확정. DoD: `npm test` NC-S2 그린, debt 목록 확정. Depends: NC-S1. spec-ref: docs/superpowers/completed/specs/2026-03-27-nanoclaw-structural-tests-design.md. [target: nanoclaw/]
- [x] **NC-S3: T1 Channel self-registration** — T1-1(모든 채널 파일이 `registerChannel(` 포함), T1-2(index.ts가 전부 import). DoD: `npm test` NC-S3 그린, http.ts로 양쪽 패스. Depends: NC-S2. spec-ref: docs/superpowers/completed/specs/2026-03-27-nanoclaw-structural-tests-design.md. [target: nanoclaw/]
- [x] **NC-S4: T2 skill-as-branch 화이트리스트** — `KNOWN_SRC_FILES` 초기값 확정, 미등록 파일 추가 시 즉시 실패. DoD: `npm test` NC-S4 그린, `npm run build` 타입 에러 없음. Depends: NC-S3. spec-ref: docs/superpowers/completed/specs/2026-03-27-nanoclaw-structural-tests-design.md. [target: nanoclaw/]
