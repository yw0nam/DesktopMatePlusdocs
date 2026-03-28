---
name: planning-workflow
description: Use when starting any new feature, initiative, or cross-repo task planning in DesktopMatePlus — chains brainstorming → plan → review → Agent Teams execution → release → memory
---

# Planning Workflow

## Overview

Full 9-phase workflow for DesktopMatePlus cross-repo features.
**Never skip phases. Each phase depends on the previous output.**

```
[Feature request / idea]
        ↓
Phase 1: superpowers:brainstorming
        ↓
[Brainstorm output = spec.md]
        ↓
Phase 2: claude-code-harness:harness-plan (spec.md as input)
        ↓
[Structured tasks in Plans.md with [target:] markers]
        ↓
Phase 3: claude-code-harness:harness-review (spec.md as input)
        ↓
[Review feedback → iterate Phase 2 until approved]
        ↓
Phase 4: Distribute TODOs to sub-repos
        ↓
[Each repo team has their scoped tasks]
        ↓
Phase 5: Worktree Setup — create feature branch per repo
        ↓
[Each affected repo has an isolated worktree]
        ↓
Phase 6: Agent Teams execution in each repo (inside worktrees)
        ↓
[/harness-work breezing --no-discuss all → report back to Lead Agent]
        ↓
Phase 7: Review and integration
        ↓
[Lead Agent reviews → delegates /harness-release per repo team]
        ↓
Phase 8: Commit and merge worktree
        ↓
[Commit in worktree → merge to working branch → remove worktree]
        ↓
Phase 9: Complete and save memory
        ↓
[Mark cc:DONE, save memories useful for similar future tasks]
```

---

## Phase 1 — Brainstorm

**Before brainstorming**, query cq for known pitfalls in the relevant domain:

```
mcp: cq.query(domain=["nanoclaw", "testing"])   ← adjust to feature domain
```

If results appear, review them before writing the spec — prior incidents inform constraints.

Invoke `superpowers:brainstorming` with the feature description.

Output must include:
- User intent and goals
- Constraints and edge cases
- Component breakdown (which repos are affected)
- Open questions resolved

**Do not proceed to Phase 2 until brainstorm output is written.**

---

## Phase 2 — Plan

Pass the brainstorm output as spec to `claude-code-harness:harness-plan`.

The plan must produce tasks in `Plans.md` with:
- `<!-- cc:TODO -->` markers
- `[target: repo/]` annotation on each task
- Phase grouping if tasks span multiple milestones
- Clear acceptance criteria per task

**Do not write vague tasks.** Each task must be actionable by a specific team.

---

## Phase 3 — Review

Invoke `claude-code-harness:harness-review` with the spec.md as input.

- If feedback → revise tasks in Plans.md, re-review
- Loop Phase 2 ↔ Phase 3 until reviewer approves
- **Do not proceed to Phase 4 without approval**

---

## Phase 4 — Distribute

For each approved `cc:TODO` task, annotate in Plans.md and mirror to each sub-repo's Plans.md:

| Target | Plans.md annotation | Sub-repo Plans.md |
|--------|--------------------|--------------------|
| `backend/` | `[target: backend/]` | `backend/Plans.md` |
| `nanoclaw/` | `[target: nanoclaw/]` | `nanoclaw/Plans.md` |
| `desktop-homunculus/` | `[target: desktop-homunculus/]` | `desktop-homunculus/Plans.md` |
| `workspace scripts/` | `[target: workspace scripts/]` | Plans.md only |

Only distribute to repos that have assigned tasks for this session.

After mirroring, **commit Plans.md in each affected sub-repo immediately**:

```bash
cd nanoclaw/  && git add Plans.md && git commit -m "docs(plans): add <feature> tasks cc:TODO"
cd backend/   && git add Plans.md && git commit -m "docs(plans): add <feature> tasks cc:TODO"
# workspace root Plans.md is committed in Phase 9
```

---

## Phase 5 — Worktree Setup

For each affected repo, **navigate to the repo directory** and create an isolated worktree before any code is written.

Branch naming convention: `feat/{feature-slug}` (e.g., `feat/structural-tests`)

```bash
# Example for nanoclaw/
cd nanoclaw/
git worktree add ../worktrees/nanoclaw-feat-structural-tests feat/structural-tests
# (creates branch automatically if it doesn't exist)
```

| Repo | Working branch | Worktree path |
|------|---------------|---------------|
| `backend/` | `main` | `../worktrees/backend-{slug}` |
| `nanoclaw/` | `develop` | `../worktrees/nanoclaw-{slug}` |
| `desktop-homunculus/` | `main` | `../worktrees/dh-{slug}` |

Teammates work **inside the worktree path**, not in the original repo directory.

**Do not skip this phase.** Working directly on the working branch loses isolation and makes rollback harder.

---

## Phase 6 — Agent Teams Execution

Spawn Agent Team (requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`).

**Teammate prompt template** — keep it lean. Do NOT include implementation instructions:

```
You are the {repo} teammate.

1. Read /home/.../{repo}/CLAUDE.md (the original repo, not the worktree)
2. Load your workflow skill: /teammate-workflow
3. Your worktree: worktrees/{repo}-{slug}/
4. Run: /harness-work breezing --no-discuss all
5. Report back when done: tasks completed, files changed, test results, blockers
```

**Critical rules for writing teammate prompts:**
- NEVER include step-by-step implementation instructions — that defeats harness-work
- NEVER specify which files to create or what code to write
- The prompt should only specify: repo path, worktree path, and "run harness-work"
- harness-work reads Plans.md and executes tasks autonomously

Each teammate is a full independent Claude Code session.
Use `Shift+Down` to cycle teammates, click pane to message directly.

---

## Phase 7 — Review and Integration

Lead Agent reviews each teammate's report:
- Verify acceptance criteria met
- Check for cross-repo integration issues
- If issues found: message the relevant teammate directly with fix instructions

Once approved, delegate release prep:

```
Ask each teammate to run /harness-release to prepare:
- Release notes
- Changelog entry
- Version bump (if applicable)
```

Coordinate release activities across repos from Leader position.

---

## Phase 8 — Commit and Merge Worktree

For each affected repo **in dependency order** (sub-repos first, workspace last):

```bash
# 1. Commit inside the worktree
cd worktrees/nanoclaw-{slug}/
git add <relevant files>   # never git add . — avoid untracked junk
git commit -m "feat: ..."

# 2. Merge back to working branch
cd nanoclaw/
git merge feat/{slug} --no-ff

# 3. Remove worktree
# Note: harness-work creates .claude/state/ files inside worktrees — always use --force
git worktree remove --force ../worktrees/nanoclaw-{slug}
git branch -d feat/{slug}   # only after successful merge
```

```
# Merge order: nanoclaw/ → backend/ → desktop-homunculus/ → DesktopMatePlus (Plans.md)
```

**Do not push** unless user explicitly requests it.

---

## Phase 9 — Complete and Save Memory

1. Update Plans.md: change `cc:TODO` → `cc:DONE` for all completed tasks
2. **Commit Plans.md in every affected repo** — Plans.md updates are code changes; they must be committed.

```bash
# Sub-repos first (each in their own git repo)
cd nanoclaw/   && git add Plans.md && git commit -m "docs(plans): mark <tasks> as DONE"
cd backend/    && git add Plans.md && git commit -m "docs(plans): mark <tasks> as DONE"

# Workspace root last
cd DesktopMatePlus/  && git add Plans.md && git commit -m "docs(plans): mark <tasks> as DONE"
```

3. Clean up Agent Team: ask leader to `Clean up the team`
4. Run `/cq:reflect` — mines the session for knowledge units worth sharing:
   - Pitfalls encountered and how they were resolved
   - Patterns that worked well and should be repeated
   - Cross-repo coordination decisions
5. For each approved candidate, call `mcp: cq.propose(...)` to save to the knowledge store
6. Save auto-memory (user/feedback/project types per memory system rules)

---

## Red Flags — Skip No Phases

| Shortcut | Why Wrong |
|----------|-----------|
| "Idea is clear, skip brainstorm" | Unresolved constraints surface late. Always brainstorm. |
| "I'll add tasks to Plans.md directly" | Without spec, tasks lack acceptance criteria. |
| "Skip review, plan looks good" | Review catches scope creep and missing DoD. |
| "I'll distribute later" | TODOs without dispatch never get executed. |
| "Just run it without Agent Teams" | Single-agent execution loses parallelism and repo isolation. |
| "Skip worktree, work directly on branch" | No isolation — rollback requires reverting commits, not just removing a worktree. |

---

## Quick Reference

```
0. cq.query(domain=[...])                        ← check known pitfalls first
1. Skill: superpowers:brainstorming
2. Skill: claude-code-harness:harness-plan   ← brainstorm output as spec
3. Skill: claude-code-harness:harness-review  ← iterate until approved
4. Mirror tasks to sub-repo Plans.md + commit Plans.md in each sub-repo
5. Create worktrees: cd {repo}/ && git worktree add ../worktrees/{repo}-{slug} feat/{slug}
6. Spawn Agent Team → work inside worktrees → /harness-work breezing --no-discuss all
7. Review reports → /harness-release per repo
8. Commit in worktree → merge to working branch → remove worktree
9. cc:DONE + /cq:reflect → cq.propose(...) + save memory
```

---

## cq — Shared Knowledge Commons

cq는 에이전트 간 학습을 공유하는 지식 저장소입니다. 작업 전 pitfall 조회, 작업 후 학습 저장을 통해 반복 실수를 방지합니다.

### 도구 6개

| 도구 | 용도 | 언제 |
|------|------|------|
| `cq.query(domain=[...])` | 도메인 태그로 KU 검색 | **Phase 1 전** — 관련 pitfall 확인 |
| `cq.propose(...)` | 새 Knowledge Unit 저장 | **Phase 9** — 학습 저장 |
| `/cq:reflect` | 세션 컨텍스트 마이닝 → 저장 후보 도출 | **Phase 9** — propose 전 |
| `cq.confirm(id)` | KU 적중 시 confidence ↑ | KU가 실제로 도움됐을 때 |
| `cq.flag(id, reason)` | KU 오류 시 confidence ↓ | stale / incorrect / duplicate |
| `/cq:status` | 저장소 통계 확인 | 언제든지 |

### propose 예시

```python
cq.propose(
  summary="nanoclaw 구조적 테스트에서 console.log 확인 시 .test.ts 제외 필수",
  detail="CONSOLE_PATTERN으로 src/**/*.ts 스캔 시 test 파일 포함되면 false positive 발생",
  action="glob 패턴에서 *.test.ts, *.d.ts 를 명시적으로 제외할 것",
  domain=["nanoclaw", "testing", "typescript"],
  language="typescript",
)
```

### domain 태그 관례

- 컴포넌트: `nanoclaw`, `backend`, `desktop-homunculus`
- 레이어: `testing`, `architecture`, `workflow`, `git`
- 언어: `typescript`, `python`, `rust`
- 주제: `agent-teams`, `worktree`, `structural-tests`

### cq vs auto-memory 차이

| | cq | auto-memory |
|--|---|---|
| 범위 | 에이전트 팀 공유 가능 (team API 설정 시) | 이 프로젝트 세션 전용 |
| 내용 | pitfall, 패턴, 해결책 (actionable) | 사용자 프로필, 피드백, 프로젝트 컨텍스트 |
| 신뢰도 | confirm/flag로 관리 | 수동 관리 |
| 형식 | summary + detail + action + domain | 자유 마크다운 |
