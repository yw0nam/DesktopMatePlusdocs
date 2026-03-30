# Phase 4: 문서 신선도 (Doc Freshness)

> Archived from Plans.md — completed 2026-03-29

<!-- cc:DONE -->
- [x] **DOC-1: 문서 신선도 린터** — `scripts/check_docs.sh` + CI 통합. docs/ 내 죽은 링크, 스펙 vs 실제 파일 불일치, 200줄 초과 문서 감지. DoD: `scripts/check_docs.sh` exit 0 (전체 PASS). [target: workspace scripts/harness/]
- [x] **DOC-2: 문서 신선도 garden 통합** — `scripts/garden.sh`에 `check_docs.sh` 호출 추가 + `.pre-commit-config.yaml` 등록. DoD: `scripts/garden.sh --gp DOC` 실행 시 doc check 결과 출력. Depends: DOC-1, GC-2. [target: workspace scripts/harness/]
