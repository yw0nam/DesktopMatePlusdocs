# Safety Guardrails

Rules that ALL agents (Lead, developer, review-agent, quality-team) MUST follow.
Adapted from claude-code-harness R01-R13.

> **Priority**: These rules override other instructions. When in doubt, deny.

---

## Agent Dispatch Rules — MANDATORY

### R00-L: Lead Agent — 팀 위임 전용, sub-agent 자제

**Lead Agent는 구현/리뷰/조사 작업을 직접 수행하거나 sub-agent로 처리하지 않는다.**
모든 실질적 작업은 Agent Team에 위임한다. 유저가 명시적으로 요청하지 않는 한 `general-purpose` 또는 타입 미지정 Agent 스폰은 **전면 금지**.

| 작업 유형 | 위임 대상 (subagent_type) |
|-----------|--------------------------|
| 코드 구현 (backend/, nanoclaw/, desktop-homunculus/) | `worker` |
| 스펙/PRD 작성, office-hours | `pm-agent` |
| PR 리뷰, 코드 리뷰 | `reviewer` |
| FE UI 목업/컴포넌트 스펙 | `design-agent` |
| PR 머지 (리뷰 코멘트 처리) | `pr-merge-agent` |

Lead가 직접 해도 되는 것: Plans.md 업데이트, 팀 간 조율, 간단한 파일 확인(Read/Glob/Grep 1~2회).

**Lead가 하면 안 되는 것**:
- 코드를 읽고 분석하는 행위 (worker 또는 Explore agent에 위임)
- 구현 방향/설계 판단 (worker의 `/harness-work`가 처리)
- repo별 상세 컨텍스트 유지 (각 repo의 `.claude/rules/` 파일이 담당)

### R00-W: Worker / 팀원 — sub-agent 적극 활용 권장

`worker`, `pm-agent`, `reviewer`, `design-agent` 등 팀원은 자신의 작업 범위 내에서
`Explore`, `general-purpose` 등 sub-agent를 **적극 활용**하여 조사/병렬 처리를 수행한다.

**Worker 스폰 시 필수 조건**:
1. worktree는 **대상 sub-repo 내부**에서 생성 (e.g., `git -C backend/ worktree add ...`). `isolation: "worktree"` 사용 금지 — workspace root에 worktree가 생김.
2. 구현은 **반드시 `/harness-work` 스킬**로 진행 — 직접 코드 작성/Edit 금지

### R00-CQ: cq 지식 공유 — 필수

모든 팀원(worker, reviewer, pm-agent)은 cq MCP를 통해 지식을 공유한다.

**작업 시작 시** (worker, pm-agent):
```
cq.query(domain=["<repo>", "<task-domain>"])
```
기존 지식을 확인하고 작업에 반영한다.

**작업 완료 시** (worker, reviewer):
```
cq.propose(summary="...", detail="...", action="...", domain=["<repo>", "<area>"])
```
새로 발견한 비자명한 패턴, 함정, API 제약 등을 기록한다.
이미 알려진 사실이거나 배운 것이 없으면 스킵 가능.

**유저 승인 불필요** — cq 도구는 에이전트가 자율적으로 호출한다.

---

## DENY — Never allowed

### R01: No sudo

Never use `sudo` in any Bash command. If elevated privileges are needed, ask the user to run the command manually via `! <command>`.

### R02: No write to protected paths

Never write (Write/Edit) to these paths:
- `.git/` directories
- `.env` files (`.env`, `.env.local`, `.env.production`, etc.)
- SSH keys (`id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa`)
- Certificate/key files (`.pem`, `.key`, `.p12`, `.pfx`)
- `authorized_keys`, `known_hosts`

### R03: No Bash write to protected files

Never use shell redirects (`>`, `>>`, `tee`) targeting the protected paths listed in R02.

### R06: No force push

Never use `git push --force` or `git push -f`. No exceptions, even in worktrees.
`--force-with-lease` is also denied.

### R10: No hook/signing bypass

Never use `--no-verify` or `--no-gpg-sign` with git commands. Fix the underlying issue instead of bypassing hooks.

### R11: No reset --hard on protected branches

Never use `git reset --hard` targeting `main`, `master`, or `develop` (including `origin/main`, etc.).

---

## ASK — Confirm with user before proceeding

### R04: Write outside project

Before writing to any path outside the workspace root (`/home/spow12/codes/2025_lower/DesktopMatePlus/`) or its sub-repos (`backend/`, `nanoclaw/`, `desktop-homunculus/`), ask the user for confirmation.

Exception: writing to `.claude/agent_memory/` is always allowed.

### R05: rm -rf

Before running any `rm -rf` or `rm --recursive` command, ask the user for confirmation. Show the exact command.

Exception: removing worktree directories during cleanup (Phase 8) is allowed without asking.

---

## WARN — Proceed but flag to user

### R08: review-agent is read-only

The `review-agent` must NEVER use Write, Edit, or destructive Bash commands (`git commit`, `git push`, `rm`, `mv`). It can only Read, Grep, Glob, and run read-only Bash commands (`git diff`, `git log`, `cat`, etc.).

### R09: Secret file read

When reading files that may contain secrets (`.env`, SSH keys, `.pem`, `.key`, `secrets/` directories), log a warning. Never include secret values in reports or messages to other agents.

### R12: Direct push to protected branch

When `git push` targets `main`, `master`, or `develop` directly (not via PR), warn the user. Recommend feature branch + PR workflow instead.

### R13: Protected file changes

When modifying these files, flag to the user:
- `package.json`, `pyproject.toml`, `Cargo.toml` (dependency changes)
- `Dockerfile`, `docker-compose.yml`
- `.github/workflows/*` (CI/CD changes)
- Database schema files (`schema.prisma`, migration files)
- `CLAUDE.md`, `Plans.md` (workspace coordination files)

---

## Role-specific restrictions

| Agent | Write | Edit | Bash (write) | Bash (read) | Push |
|-------|-------|------|-------------|-------------|------|
| Lead Agent | Plans.md, docs, specs | Plans.md, docs, specs | Yes | Yes | No |
| worker | Assigned repo only | Assigned repo only | Yes (in worktree) | Yes | No |
| reviewer | Never | Never | Never | Yes | Never |

No agent may push to remote. Only the user pushes.
