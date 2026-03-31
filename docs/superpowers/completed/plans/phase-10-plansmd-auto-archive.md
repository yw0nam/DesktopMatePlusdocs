### Phase 10: Plans.md 자동 아카이빙 (Auto-Archive)

<!-- cc:TODO -->
- [x] **AA-1: garden.sh Plans.md 자동 아카이빙 함수** — Phase 내 모든 태스크가 `[x]`이면 해당 Phase 블록을 `docs/superpowers/completed/plans/` 파일로 추출하고, Plans.md에는 Phase 제목 + archived 링크만 남긴다. 완료된 Phase가 참조하는 spec/plan 파일도 `completed/specs/`, `completed/plans/`로 이동. DoD: `garden.sh --gp GP-12` 실행 시 아카이빙 대상 감지, `--dry-run` 없이 실행 시 자동 이동 + Plans.md 갱신. [target: workspace scripts/harness/]
- [x] **AA-2: GP-12 + pre-commit hook 등록** — `docs/GOLDEN_PRINCIPLES.md`에 GP-12 (Plans.md Auto-Archive) 추가. `.pre-commit-config.yaml`에 garden.sh archive check 등록. DoD: `garden.sh --gp GP-12` 정상 출력, pre-commit hook에서 감지 실행. Depends: AA-1. [target: workspace scripts/harness/]
