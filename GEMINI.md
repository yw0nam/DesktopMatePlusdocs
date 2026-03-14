# DesktopMate+ Workspace Instructions

## Architecture

**Director-Artisan pattern** — 3 deployment components:

- **FastAPI** (`backend/`): Director — real-time WebSocket chat, STM/LTM, TTS, VLM, delegates heavy tasks to NanoClaw
- **NanoClaw** (`nanoclaw/`): Artisan — Node.js Claude agent runner; executes delegated tasks via container-based persona agents
- **Unity**: Dumb UI — renders output only, unaware of NanoClaw
- **DesktopMatePlus**: Only documentation and workspace-level instructions; no code. You have to make a worktree or code change in backend or nanoclaw only. path:/home/spow12/codes/2025_lower/DesktopMatePlus

Note: NanoClaw and Backend has own their git.

Delegation flow: `PersonaAgent` → `DelegateTaskTool` → `POST /api/webhooks/fastapi` (NanoClaw) → `POST /v1/callback/nanoclaw/{session_id}` (FastAPI)

## Skill 설계 원칙

NanoClaw 스킬은 **Git 브랜치 기반**으로 관리된다. 스킬을 적용한다는 것은 해당 스킬 브랜치를 현재 브랜치에 `git merge`하는 것이다.

```
skill 브랜치 작성 (main 기반, 스킬 코드만 포함)
  → git merge origin/skill/{name} 적용
    → npm run build && npm test 실행 (검증)
```

- **업스트림 공식 스킬**: `git remote add {name} https://github.com/qwibitai/nanoclaw-{name}.git` 후 `git fetch {name} main && git merge {name}/main`
- **커스텀 스킬** (이 repo): `git fetch origin skill/{name} && git merge origin/skill/{name}`
- 소스를 직접 수정하지 말 것 — 다음 merge 시 충돌 발생

## CRITICAL: NanoClaw Changes via Skills Only

**Never modify NanoClaw source directly.** Use the skill-based workflow:

```bash
# 1. Create skill branch from main (custom skill)
git checkout -b skill/{name} main
# Add only the skill's source files, commit
git push origin skill/{name}

# 2. Write SKILL.md in .claude/skills/{name}/SKILL.md
#    Phase 1: pre-flight check
#    Phase 2: git fetch + merge
#    Phase 3: env/setup
#    Phase 4: verify

# 3. Apply (from target branch e.g. develop)
git fetch origin skill/{name}
git merge origin/skill/{name}

# 4. Test
npm run build && npm test
```

Skill SKILL.md 구조: Phase 1~4 단계별 가이드. `add/`, `modify/`, `manifest.yaml`은 구 방식 — 사용하지 않는다.

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

# Real E2E (requires both services running)
# 1. Backend: uvicorn src.main:app --port 5500  (in backend/)
# 2. NanoClaw: HTTP_PORT=4000 node dist/index.js  (in nanoclaw/, after npm run build)
# 3. Run tests:
cd backend
NANOCLAW_HTTP_PORT=4000 uv run pytest tests/api/test_real_e2e.py -v
# Note: NanoClaw credential proxy uses 3001; HTTP channel must use a different port (e.g. 4000)
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

- **Channels** self-register: import in [`src/channels/index.ts`](nanoclaw/src/channels/index.ts) triggers `registerChannel()`; channels are skills applied via `git merge`
- **Channel skills**: upstream 공식 채널(Telegram, Slack 등)은 별도 fork repo(`qwibitai/nanoclaw-{name}.git`)로 관리; 커스텀 채널은 `origin/skill/{name}` 브랜치로 관리
- **Persona skills** live in `container/skills/{name}/SKILL.md`; skill-only (no code) for runtime agent instructions
- **IPC trigger**: write task file to `ipc/{group}/tasks/` to dispatch a NanoClaw task directly
- **Per-group config**: `groups/{name}/CLAUDE.md` (isolated memory context)
- **Skill 적용 후 코드 복원**: 스킬을 `skill/{name}` 브랜치에 커밋한 뒤, `develop`/`main`에는 해당 소스를 두지 않는다. 설치 시에만 merge, 제거 시 원상복구. SKILL.md의 Removal 섹션을 따른다.

## PRD Tracking

Feature tasks tracked in [`docs/prds/feature/INDEX.md`](docs/prds/feature/INDEX.md) with Priority (P0/P1/P2) and Status (TODO/DONE/VERIFY).
Current focus: Phase 2 완료 + Real E2E 검증 완료. 다음은 P2 HOLD 항목 중 필요한 것을 선택적으로 구현.

## Update documents

- Update `docs/prds/feature/INDEX.md` with new tasks, priorities, and statuses.
- Update `docs/backend/CLAUDE.md` with any new backend design decisions or conventions.
- Update this file with any new general instructions or architectural notes for the workspace.

## Appendix

- [backend Claude.md](./backend/CLAUDE.md): Current FastAPI backend design and conventions.
- [backend Documents](./backend/docs/): Design documents for backend services and features.
- [NanoClaw Claude.md](./nanoclaw/CLAUDE.md): NanoClaw setup and agent development guide.
- [Document Guide](./docs/guidelines/DOCUMENT_GUIDE.md): How to write and maintain design documents in this repository.
- [PRD Index](./docs/prds/feature/INDEX.md): Current PRD task list and status.
