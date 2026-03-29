# Contract Registry

This directory records confirmed cross-repo API contracts.

## Purpose

Contracts are accumulated here after `CONTRACT_REVIEW_REQUEST` / `APPROVED` cycles during Agent Teams sessions. Once recorded, teammates check this file before applying self-judgment — reducing detection misses.

## File Naming

`{consumer}-{provider}.md`

Examples:
- `nanoclaw-backend.md` — NanoClaw consumes Backend HTTP API
- `backend-dh.md` — Backend produces WebSocket events consumed by desktop-homunculus

## Entry Format

```markdown
## {HTTP METHOD} {path}  (or: WebSocket event `{name}` / IPC format `{name}`)
- description: what this contract covers
- payload: key fields and types (brief)
- confirmed: {YYYY-MM-DD}, approved-by: {team-name}
```

### Example

```markdown
## POST /api/webhooks/fastapi
- description: NanoClaw delegates a task result back to FastAPI
- payload: session_id (str, required), result (str, required), agent_id (str, optional)
- confirmed: 2026-03-29, approved-by: backend-team
```

## Graduation Path

As contracts accumulate, teammates use this file to detect violations automatically (no self-judgment needed for known contracts). New contracts still go through self-judgment in `teammate-workflow`.

This directory is checked by `scripts/check_docs.sh` for dead links and freshness.
