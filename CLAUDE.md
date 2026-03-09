# DesktopMate+ Workspace Instructions

## Architecture

**Director-Artisan pattern** — 3 deployment components:

- **FastAPI** (`backend/`): Director — real-time WebSocket chat, STM/LTM, TTS, VLM, delegates heavy tasks to NanoClaw
- **NanoClaw** (`nanoclaw/`): Artisan — Node.js Claude agent runner; executes delegated tasks via container-based persona agents
- **Unity**: Dumb UI — renders output only, unaware of NanoClaw

Delegation flow: `PersonaAgent` → `DelegateTaskTool` → `POST /api/webhooks/fastapi` (NanoClaw) → `POST /v1/callback/nanoclaw/{session_id}` (FastAPI)

## CRITICAL: NanoClaw Changes via Skills Only

**Never modify NanoClaw source directly.** Use the skill-based workflow:

```bash
# 1. Create skill package
mkdir -p nanoclaw/.claude/skills/add-{feature}/{add,modify,tests}
# add SKILL.md + manifest.yaml

# 2. Apply
cd nanoclaw && npx tsx scripts/apply-skill.ts .claude/skills/add-{feature}

# 3. Test
npm test
```

Skill layout: `.claude/skills/{name}/add/` (new files), `modify/` (full replacements, 3-way merged), `tests/`. See [nanoclaw/docs/nanoclaw-architecture-final.md](nanoclaw/docs/nanoclaw-architecture-final.md).

## Build & Test

```bash
# Backend (Python 3.13 + uv)
cd backend
uv run pytest                # all tests
uv run pytest tests/path.py  # specific
sh scripts/lint.sh           # ruff lint + format check

# NanoClaw (Node.js + TypeScript)
cd nanoclaw
npm run build                # compile
npm test                     # vitest run
npm run dev                  # hot reload
```

## Backend Conventions

- **Package manager**: `uv` only — never `pip`
- **Config**: YAML files in `backend/yaml_files/`; Pydantic settings — no hardcoded values
- **Services**: One directory per service under `backend/src/services/`; register in `__init__.py` + `main.py` lifespan
- **Routes**: Add router to `backend/src/api/routes/__init__.py`; always include full `response_model`, `status_code`, `responses`
- **STM metadata**: Attach `user_id`/`agent_id` in metadata so callback endpoint can inject synthetic messages — see [`handlers.py`](backend/src/services/websocket_service/manager/handlers.py)
- **Logging**: Loguru via `src/core/logger`; never bare `print`
- **Type hints**: Strict, `|` union style (Python 3.10+)

## NanoClaw Conventions

- **Channels** self-register: import in [`src/channels/index.ts`](nanoclaw/src/channels/index.ts) triggers `registerChannel()`
- **Persona skills** live in `container/skills/{name}/SKILL.md`; skill-only (no code) for runtime agent instructions
- **IPC trigger**: write task file to `ipc/{group}/tasks/` to dispatch a NanoClaw task directly
- **Per-group config**: `groups/{name}/CLAUDE.md` (isolated memory context)

## PRD Tracking

Feature tasks tracked in [`docs/prds/feature/INDEX.md`](docs/prds/feature/INDEX.md) with Priority (P0/P1/P2) and Status (TODO/DONE/VERIFY).  
Current focus: Phase 2 — `nanoclaw/03` (Multi-Persona Execution) + `data_flow/01` (E2E Integration).

## Update documents

- Update `docs/prds/feature/INDEX.md` with new tasks, priorities, and statuses.
- Update `docs/backend/CLAUDE.md` with any new backend design decisions or conventions.
- Update this file with any new general instructions or architectural notes for the workspace.

## Appendix

- [backend Claude.md](./backend/CLAUDE.md): Current FastAPI backend design and conventions.
- [NanoClaw Claude.md](./nanoclaw/CLAUDE.md): NanoClaw setup and agent development guide.
- [Document Guide](./docs/guidelines/DOCUMENT_GUIDE.md): How to write and maintain design documents in this repository.
- [PRD Index](./docs/prds/feature/INDEX.md): Current PRD task list and status.
