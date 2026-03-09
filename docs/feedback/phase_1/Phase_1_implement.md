Phase 1 is complete. Here's what was done:

### Changes Summary

**P0 — Applied HTTP Channel Skill (NanoClaw)**
- Fixed YAML quote in manifest.yaml
- Applied skill → src/channels/http.ts, src/channels/http.test.ts, src/channels/index.ts now imports HTTP channel
- 16 tests pass

**P0 — Simplified DelegateTaskTool**
- Removed unused `nanoclaw_url`/`callback_url` constructor params in delegate_task.py
- Uses module-level constants directly; callback URL now includes `/{session_id}` for O(1) lookup

**P0 — Integrated DelegateTaskTool into PersonaAgent**
- handlers.py now instantiates `DelegateTaskTool(stm_service, session_id)` and passes it to `agent.stream(tools=[...])`

**P0 — Implemented Callback Endpoint**
- New callback.py: `POST /v1/callback/nanoclaw/{session_id}`
- New callback models: `NanoClawCallbackRequest`/`Response`
- Updates `pending_tasks` status in STM metadata
- Injects `[TaskResult:{task_id}]` or `[TaskFailed:{task_id}]` synthetic message into chat history
- Route registered in routes/__init__.py

**P0 — Tests**
- 6 unit tests: test_delegate_task.py — STM metadata, POST behavior, error handling
- 6 API tests: test_callback_api.py — 503/404/200/422, done/failed flows
- 3 E2E tests: test_delegation_e2e.py — full round-trip with mock NanoClaw server
- Fixed existing websocket test to work with `STMService` type validation

**P1 — Clarified Persona Skill structure**
- Updated task-01-persona-skills.md — SKILL.md-only is correct for runtime agent instructions (matches `agent-browser` pattern)
- Updated INDEX.md statuses to DONE

**Full test suite: 230 passed, 0 failed.**