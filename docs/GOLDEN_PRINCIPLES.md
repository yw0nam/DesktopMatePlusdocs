# Golden Principles

> **Purpose**: Invariants that must hold across all repos at all times.
> The Background Gardening Agent uses this as its checklist — each principle has a machine-verifiable DoD.
> When a violation is detected, a refactoring PR is opened automatically.

> **CONTRIBUTING**: This document is a protected invariant. Direct commits to this file are forbidden.
> All changes (adding, modifying, or removing a principle) **must go through a PR** and require explicit human approval before merge.

---

## GP-1: Architecture Layering

**Rule**: Dependency direction is strictly enforced per repo. No reverse imports.

| Repo | Layer order (lower → higher) |
|------|------------------------------|
| `backend/` | core → models → services → api |
| `nanoclaw/` | config → channels → ipc → router → index |

**Verify**: `uv run pytest tests/structural/test_architecture.py` (backend), `npm test -- --testPathPattern=structural` (nanoclaw)

**Severity**: Critical — structural test failure blocks merge.

---

## GP-2: File Size Limits

**Rule**: No source file exceeds its repo's line limit.

| Repo | Limit | Exception |
|------|-------|-----------|
| `backend/` | 300 lines | — |
| `nanoclaw/` | 400 lines | `index.ts` ≤ 800 lines |

New violations must be fixed immediately — never added to `_KNOWN_*` sets without a remediation plan.

**Verify**: `uv run pytest tests/structural/test_architecture.py::test_file_sizes` / `npm test -- --testPathPattern=structural`

**Severity**: Major — lint fails on new violations.

---

## GP-3: No Bare Logging

**Rule**: No `print()` in `backend/`, no `console.log()` in `nanoclaw/` source files.

| Repo | Required | Banned |
|------|----------|--------|
| `backend/` | `from src.core.logger import logger` (Loguru) | `print()` |
| `nanoclaw/` | structured logger or `logger.*` | `console.log/warn/info` in `src/**/*.ts` (excl. test/d.ts) |

**Verify**: `ruff check src/` (backend), `npm test -- --testPathPattern=structural` NC-S1 (nanoclaw)

**Severity**: Major.

---

## GP-4: No Hardcoded Config

**Rule**: No magic strings, ports, URLs, or credentials in source code.

- `backend/`: all config via `settings` object or `yaml_files/`. No hardcoded `localhost`, port numbers, or API keys.
- `nanoclaw/`: credentials managed by OneCLI gateway. No `.env` values in source.

**Verify**: `grep -rn "localhost\|127\.0\.0\.1\|mongodb://" src/` must return zero hits (excluding test files and config loaders).

**Severity**: Critical (credential exposure) / Major (config values).

---

## GP-5: Delegation Direction

**Rule**: Changes propagate in one direction only — `backend/ → nanoclaw/ → desktop-homunculus/`. Reverse dependencies are forbidden.

- NanoClaw never imports from backend source.
- desktop-homunculus never calls nanoclaw directly (only via FastAPI WebSocket).

**Verify**: No cross-repo `import` or `require()` paths pointing upstream.

**Severity**: Critical.

---

## GP-6: NanoClaw Skill-as-Branch

**Rule**: NanoClaw source is never modified directly. All capabilities are added via `skill/{name}` branches merged at install time.

- No direct edits to `nanoclaw/src/` outside of a `skill/*` branch.
- `KNOWN_SRC_FILES` whitelist enforced by NC-S4 structural test.

**Verify**: `npm test` NC-S4 — any unregistered source file fails immediately.

**Severity**: Critical.

---

## GP-7: CLAUDE.md as Map, Not Encyclopedia

**Rule**: Root `CLAUDE.md` stays under 120 lines. Sub-repo `CLAUDE.md` stays under 200 lines.
Detail goes in `docs/`, `docs/faq/`, or sub-directory `CLAUDE.md` files.

**Verify**: `wc -l CLAUDE.md` (root ≤ 120), `wc -l backend/CLAUDE.md` (≤ 200).

**Severity**: Minor — triggers a split suggestion PR.

---

## GP-8: Plans as First-Class Artifacts

**Rule**: Every task must exist in `Plans.md` with `cc:TODO` before implementation starts.
Plans.md changes must be committed in the same session as the task they track.

- Workspace `Plans.md` → cross-repo coordination
- Sub-repo `Plans.md` → repo-scoped task tracking

**Verify**: No `cc:WIP` task in any Plans.md without a corresponding commit on the feature branch.

**Severity**: Minor.

---

## GP-9: Worktree Isolation for Implementation

**Rule**: All implementation work happens inside a `git worktree` on a `feat/{slug}` branch.
Direct commits to `main`/`develop`/`feat/claude_harness` are forbidden during implementation.

**Verify**: `git log --oneline main..HEAD` in any sub-repo should only show merge commits from worktree branches.

**Severity**: Major — work done on main branch must be rebased to a feature branch.

---

## GP-10: Lint Before Merge

**Rule**: `sh scripts/lint.sh` must pass (exit 0) in `backend/` before any merge.
`npm run build` must pass in `nanoclaw/` before any merge.

**Verify**: CI / pre-merge gate.

**Severity**: Critical — blocks merge.

---

## GP-11: Archive Freshness

**Rule**: Completed spec/plan files must be moved to `docs/superpowers/completed/` once all Plans.md tasks referencing them are `cc:DONE`.

- `spec-ref:` fields in Plans.md are parsed to identify referenced files.
- If ALL tasks referencing a spec-ref are `[x]` (done) and the file is still in `docs/superpowers/specs/` or `docs/superpowers/plans/` (active directories), it triggers a warning.
- Files referenced by any `[ ]` (TODO/WIP) task are exempt.

**Verify**: `scripts/garden.sh --gp GP-11` — lists stale files that should be archived.

**Severity**: WARN — garden.sh reports only; quality-team handles the actual `git mv` to `completed/`.

---

## GP-12: Plans.md Auto-Archive

**Rule**: Completed Phases in Plans.md (all tasks `[x]`) must be archived to `docs/superpowers/completed/plans/`. Plans.md retains only the Phase title with an `[archived]` link.

- Referenced `spec-ref:` files are moved to `completed/specs/` or `completed/plans/`.
- Already-archived Phases (with `archived` or `details` in the header) are skipped.
- garden.sh detects and auto-archives in non-dry-run mode.

**Verify**: `scripts/garden.sh --gp GP-12` — lists unarchived completed Phases.

**Severity**: WARN — garden.sh auto-archives; no merge block.

---

## Appendix: Gardening Agent Usage

The Background Gardening Agent runs each principle's **Verify** command and opens a PR when violations are found.
Priority order for automated remediation: GP-10 → GP-3 → GP-12 → GP-2 → GP-7 → GP-8.
GP-1, GP-5, GP-6 require human review before auto-merge.
