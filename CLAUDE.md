# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Note: Use only english or korean for code and interaction, documentation. Avoid mixing languages in the same file or code block.

## Architecture

**Director-Artisan pattern** — 3 deployment components:

- **FastAPI** (`backend/`): Director — real-time WebSocket chat, STM/LTM, TTS, delegates heavy tasks to NanoClaw
- **NanoClaw** (`nanoclaw/`): Artisan — Node.js Claude agent runner; executes delegated tasks via container-based persona agents
- **desktop-homunculus** (`desktop-homunculus/`): Frontend (Dumb UI) — Bevy desktop mascot engine + MOD system. Renders output only, unaware of NanoClaw. MOD code lives here (e.g. `mods/desktopmate-bridge`). Has its own git.
- **DesktopMatePlus**: Documentation and workspace-level instructions only; no code.

**Cross-repo rule**: NanoClaw, Backend, desktop-homunculus each have their own git repo — do NOT commit code to DesktopMatePlus root.

**Delegation flow**: `DelegateTaskTool` → `POST /api/webhooks/fastapi` (NanoClaw) → async execution → `POST /v1/callback/nanoclaw/{session_id}` (FastAPI) → result injected into LangGraph state

See sub-repo CLAUDE.md files for per-repo conventions: [`backend/CLAUDE.md`](backend/CLAUDE.md), [`nanoclaw/CLAUDE.md`](nanoclaw/CLAUDE.md), [`desktop-homunculus/CLAUDE.md`](desktop-homunculus/CLAUDE.md).

## PRD Tracking

Flow: PM(`/office-hours`) → `docs/TODO.md` (spec + priority table) → Lead → `Plans.md` (cc:TODO / cc:DONE) → Worker

### docs/ 규칙 요약

- **본문 200줄 한도** — 초과 시 기능 단위로 분리, 인덱스 문서로 관리 ([전체 규칙](./docs/guidelines/DOCUMENT_GUIDE.md))
- **`docs/TODO.md`**: PM agent가 작성하는 활성 스펙 목록. Priority (P0/P1/P2) + Status (TODO/DONE) 테이블 형식
- **`docs/feedback/`**: 읽기 전용, 수정 금지 (외부 피드백 원본 보존)

### FAQ 작성 규칙

작업 중 아래 상황이 발생하면 `docs/faq/`에 문서를 추가하고 이 파일의 FAQ 섹션에 링크를 추가한다:

- 설계의 의도를 잘못 이해했다가 바로잡은 경우
- "왜 X 대신 Y를 쓰는가"에 대한 답을 찾은 경우
- 비슷해 보이는 두 개념의 차이를 명확히 한 경우
- 반복적으로 헷갈릴 수 있는 아키텍처 결정이 드러난 경우

## FAQ

- [NanoClaw Task Dispatch — IPC vs HTTP Channel](./docs/faq/nanoclaw-task-dispatch.md): `ipc/{group}/tasks/`(내부 자기 디스패치)와 `add-http` 스킬(FastAPI → NanoClaw 위임 브리지)의 차이.
- [Desktop Homunculus MOD 시스템](./docs/faq/desktop-homunculus-mod-system.md): MOD 철학, Service/UI/Bin 진입점, Glassmorphism UI, signals 통신, preferences 저장.
- [Upstream Fork CLAUDE.md 충돌 방지](./docs/faq/upstream-fork-claude-md.md): fork repo에서 학습 기록 시 `.claude/rules/team-local.md`를 쓰는 이유.
- **[NanoClaw Skill 작성 가이드](./docs/faq/nanoclaw-skill-writing-guide.md)**: SKILL.md 구조, 커밋/PR 규칙. Critical — NanoClaw 소스 직접 수정 금지.
- **[FE Design Agent Workflow](./docs/faq/fe-design-agent-workflow.md)**: design-agent 스폰 조건, E2E scaffold vs unit test 경계, `design/{feature}` PR 흐름.

## Agent Teams

Agent definitions: `.claude/agents/`. gstack skills drive all workflow logic.

| Agent | Role | Persistence |
|-------|------|-------------|
| Lead Agent | Coordinator — spawn + Plans.md + delegation only | persistent |
| `pm-agent` | Feature spec/plan creation via `/office-hours` | on-demand |
| `design-agent` | FE mockup + component spec + E2E scaffold (desktop-homunculus/ only) | on-demand |
| `worker` | TDD implementation via `/harness-work` (per repo, worktree isolated) | on-demand, reuse preferred |
| `reviewer` | Spec review (`/autoplan`) + code review (`/review` + `/cso`) | on-demand |
| `pr-merge-agent` | PR 리뷰 코멘트 분류 → 답변 → 자동 머지 | 수동 긴급용 (/babysit cron이 normal flow) |
| `quality-agent` | 주기적 품질 모니터링 — garden.sh + check_docs.sh + QUALITY_SCORE.md 갱신 | on-demand |

**Worker 재활용**: 같은 레포 연속 태스크 → `SendMessage`로 기존 worker 재사용. 새 스폰 기준: `total_tokens` ≥ 80k / `tool_uses` ≥ 60 / 레포 변경.

**스킬 책임 분리**: `/ship` · `/simplify` → worker/design-agent. `/document-release` → babysit cron. Lead는 직접 실행하지 않는다.

**Flow**: PM spec → Reviewer(`/autoplan`) → Worker(구현 → `/simplify` → `/ship`) → Reviewer(`/review` + `/cso`) → babysit cron(PR 머지 → `/document-release`)

### Worktree Rules

**모든 구현 작업은 feature 브랜치 + worktree에서 진행한다. workspace root 포함.**

- Sub-repo: `git -C <repo>/ worktree add worktrees/feat-<slug> feat/<slug>`
- Workspace root: `git worktree add ../DesktopMatePlus-feat-<slug> feat/<slug>`
- Do NOT use `isolation: "worktree"` from workspace root.
- Do NOT commit directly to `master`/`main`/`develop`.

**Branch prefix**: `{feat|fix|docs|refactor|chore|test}/p{N}-t{id}` (e.g. `feat/p21-t1`)

## gstack

Use `/browse` for all web browsing. **Never use `mcp__claude-in-chrome__*` tools.**

If gstack skills aren't working: `cd .claude/skills/gstack && ./setup`

## Appendix

- [Feature TODO](./docs/TODO.md): Active feature specs and priority list.
- [Data Flows](./docs/data_flow/): Mermaid diagrams — chat, channel, agent (LTM, DelegateTask), desktopmate-bridge.
- [FAQ](./docs/faq/): Architectural decisions Q&A.
- [Plans.md](./Plans.md): Cross-repo task tracking (cc:TODO / cc:DONE).
- [Scripts Reference](./docs/scripts-reference.md): garden.sh / e2e.sh / check_docs.sh / run-quality-agent.sh 등.
- [/babysit](./.claude/commands/babysit.md) · [/cleanup](./.claude/commands/cleanup.md) · [/phase-dispatch](./.claude/commands/phase-dispatch.md) · [/post-merge-sweeper](./.claude/commands/post-merge-sweeper.md) · [/pr-pruner](./.claude/commands/pr-pruner.md): Workflow command references.
