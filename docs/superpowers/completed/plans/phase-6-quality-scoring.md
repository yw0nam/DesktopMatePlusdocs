# Phase 6: 품질 등급 추적 (Quality Scoring)

> Archived from Plans.md — completed 2026-03-29

<!-- cc:DONE -->
- [x] **QS-1: 품질 등급 문서** — `docs/QUALITY_SCORE.md` 신규. 도메인(backend/nanoclaw/dh)별 + 레이어별(arch/test/obs/docs) 품질 등급(A~D). DoD: 문서 존재 + 초기 등급 확정. [target: workspace scripts/harness/]
- [x] **QS-2: 품질 등급 자동 갱신** — gardening agent가 GP 결과를 QS-1 문서에 반영. DoD: `scripts/garden.sh --dry-run` 실행 시 QUALITY_SCORE.md에 갱신 날짜 + 각 도메인 등급 출력. Depends: GC-2, QS-1. [target: workspace scripts/harness/]
