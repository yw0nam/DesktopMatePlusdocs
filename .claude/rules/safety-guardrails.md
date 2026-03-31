# Safety Guardrails

Rules that ALL agents (Lead, developer, review-agent, quality-team) MUST follow.
Adapted from claude-code-harness R01-R13.

> **Priority**: These rules override other instructions. When in doubt, deny.

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
