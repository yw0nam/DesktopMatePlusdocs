# Task 04: Cross-Runtime Sub-Agent Delegation

**Parent**: §3 The Artisan Team (NanoClaw Swarm)
**Priority**: P2
**Depends on**: nanoclaw_swarm/02 (Sub-Agent Driven Multi-Persona)
**Status**: HOLD

---

## Goal

Claude Agent SDK의 Agent Teams(`TeamCreate`)에 의존하지 않고, Gemini CLI, OpenCode 등 모든 런타임에서 동일하게 동작하는 Sub-agent delegation method를 구현한다.

## Background

nanoclaw_swarm/02는 Claude의 `TeamCreate`를 사용하여 Sub-agent를 spawn한다. 이는 Claude 전용 기능이므로, 다른 런타임에서는 동작하지 않는다.

## 추천 방향: MCP `spawn_sub_agent` Tool

MCP는 runtime-agnostic 프로토콜이므로, 새 MCP tool로 Sub-agent spawning을 추상화한다.

```
ipc-mcp-stdio.ts
  └── spawn_sub_agent tool
       ├── Input: { persona: "DevAgent", prompt: "...", runtime?: "gemini" }
       ├── Host가 container-runner로 새 container spawn
       └── 결과를 IPC로 원래 container에 반환
```

### 변경 대상

- `container/agent-runner/src/ipc-mcp-stdio.ts`: `spawn_sub_agent` tool 추가
- `src/ipc.ts`: sub-agent spawn 요청 감지 및 처리
- `src/container-runner.ts`: sub-agent container spawn 로직

### IPC 파일 방식 대비 이점

- Tool 레벨에서 동기/비동기 결과 대기 제어 가능
- 인터페이스가 명확 (input schema, output schema)
- 모든 런타임이 MCP tool 호출 가능

## Acceptance Criteria

- [ ] MCP tool `spawn_sub_agent`가 구현된다
- [ ] Claude, Gemini CLI, OpenCode에서 동일한 tool 호출로 Sub-agent spawn 가능
- [ ] Sub-agent 결과가 호출한 Main Agent에 반환된다
- [ ] 기존 Agent Teams 방식(nanoclaw_swarm/02)과 공존 가능
