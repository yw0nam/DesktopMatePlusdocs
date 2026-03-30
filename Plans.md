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
- [x] **DOC-1: 문서 신선도 린터** — `scripts/check_docs.sh` + CI 통합. docs/ 내 죽은 링크, 스펙 vs 실제 파일 불일치, 200줄 초과 문서 감지. DoD: `scripts/check_docs.sh` exit 0 (전체 PASS). [target: workspace scripts/harness/]
- [x] **DOC-2: 문서 신선도 garden 통합** — `scripts/garden.sh`에 `check_docs.sh` 호출 추가 + `.pre-commit-config.yaml` 등록. DoD: `scripts/garden.sh --gp DOC` 실행 시 doc check 결과 출력. Depends: DOC-1, GC-2. [target: workspace scripts/harness/]

### Phase 5: 메트릭 관측 가능성 (Metrics Observability)

<!-- cc:TODO -->
- ~~**MET-1/2**~~ — removed (over-engineered for current scope)

### Phase 6: 품질 등급 추적 (Quality Scoring)

<!-- cc:TODO -->
- [x] **QS-1: 품질 등급 문서** — `docs/QUALITY_SCORE.md` 신규. 도메인(backend/nanoclaw/dh)별 + 레이어별(arch/test/obs/docs) 품질 등급(A~D). DoD: 문서 존재 + 초기 등급 확정. [target: workspace scripts/harness/]
- [x] **QS-2: 품질 등급 자동 갱신** — gardening agent가 GP 결과를 QS-1 문서에 반영. DoD: `scripts/garden.sh --dry-run` 실행 시 QUALITY_SCORE.md에 갱신 날짜 + 각 도메인 등급 출력. Depends: GC-2, QS-1. [target: workspace scripts/harness/]

### Phase 7: Docs Consolidation

<!-- spec: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md -->
<!-- cc:TODO -->
- [ ] **DC-0: quality-team 스킬 정의** — quality-team용 teammate-workflow 확장 또는 별도 스킬 파일 생성. TASK_DONE 프로토콜 처리, 아카이빙 로직, INDEX.md 동기화 포함. DoD: quality-team 스폰 시 역할 자동 로드. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: workspace scripts/harness/]
- [x] **DC-1: 디렉토리 마이그레이션** — docs/superpowers/completed/{specs,plans,prds}/ 생성. docs/plans/ → completed/plans/, docs/prds/feature/*.md(INDEX.md 제외) → completed/prds/, 완료된 specs/plans → completed/. docs/plans/, docs/prds/ 삭제. DoD: 활성 디렉토리에 완료 파일 0개, docs/plans/ 및 docs/prds/ 삭제됨. Depends: DC-0. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: docs/]
- [x] **DC-2: INDEX.md 이전 + 갱신** — docs/prds/feature/INDEX.md → docs/superpowers/INDEX.md로 이동. Plans.md Phase 참조 컬럼 추가. DoD: INDEX.md가 docs/superpowers/에 존재, 기존 링크 정상. Depends: DC-1. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: docs/]
- [ ] **DC-3: Plans.md spec-ref 필드 추가** — 기존 cc:TODO/DONE 태스크에 spec-ref: 필드 추가 (해당하는 것만). 신규 태스크 포맷 문서화. DoD: Plans.md 내 모든 기능 태스크에 spec-ref 존재. Depends: DC-1. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: workspace/]
- [x] **DC-4: CLAUDE.md 참조 업데이트** — 루트 CLAUDE.md + docs/CLAUDE.md 내 디렉토리 맵, FAQ 링크, Appendix 참조를 새 구조에 맞게 갱신. DoD: check_docs.sh 실행 시 dead link 0개. Depends: DC-1, DC-2. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: docs/]
- [ ] **DC-5: garden.sh GP-11 추가** — Archive Freshness 감지. Plans.md spec-ref 파싱 → cc:DONE인데 활성 디렉토리에 있는 파일 WARN. GOLDEN_PRINCIPLES.md에 GP-11 추가. DoD: garden.sh --gp GP-11 실행 시 누락 파일 목록 정상 출력. Depends: DC-1, DC-3. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: workspace scripts/harness/]
- [ ] **DC-6: 팀 구성 업데이트** — CLAUDE.md Agent Teams 섹션에 quality-team 추가. MEMORY.md 팀 목록 갱신. config.json 업데이트. DoD: 5명 팀 구성 문서화 완료. Depends: DC-0. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: workspace/]

## Completed

### Phase 2: 관측 가능성 레이어 (2026-03-28)

- [x] **OBS-1~4: Backend Agent Run Environment** — `scripts/run.sh`, `scripts/verify.sh`, `scripts/logs.sh`, `scripts/log_query.py` 신규 생성. worktree별 포트 격리, LOG_DIR 격리, 외부 서비스 Enter 대기, health/examples/로그 검증 자동화. (2026-03-28)

### Phase 1: 아키텍처 강제 (2026-03-28)

- [x] **NanoClaw 구조적 테스트 NC-S1~NC-S4** — `nanoclaw/src/structural/architecture.test.ts` 신규 생성. 5개 테스트 모두 GREEN. Debt: container-runtime.ts(console.error), container-runner.ts/db.ts/ipc.ts/mount-security.ts(LOC 초과) KNOWN 등록.

## Delegation Log
