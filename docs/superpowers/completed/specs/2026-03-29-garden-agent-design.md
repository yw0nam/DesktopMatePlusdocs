# Background Gardening Agent — Design Spec

**Date**: 2026-03-29
**Status**: Approved
**Target**: `workspace scripts/` (`scripts/garden.sh`)

## Overview

`docs/GOLDEN_PRINCIPLES.md`의 GP-1~GP-10 Verify 명령을 실행해 드리프트를 감지하고, 자동 수정 가능한 Minor 위반은 쉘 명령으로 수정한 뒤 레포별 PR을 생성한다.

## 파일 구조

```
scripts/           ← 워크스페이스 루트 신규
└── garden.sh      # 단일 스크립트 (~150줄)
```

## CLI 인터페이스

```bash
scripts/garden.sh                 # 전체 GP 실행 (기본)
scripts/garden.sh --dry-run       # 감지만, PR/커밋 없음
scripts/garden.sh --gp GP-3       # 특정 GP만 실행
scripts/garden.sh --repo backend  # 특정 레포만 검사
```

## 실행 흐름

### 1. 감지 (Detection)

각 GP의 Verify 명령을 해당 레포 디렉토리에서 실행한다.
결과를 `{GP-id, repo, severity, status, details}` 형태로 수집한다.

### 2. 자동 수정 (Auto-fix, Minor only)

쉘 명령으로 수정 가능한 경우에만 시도한다:

| GP | 레포 | Auto-fix 명령 |
|----|------|---------------|
| GP-3 | backend | `cd backend && uv run ruff check src/ --fix` |
| GP-10 | backend | `cd backend && sh scripts/lint.sh` (ruff --fix 포함) |

수정 후 재검증을 실행해 통과하면 "auto-fixed", 실패하면 "report"로 강등한다.

### 3. PR 생성

위반이 1건 이상인 레포마다 개별 PR을 생성한다.

```bash
# 각 영향 레포에서
git checkout -b fix/garden-{YYYY-MM-DD}

# auto-fixed 파일이 있으면
git add <fixed-files>
git commit -m "fix: garden auto-fix GP-N violations"

# GARDEN_REPORT.md 생성 후 커밋
git add GARDEN_REPORT.md
git commit -m "docs: garden report {date}"

# PR 오픈
gh pr create \
  --title "garden: drift report {date}" \
  --base {working-branch} \
  --body "$(cat GARDEN_REPORT.md)"
```

PR 타깃 브랜치:

| 레포 | working branch |
|------|----------------|
| `backend/` | `feat/claude_harness` |
| `nanoclaw/` | `develop` |
| `DesktopMatePlus/` | `master` |

### 4. 요약 출력

```
=== Garden Run 2026-03-29 ===

[GP-7]  PASS   workspace  CLAUDE.md 96 lines (≤120) ✓
[GP-3]  FAIL   backend    2 print() found → auto-fixing...
[GP-3]  FIXED  backend    ruff --fix applied
[GP-1]  FAIL   backend    test_architecture.py FAILED → report only

--- Summary ---
Repos with violations: backend (2 total, 1 auto-fixed, 1 report)
PRs created:
  backend → feat/claude_harness: fix/garden-2026-03-29
```

## GP별 처리 방식

| Severity | GP | 처리 |
|----------|----|----|
| Critical | GP-1, GP-4, GP-5, GP-6, GP-10 | 리포트 PR만 |
| Major | GP-2, GP-3, GP-9 | 리포트 PR만 |
| Minor (auto) | GP-3 backend, GP-10 backend | ruff --fix 후 auto-fixed PR |
| Minor | GP-7, GP-8 | 리포트 PR만 (쉘로 분리 불가) |

> GP-3, GP-10은 fix 후 재검증 성공 시에만 auto-fixed. 실패 시 리포트로 강등.

## GARDEN_REPORT.md 포맷

```markdown
# Garden Report — {date}

## Auto-fixed
- [GP-3] backend: 2 print() removed via ruff --fix

## Requires Human Review
- [GP-1] backend — Severity: Critical
  Verify: uv run pytest tests/structural/test_architecture.py
  Output: <pytest 출력 첫 30줄>
```

## 완료 기준 (DoD)

- `scripts/garden.sh` 실행 → GP Verify 명령 전체 실행
- 위반 감지 → auto-fix 시도 (Minor/backend) → GARDEN_REPORT.md 생성
- `gh pr create` 성공 → PR URL 출력
- `--dry-run` 플래그 시 커밋/PR 없이 감지 결과만 출력
- 위반 0건이면 "All principles satisfied. Nothing to do." 출력 후 exit 0
