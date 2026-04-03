# Changelog

All notable changes to the DesktopMatePlus workspace coordination layer are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0.2] - 2026-04-03

### Fixed
- `scripts/garden.sh` — GP-13 console.log grep now excludes `mods/*/scripts/` via `--exclude-dir=scripts`
- `scripts/garden.sh` — `update_quality_score()` now updates QUALITY_SCORE.md Violations Summary with actual GP-3 and GP-13 violation counts (previously always showed 0)
- `scripts/check_docs.sh` — `docs/superpowers/` excluded from dead link and oversized-doc checks

### Changed
- `Plans.md` — Phases 12–17, 19–20 (all cc:DONE) archived to `docs/archive/plans-2026-04.md`; Phase 18 (cc:TODO) retained

## [0.1.0.1] - 2026-04-03

### Changed
- `quality-agent.md` — Constraints에 PR 생성 금지 명시 (PR은 run-quality-agent.sh 담당)
- `pr-merge-agent.md` — Quality PR block을 AUTO_FIX/ACKNOWLEDGE/NEEDS_LEAD 분류 체계로 교체; reviewer 용어를 "GitHub Bot Reviewer" / "GitHub Human Reviewer"로 통일
- `pm-agent.md` — Lifecycle Step 4: PM이 docs/TODO.md 작성하도록 수정 (Plans.md는 Lead 책임)
- `CLAUDE.md` — Reviewer APPROVE 후 Worker /ship 타이밍 명시; 브랜치 prefix 컨벤션 `{prefix}/p{N}-t{id}` 추가
- `docs/faq/fe-design-agent-workflow.md` — design-agent → worker 브랜치 인계 흐름 추가
- `.github/pull_request_template.md` — 첫 번째 체크박스를 E2E 확인 항목으로 교체

## [0.1.0.0] - 2026-04-03

### Added
- `quality-agent.md` — background QA agent that runs periodic drift detection, stale TODO detection, and archive bloat flagging; writes structured reports to `docs/reports/`
- `docs/TODO.md` — PM-generated active spec list with P0/P1/P2 priority table (replaces superpowers references)
- `docs/reports/` and `docs/archive/` directories for quality reports and archived plans
- GP-13 in `docs/GOLDEN_PRINCIPLES.md` — DH MOD TypeScript quality rules: no `console.log/warn/info`, files ≤ 400 lines
- `garden.sh --metrics` flag — runs detection and updates `QUALITY_SCORE.md` only, skips report generation

### Changed
- `reviewer.md` — 4-criteria scoring rubric (correctness/security/maintainability/test_coverage, 0–3 points each); any criterion < 2 → automatic FAIL; added `/qa` trigger for DH UI component changes
- `CLAUDE.md` — PRD Tracking section now references `docs/TODO.md` instead of superpowers; `/ship` and `/document-release` responsibilities clarified (worker/pr-merge-agent own these, Lead never runs them directly); Worktree Rules extended to workspace root (feature branch + worktree required for all changes)
- `safety-guardrails.md` — role table expanded with `/ship` and `/document-release` columns; R00-CQ section removed
- `pr-merge-agent.md` — Step 5 added: auto-run `/document-release` after merge
- `worker.md` — cq.query/propose steps replaced with `docs/faq/` documentation rule
- `docs/GOLDEN_PRINCIPLES.md` — GP-9 branch reference updated to `develop`; GP-11/12 archive rules updated to `docs/TODO.md` and `Plans.md` Phase collapse
- `docs/QUALITY_SCORE.md` — DH Rust rows marked UNCHECKED; Violations Summary section added
- `garden.sh` — GP-13 DH MOD console.log check with file:line output; file size >400 lines check; `docs/reports/` path unified; backend branch updated to `develop`

### Removed
- `harness-reviewer.md` and `harness-worker.md` — superseded by `worker` + `reviewer` agents
- cq MCP enforcement from `safety-guardrails.md`, `CLAUDE.md`, and all agent definitions
- cq env vars and allowedTools from `settings.json`
