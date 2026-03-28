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

<!-- spec: docs/superpowers/specs/2026-03-28-backend-agent-run-env-design.md -->
<!-- cc:DONE -->
- [x] **OBS-1: log_query.py** — Loguru 로그 파싱 + `--level`/`--last`/`--since`/`--summary` 지원. DoD: `uv run python scripts/log_query.py --summary` 출력 정상. [target: backend/]
- [x] **OBS-2: logs.sh** — log_query.py thin wrapper. `scripts/logs.sh --level ERROR --summary` 동작. DoD: 로그 파일 자동 감지(LOG_DIR → .run.logdir → 오늘 날짜 파일). Depends: OBS-1. [target: backend/]
- [x] **OBS-3: run.sh** — worktree-aware 실행기. 포트 자동 해시, LOG_DIR 격리, 외부 서비스 체크 + Enter 대기, --bg/--stop/--port 플래그. DoD: `scripts/run.sh --bg` 기동 후 `scripts/run.sh --port` 일관된 포트 출력. [target: backend/]
- [x] **OBS-4: verify.sh** — health + examples + 로그 클린 체크. DoD: `scripts/verify.sh` exit 0 (전체 PASS) / exit 1 (실패). Depends: OBS-2, OBS-3. [target: backend/]

### Phase 3: 엔트로피 제어 (Drift GC)

<!-- cc:TODO -->
- [ ] **Background gardening agent 설계** — harness.txt 원칙: 드리프트를 주기적으로 청소하는 백그라운드 에이전트. "황금 원칙" 위반 감지 → 자동 리팩터링 PR. Reviewer와 별도 역할. [target: workspace scripts/harness/]

## Completed

### Phase 2: 관측 가능성 레이어 (2026-03-28)

- [x] **OBS-1~4: Backend Agent Run Environment** — `scripts/run.sh`, `scripts/verify.sh`, `scripts/logs.sh`, `scripts/log_query.py` 신규 생성. worktree별 포트 격리, LOG_DIR 격리, 외부 서비스 Enter 대기, health/examples/로그 검증 자동화. (2026-03-28)

### Phase 1: 아키텍처 강제 (2026-03-28)

- [x] **NanoClaw 구조적 테스트 NC-S1~NC-S4** — `nanoclaw/src/structural/architecture.test.ts` 신규 생성. 5개 테스트 모두 GREEN. Debt: container-runtime.ts(console.error), container-runner.ts/db.ts/ipc.ts/mount-security.ts(LOC 초과) KNOWN 등록.

## Delegation Log
