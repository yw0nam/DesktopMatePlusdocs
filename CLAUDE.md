# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Note, Use only english or korean for code and interaction, documentation. Avoid mixing languages in the same file or code block.

## DesktopMate+ Workspace Instructions

## Architecture

**Director-Artisan pattern** — 3 deployment components:

- **FastAPI** (`backend/`): Director — real-time WebSocket chat, STM/LTM, TTS, delegates heavy tasks to NanoClaw
- **NanoClaw** (`nanoclaw/`): Artisan — Node.js Claude agent runner; executes delegated tasks via container-based persona agents
- **desktop-homunculus** (`desktop-homunculus/`): Frontend (Dumb UI) — Bevy desktop mascot engine + MOD system. Renders output only, unaware of NanoClaw. MOD code lives here (e.g. `mods/desktopmate-bridge`). Has its own git.
- **DesktopMatePlus**: Only documentation and workspace-level instructions; no code. path:/home/spow12/codes/2025_lower/DesktopMatePlus

Note: NanoClaw, Backend, and desktop-homunculus each have their own git repo. Code changes go into their respective repos — do NOT commit code to DesktopMatePlus root. Workspace root has no `.github/workflows/` — automation uses `scripts/garden.sh` (drift detection + report generation), `scripts/e2e.sh` (cross-repo E2E verification wrapper), or `.pre-commit-config.yaml` only.

Delegation flow: `PersonaAgent` → `DelegateTaskTool` → `POST /api/webhooks/fastapi` (NanoClaw) → `POST /v1/callback/nanoclaw/{session_id}` (FastAPI)

## Backend Conventions

- **Package manager**: `uv` only — never `pip`
- **Config**: YAML files in `backend/yaml_files/`; Pydantic settings — no hardcoded values
- **Services**: One directory per service under `backend/src/services/`; register in `__init__.py` + `main.py` lifespan
- **Routes**: Add router to `backend/src/api/routes/__init__.py`; always include full `response_model`, `status_code`, `responses`
- **STM metadata**: Attach `user_id`/`agent_id` in metadata so callback endpoint can inject synthetic messages — see [`handlers.py`](backend/src/services/websocket_service/manager/handlers.py)
- **Logging**: Loguru via `src/core/logger`; never bare `print`
- **Type hints**: Strict, `|` union style (Python 3.10+)

## NanoClaw Conventions

- **Channels** self-register: import in [`src/channels/index.ts`](nanoclaw/src/channels/index.ts) triggers `registerChannel()`; channels are skills applied via `git merge`
- **Channel skills**: upstream 공식 채널(Telegram, Slack 등)은 별도 fork repo(`qwibitai/nanoclaw-{name}.git`)로 관리; 커스텀 채널은 `origin/skill/{name}` 브랜치로 관리
- **Persona skills** live in `container/skills/{name}/SKILL.md`; skill-only (no code) for runtime agent instructions
- **IPC trigger**: write task file to `ipc/{group}/tasks/` to dispatch a NanoClaw task directly
- **Per-group config**: `groups/{name}/CLAUDE.md` (isolated memory context)
- **Skill 적용 후 코드 복원**: 스킬을 `skill/{name}` 브랜치에 커밋한 뒤, `develop`/`main`에는 해당 소스를 두지 않는다. 설치 시에만 merge, 제거 시 원상복구. SKILL.md의 Removal 섹션을 따른다.
- **Working Branch**: 포크해온 레포임. 내가 사용하는 브랜치는 develop 브랜치임. develop 브랜치에서 작업한 뒤, skill/{name} 브랜치로 cherry-pick → PR → merge → develop에 반영되는 흐름.

## PRD Tracking

Feature tasks tracked in [`docs/superpowers/INDEX.md`](docs/superpowers/INDEX.md) with Priority (P0/P1/P2) and Status (TODO/DONE/VERIFY).

### docs/ 규칙 요약

- **본문 200줄 한도** — 초과 시 기능 단위로 분리, 인덱스 문서로 관리 ([전체 규칙](./docs/guidelines/DOCUMENT_GUIDE.md))
- **`docs/superpowers/`**: 활성 specs/plans + INDEX.md + completed/ 아카이브. 커밋 대상
- **`docs/feedback/`**: 읽기 전용, 수정 금지 (외부 피드백 원본 보존)

### FAQ 작성 규칙

작업 중 아래 상황이 발생하면 `docs/faq/` 에 문서를 추가하고 이 파일의 FAQ 섹션에 링크를 추가한다:

- 설계의 의도를 잘못 이해했다가 바로잡은 경우
- "왜 X 대신 Y를 쓰는가"에 대한 답을 찾은 경우
- 비슷해 보이는 두 개념의 차이를 명확히 한 경우
- 반복적으로 헷갈릴 수 있는 아키텍처 결정이 드러난 경우

파일명은 주제를 명확히 표현하는 kebab-case로 작성 (예: `nanoclaw-task-dispatch.md`).

## FAQ

자주 혼동되는 설계 결정들:

- [NanoClaw Task Dispatch — IPC vs HTTP Channel](./docs/faq/nanoclaw-task-dispatch.md): `ipc/{group}/tasks/`(내부 자기 디스패치)와 `add-http` 스킬(FastAPI → NanoClaw 위임 브리지)의 차이. 왜 HTTP Channel을 Redis Queue로 대체하지 않는가.
- [Desktop Homunculus MOD 시스템](./docs/faq/desktop-homunculus-mod-system.md): MOD 철학(pnpm 패키지 기반), Service/UI/Bin 진입점 구조, Glassmorphism UI 설정, signals 통신, preferences 저장 방법.
- [Upstream Fork CLAUDE.md 충돌 방지](./docs/faq/upstream-fork-claude-md.md): nanoclaw/desktop-homunculus 같은 fork repo에서 학습을 기록할 때 왜 CLAUDE.md가 아닌 `.claude/rules/team-local.md`를 쓰는가.
- **[NanoClaw Skill 작성 가이드](./docs/faq/nanoclaw-skill-writing-guide.md)**: NanoClaw 스킬을 작성할 때의 SKILL.md 구조, 커밋/PR 규칙. **Critical** — NanoClaw 소스 직접 수정 금지, 스킬은 Git 브랜치로 관리, SKILL.md 작성 패턴 엄수.
- **[FE Design Agent Workflow](./docs/faq/fe-design-agent-workflow.md)**: design-agent 스폰 조건, E2E scaffold vs unit test 경계, `design/{feature}` PR 흐름. FE feature 작업 전 필독.

## Agent Teams

Agent definitions: `.claude/agents/`. gstack skills drive all workflow logic — no custom workflow skills.

| Agent | Role | Persistence |
|-------|------|-------------|
| Lead Agent | Coordinator — spawn + Plans.md + delegation only | persistent |
| `pm-agent` | Feature spec/plan creation via `/office-hours` | on-demand |
| `design-agent` | FE mockup + component spec + E2E scaffold (desktop-homunculus/ only) | on-demand |
| `worker` | TDD implementation via `/harness-work` (per repo, worktree isolated) | on-demand |
| `reviewer` | Spec review (`/autoplan`) + code review (`/review` + `/cso`) | on-demand |
| `pr-merge-agent` | PR 리뷰 코멘트 분류(valid/false positive) → 답변 → 자동 머지 | on-demand |

Spawn condition for `design-agent`: PM spec에 `[target: desktop-homunculus/]` 명시 + 가시적 UI 변경 포함 시. 자세한 판별 기준은 [FE Design Agent Workflow FAQ](./docs/faq/fe-design-agent-workflow.md) 참조.

Flow:

```
User: feature request
  → Lead spawns pm-agent
  → PM: /office-hours → spec + Plans.md → cq.propose() → SPEC_READY
  → Reviewer: /autoplan → feedback (optional)
Lead: dispatch workers
  → (FE feature) Design Agent: /design-consultation → /design-shotgun → /design-html
      → component spec + E2E scaffold → design/{feature} branch PR → DESIGN_READY
  → Worker(s): per-repo implementation (FE worker uses design/{feature} as base branch)
  → Reviewer: /review + /cso → pass/fail
Lead: merge → /document-release
  → (PR에 리뷰 코멘트 있으면) pr-merge-agent: 분류 → 답변 → 머지
```

Task tracking: `Plans.md` with `cc:TODO` / `cc:DONE` markers.

### cq Knowledge Sharing — Mandatory

All team members use cq MCP for knowledge sharing. See `safety-guardrails.md` R00-CQ for details.

- **Before work**: `cq.query()` to check existing knowledge
- **After work**: `cq.propose()` to capture non-obvious learnings
- Autonomous — no user approval needed

### Worktree Rules

Workers create worktrees **inside the target sub-repo**: `git -C <repo>/ worktree add ...`
Do NOT use `isolation: "worktree"` from workspace root — it creates worktrees at the wrong level.

## gstack

Use the `/browse` skill from gstack for all web browsing. **Never use `mcp__claude-in-chrome__*` tools.**

Available gstack skills: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/agent-browser`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`

If gstack skills aren't working, run `cd .claude/skills/gstack && ./setup` to build the binary and register skills.

## Appendix

- [PRD Index](./docs/superpowers/INDEX.md): Current PRD task list and status.
- [FAQ](./docs/faq/): Frequently Asked Questions about architectural decisions and design patterns in this workspace.
- [NanoClaw Skills](./nanoclaw/.claude/skills/): Directory of existing NanoClaw skills with installation instructions.
- [Data Flows](./docs/data_flow/): Visual diagrams and explanations of key data flows between FastAPI, NanoClaw, and desktop-homunculus.
- [desktopmate-bridge CLAUDE.md](./desktop-homunculus/mods/desktopmate-bridge/CLAUDE.md): Mod-specific build/test commands, config flow, React gotchas.
- [Plans.md](./Plans.md): Cross-repo task tracking with `cc:TODO` / `cc:DONE` markers.
