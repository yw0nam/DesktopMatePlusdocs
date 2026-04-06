# Phase Dispatch

새 Phase 시작 시 Lead 표준 절차.

## 순서

1. **Plans.md 확인** — cc:TODO 태스크 목록 확인
2. **TeamCreate** — `team_name`: `phase-{N}`
3. **TaskCreate** — 각 태스크별로 생성 (레포별로 묶기)
4. **Worker Sub-Team 스폰** — 레포별로 3명씩 동시 스폰:
   ```
   Agent(name: "wl-{repo}", subagent_type: worker-lead, team_name: "phase-{N}")
   Agent(name: "coder-{repo}", subagent_type: worker-coder, team_name: "phase-{N}")
   Agent(name: "reviewer-{repo}", subagent_type: worker-reviewer, team_name: "phase-{N}")
   ```
5. **TaskUpdate** — 태스크 owner를 Worker Lead 이름으로 지정
6. **Worker Lead에게 지시** — SendMessage로 태스크 목록 + worktree 경로 + Coder/Reviewer 이름 전달

> **NOTE**: Teammate는 다른 teammate를 스폰할 수 없음 (flat roster). Main Lead가 3명 모두 스폰.

## 레포별 Worker Sub-Team

| 대상 | Worker Lead | Coder | Reviewer | 비고 |
|------|-------------|-------|----------|------|
| backend/ | wl-be | coder-be | reviewer-be | FastAPI/Python |
| nanoclaw/ | wl-nc | coder-nc | reviewer-nc | skill-as-branch only |
| desktop-homunculus/ | wl-dh | coder-dh | reviewer-dh | Rust/Bevy + TS MOD |
| DesktopMatePlus/ (docs) | wl-ws | coder-ws | reviewer-ws | docs/config only |

같은 레포 연속 태스크 → Worker Lead에 SendMessage 재활용 (새 스폰 금지).
재스폰 기준: total_tokens ≥ 80k / tool_uses ≥ 60 / 레포 변경.

## Branch 네이밍

`{prefix}/p{N}-t{id}`

prefix ∈ `{feat, fix, docs, refactor, chore, test, ci, build}`

예: `feat/p23-t1`, `fix/p22-tqa12`, `docs/p21-twf`

## Worker Lead Worktree

Worker Lead가 worktree를 직접 생성:
- Sub-repo: `git -C <repo>/ worktree add worktrees/{prefix}-p{N}-t{id} {prefix}/p{N}-t{id}`
- Workspace root: `git worktree add ../DesktopMatePlus-{slug} {branch}`

## Worker Lead 자율 운영

3명 스폰 후 Main Lead는 대기만:
1. Worker Lead가 Coder에게 태스크 할당 → 구현 → Reviewer 리뷰 사이클 자율 진행
2. Reviewer PASS → Worker Lead가 /simplify → /ship → PR 생성
3. Worker Lead가 Main Lead에게 최종 보고 (PR URL, test results)
4. Main Lead는 내부 iteration에 개입하지 않음 (escalation 시에만)
