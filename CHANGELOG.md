# Changelog

All notable changes to the DesktopMatePlus workspace coordination layer are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
