# Phase 2: 관측 가능성 레이어 (Observability)

> Archived from Plans.md — completed 2026-03-28

<!-- spec: docs/superpowers/specs/2026-03-28-backend-agent-run-env-design.md -->
<!-- cc:DONE -->
- [x] **OBS-1: log_query.py** — Loguru 로그 파싱 + `--level`/`--last`/`--since`/`--summary` 지원. DoD: `uv run python scripts/log_query.py --summary` 출력 정상. spec-ref: docs/superpowers/completed/specs/2026-03-28-backend-agent-run-env-design.md. [target: backend/]
- [x] **OBS-2: logs.sh** — log_query.py thin wrapper. `scripts/logs.sh --level ERROR --summary` 동작. DoD: 로그 파일 자동 감지(LOG_DIR → .run.logdir → 오늘 날짜 파일). Depends: OBS-1. spec-ref: docs/superpowers/completed/specs/2026-03-28-backend-agent-run-env-design.md. [target: backend/]
- [x] **OBS-3: run.sh** — worktree-aware 실행기. 포트 자동 해시, LOG_DIR 격리, 외부 서비스 체크 + Enter 대기, --bg/--stop/--port 플래그. DoD: `scripts/run.sh --bg` 기동 후 `scripts/run.sh --port` 일관된 포트 출력. spec-ref: docs/superpowers/completed/specs/2026-03-28-backend-agent-run-env-design.md. [target: backend/]
- [x] **OBS-4: verify.sh** — health + examples + 로그 클린 체크. DoD: `scripts/verify.sh` exit 0 (전체 PASS) / exit 1 (실패). Depends: OBS-2, OBS-3. spec-ref: docs/superpowers/completed/specs/2026-03-28-backend-agent-run-env-design.md. [target: backend/]
