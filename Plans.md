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
- [x] **GC-1: 황금 원칙 문서** — `docs/GOLDEN_PRINCIPLES.md` 신규. 아키텍처 불변 조건 + 취향 규칙을 gardening agent가 파싱 가능한 구조로 인코딩. DoD: 문서 존재 + 각 원칙에 검증 방법 명시. [target: workspace scripts/harness/]
- [x] **GC-2: Background gardening agent** — `scripts/garden.sh` 신규. GP-1~10 위반 감지 + Minor auto-fix + 레포별 PR 생성. Depends: GC-1. [target: workspace scripts/harness/]
  - [x] **GC-2a** — `scripts/garden.sh` 스켈레톤: `--dry-run` / `--gp` / `--repo` CLI 플래그 파싱, 헬퍼 함수 구조. DoD: `scripts/garden.sh --help` 정상 출력. | cc:DONE
  - [x] **GC-2b** — GP 감지 모듈: 각 GP Verify 명령 실행 → `{gp, repo, severity, status, details}` 수집. DoD: `--dry-run` 시 전체 GP 결과 stdout 출력. Depends: GC-2a. | cc:DONE
  - [x] **GC-2c** — Auto-fix 모듈: GP-3/GP-10 backend에 `ruff --fix` 적용 → 재검증 → 성공 시 "auto-fixed" 태그. DoD: 실제 `print()` 삽입 후 `--dry-run` 없이 실행 시 auto-fixed 표시. Depends: GC-2b. | cc:DONE
  - [x] **GC-2d** — 리포트 + PR 생성: `GARDEN_REPORT.md` 생성 → `fix/garden-{date}` 브랜치 → `gh pr create`. DoD: 위반 1건 이상 시 PR URL 출력. Depends: GC-2c. | cc:DONE

### Phase 4: 문서 신선도 (Doc Freshness)

<!-- cc:TODO -->
- [ ] **DOC-1: 문서 신선도 린터** — `scripts/check_docs.sh` + CI 통합. docs/ 내 죽은 링크, 스펙 vs 실제 파일 불일치, 200줄 초과 문서 감지. DoD: `scripts/check_docs.sh` exit 0 (전체 PASS). [target: workspace scripts/harness/]
- [ ] **DOC-2: 문서 신선도 CI** — GitHub Actions 또는 pre-commit hook으로 DOC-1 자동 실행. DoD: PR 시 죽은 링크 자동 감지. Depends: DOC-1. [target: workspace scripts/harness/]

### Phase 5: 메트릭 관측 가능성 (Metrics Observability)

<!-- cc:TODO -->
- [ ] **MET-1: 앱 메트릭 노출** — FastAPI에 Prometheus 메트릭 엔드포인트(`/metrics`) 추가. request latency, error rate, active connections. DoD: `GET /metrics` → Prometheus 포맷 응답. [target: backend/]
- [ ] **MET-2: 메트릭 쿼리 스크립트** — `scripts/metrics.sh` — worktree별 메트릭 조회 + 임계값 초과 알림. DoD: `scripts/metrics.sh --latency p99` 정상 출력. Depends: MET-1. [target: backend/]

### Phase 6: 품질 등급 추적 (Quality Scoring)

<!-- cc:TODO -->
- [ ] **QS-1: 품질 등급 문서** — `docs/QUALITY_SCORE.md` 신규. 도메인(backend/nanoclaw/dh)별 + 레이어별(arch/test/obs/docs) 품질 등급(A~D). DoD: 문서 존재 + 초기 등급 확정. [target: workspace scripts/harness/]
- [ ] **QS-2: 품질 등급 자동 갱신** — gardening agent가 QS-1 문서를 주기적으로 업데이트. Depends: GC-2, QS-1. [target: workspace scripts/harness/]

## Completed

### Phase 2: 관측 가능성 레이어 (2026-03-28)

- [x] **OBS-1~4: Backend Agent Run Environment** — `scripts/run.sh`, `scripts/verify.sh`, `scripts/logs.sh`, `scripts/log_query.py` 신규 생성. worktree별 포트 격리, LOG_DIR 격리, 외부 서비스 Enter 대기, health/examples/로그 검증 자동화. (2026-03-28)

### Phase 1: 아키텍처 강제 (2026-03-28)

- [x] **NanoClaw 구조적 테스트 NC-S1~NC-S4** — `nanoclaw/src/structural/architecture.test.ts` 신규 생성. 5개 테스트 모두 GREEN. Debt: container-runtime.ts(console.error), container-runner.ts/db.ts/ipc.ts/mount-security.ts(LOC 초과) KNOWN 등록.

## Delegation Log
