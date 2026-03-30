# Phase 7: Docs Consolidation

> Archived from Plans.md — completed 2026-03-30

<!-- spec: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md -->
<!-- cc:DONE -->
- [x] **DC-0: quality-team 스킬 정의** — quality-team용 teammate-workflow 확장 또는 별도 스킬 파일 생성. TASK_DONE 프로토콜 처리, 아카이빙 로직, INDEX.md 동기화 포함. DoD: quality-team 스폰 시 역할 자동 로드. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: workspace scripts/harness/]
- [x] **DC-1: 디렉토리 마이그레이션** — docs/superpowers/completed/{specs,plans,prds}/ 생성. docs/plans/ → completed/plans/, docs/prds/feature/*.md(INDEX.md 제외) → completed/prds/, 완료된 specs/plans → completed/. docs/plans/, docs/prds/ 삭제. DoD: 활성 디렉토리에 완료 파일 0개, docs/plans/ 및 docs/prds/ 삭제됨. Depends: DC-0. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: docs/]
- [x] **DC-2: INDEX.md 이전 + 갱신** — docs/prds/feature/INDEX.md → docs/superpowers/INDEX.md로 이동. Plans.md Phase 참조 컬럼 추가. DoD: INDEX.md가 docs/superpowers/에 존재, 기존 링크 정상. Depends: DC-1. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: docs/]
- [x] **DC-3: Plans.md spec-ref 필드 추가** — 기존 cc:TODO/DONE 태스크에 spec-ref: 필드 추가 (해당하는 것만). 신규 태스크 포맷 문서화. DoD: Plans.md 내 모든 기능 태스크에 spec-ref 존재. Depends: DC-1. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: workspace/]
- [x] **DC-4: CLAUDE.md 참조 업데이트** — 루트 CLAUDE.md + docs/CLAUDE.md 내 디렉토리 맵, FAQ 링크, Appendix 참조를 새 구조에 맞게 갱신. DoD: check_docs.sh 실행 시 dead link 0개. Depends: DC-1, DC-2. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: docs/]
- [x] **DC-5: garden.sh GP-11 추가** — Archive Freshness 감지. Plans.md spec-ref 파싱 → cc:DONE인데 활성 디렉토리에 있는 파일 WARN. GOLDEN_PRINCIPLES.md에 GP-11 추가. DoD: garden.sh --gp GP-11 실행 시 누락 파일 목록 정상 출력. Depends: DC-1, DC-3. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: workspace scripts/harness/]
- [x] **DC-6: 팀 구성 업데이트** — CLAUDE.md Agent Teams 섹션에 quality-team 추가. MEMORY.md 팀 목록 갱신. config.json 업데이트. DoD: 5명 팀 구성 문서화 완료. Depends: DC-0. spec-ref: docs/superpowers/specs/2026-03-30-docs-consolidation-design.md. [target: workspace/]
