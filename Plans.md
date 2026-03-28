# DesktopMatePlus — Lead Agent Coordination

> **Lead Agent Rule**: This agent delegates and coordinates ONLY. Never writes code directly.
> All implementation is delegated to repo teams via Subagent dispatch.

## Repo Teams

| Repo | Team | Stack | Constraint |
|------|------|-------|------------|
| `backend/` | Backend Team | Python / FastAPI / uv | — |
| `nanoclaw/` | NanoClaw Team | Node.js / TypeScript | skill-as-branch only (no direct source edit) |
| `desktop-homunculus/` | DH Team | Rust / Bevy + TypeScript MOD | separate git repo |

## Active Cross-Repo Tasks

<!-- cc:TODO format: [ ] task description [target: repo] -->

### Phase 1: 아키텍처 강제 (Architecture Enforcement)

- [x] **Backend 커스텀 린터 / 구조적 테스트** — `tests/structural/test_architecture.py` (9 tests: import layering, file size, conventions), ruff 규칙 추가 (UP/SIM/RUF/A/TID), `scripts/lint.sh` 통합 (2026-03-27)

<!-- NanoClaw 구조적 테스트 — nanoclaw/src/structural/architecture.test.ts -->
<!-- spec: docs/superpowers/specs/2026-03-27-nanoclaw-structural-tests-design.md -->

<!-- cc:DONE -->
- [x] **NC-S1: T4 console.log 금지** — `src/**/*.ts` (test/d.ts 제외)에 `console.*` 미존재 검증. DoD: `npm test` NC-S1 그린. [target: nanoclaw/]
- [x] **NC-S2: T3 파일 LOC 제한** — `src/**/*.ts` 400줄 상한, `index.ts` 800줄 특례, `KNOWN_LARGE_FILES` 초기값 확정. DoD: `npm test` NC-S2 그린, debt 목록 확정. Depends: NC-S1. [target: nanoclaw/]
- [x] **NC-S3: T1 Channel self-registration** — T1-1(모든 채널 파일이 `registerChannel(` 포함), T1-2(index.ts가 전부 import). DoD: `npm test` NC-S3 그린, http.ts로 양쪽 패스. Depends: NC-S2. [target: nanoclaw/]
- [x] **NC-S4: T2 skill-as-branch 화이트리스트** — `KNOWN_SRC_FILES` 초기값 확정, 미등록 파일 추가 시 즉시 실패. DoD: `npm test` NC-S4 그린, `npm run build` 타입 에러 없음. Depends: NC-S3. [target: nanoclaw/]

### Phase 2: 관측 가능성 레이어 (Observability)

<!-- cc:TODO -->
- [ ] **Developer/Reviewer Agent용 worktree별 앱 실행 환경** — harness.txt 원칙: 에이전트가 앱을 직접 실행하고 로그/메트릭으로 검증. Backend worktree별 독립 실행 스크립트 + 로그 쿼리 인터페이스 설계. [target: backend/, scripts/]

### Phase 3: 엔트로피 제어 (Drift GC)

<!-- cc:TODO -->
- [ ] **Background gardening agent 설계** — harness.txt 원칙: 드리프트를 주기적으로 청소하는 백그라운드 에이전트. "황금 원칙" 위반 감지 → 자동 리팩터링 PR. Reviewer와 별도 역할. [target: workspace scripts/harness/]

## Completed

### Phase 1: 아키텍처 강제 (2026-03-28)

- [x] **NanoClaw 구조적 테스트 NC-S1~NC-S4** — `nanoclaw/src/structural/architecture.test.ts` 신규 생성. 5개 테스트 모두 GREEN. Debt: container-runtime.ts(console.error), container-runner.ts/db.ts/ipc.ts/mount-security.ts(LOC 초과) KNOWN 등록.

## Delegation Log
