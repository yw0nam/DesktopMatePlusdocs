# Phase 3: 엔트로피 제어 (Drift GC)

> Archived from Plans.md — completed 2026-03-29

<!-- cc:DONE -->
- [x] **GC-1: 황금 원칙 문서** — `docs/GOLDEN_PRINCIPLES.md` 신규. 아키텍처 불변 조건 + 취향 규칙을 gardening agent가 파싱 가능한 구조로 인코딩. DoD: 문서 존재 + 각 원칙에 검증 방법 명시. [target: workspace scripts/harness/]
- [x] **GC-2: Background gardening agent** — `scripts/garden.sh` 신규. GP-1~10 위반 감지 + Minor auto-fix + 레포별 PR 생성. Depends: GC-1. [target: workspace scripts/harness/]
  - [x] **GC-2a** — `scripts/garden.sh` 스켈레톤: `--dry-run` / `--gp` / `--repo` CLI 플래그 파싱, 헬퍼 함수 구조. DoD: `scripts/garden.sh --help` 정상 출력. | cc:DONE
  - [x] **GC-2b** — GP 감지 모듈: 각 GP Verify 명령 실행 → `{gp, repo, severity, status, details}` 수집. DoD: `--dry-run` 시 전체 GP 결과 stdout 출력. Depends: GC-2a. | cc:DONE
  - [x] **GC-2c** — Auto-fix 모듈: GP-3/GP-10 backend에 `ruff --fix` 적용 → 재검증 → 성공 시 "auto-fixed" 태그. DoD: 실제 `print()` 삽입 후 `--dry-run` 없이 실행 시 auto-fixed 표시. Depends: GC-2b. | cc:DONE
  - [x] **GC-2d** — 리포트 + PR 생성: `GARDEN_REPORT.md` 생성 → `fix/garden-{date}` 브랜치 → `gh pr create`. DoD: 위반 1건 이상 시 PR URL 출력. Depends: GC-2c. | cc:DONE
