# Phase Dispatch

새 Phase 시작 시 Lead 표준 절차.

## 순서

1. **Plans.md 확인** — cc:TODO 태스크 목록 확인
2. **TeamCreate** — `team_name`: `phase-{N}`
3. **TaskCreate** — 각 태스크별로 생성 (레포별로 묶기)
4. **TaskUpdate** — 각 태스크에 owner 지정
5. **Agent 스폰** — `team_name` 포함, `subagent_type: worker`

## 레포별 Worker 분리 기준

| 대상 | Worker | 비고 |
|------|--------|------|
| backend/ | worker-be | FastAPI/Python |
| nanoclaw/ | worker-nc | skill-as-branch only |
| desktop-homunculus/ | worker-dh | Rust/Bevy + TS MOD |
| DesktopMatePlus/ (docs) | worker-ws | docs/config only |

같은 레포 연속 태스크 → SendMessage 재활용 (새 스폰 금지).
재스폰 기준: total_tokens ≥ 80k / tool_uses ≥ 60 / 레포 변경.

## Branch 네이밍

`{prefix}/p{N}-t{id}`

prefix ∈ `{feat, fix, docs, refactor, chore, test, ci, build}`

예: `feat/p23-t1`, `fix/p22-tqa12`, `docs/p21-twf`

## Worker Worktree

- Sub-repo: `git -C <repo>/ worktree add worktrees/{prefix}-p{N}-t{id} {prefix}/p{N}-t{id}`
- Workspace root: `git worktree add ../DesktopMatePlus-{slug} {branch}`

## /simplify 게이트

코드 변경 태스크: 구현 완료 → /simplify → /ship
docs-only 태스크: /simplify 생략 → /ship
