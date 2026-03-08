# Task 02: Sub-Agent Driven Multi-Persona 실행 로직

**Parent**: §3 The Artisan Team (NanoClaw Swarm)
**Priority**: P0
**Depends on**: Task 01 (Persona Skills)

---

## Goal

Main Agent(Orchestrator)가 task를 분석하고, Claude Agent Teams(`TeamCreate`)로 Persona별 Sub-agent를 spawn하여 작업을 위임한 뒤 결과를 수집한다.

## 현재 인프라 상태

코드 변경 없이 사용 가능한 기존 인프라:

- `container-runner.ts`: settings.json에 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: '1'` 설정 완료
- `agent-runner/index.ts`: allowedTools에 `TeamCreate`, `TeamDelete`, `SendMessage` 포함
- `ipc-mcp-stdio.ts`: `send_message` MCP tool로 결과 전송 가능
- Container 내 Sub-agent는 Main Agent와 동일한 filesystem 및 MCP tools 공유

## Scope

### 실행 흐름

```text
Container (agent-runner)
  └── Main Agent (CLAUDE.md: orchestrator 지침)
       ├── TeamCreate(prompt: SKILL.md[DevAgent] + task context)
       │     └── Sub-agent: 작업 수행 → SendMessage로 결과 반환
       ├── TeamCreate(prompt: SKILL.md[ReviewerAgent] + 선행 결과)
       │     └── Sub-agent: 리뷰 → SendMessage로 결과 반환
       └── Main Agent가 결과 종합 → mcp__nanoclaw__send_message로 callback
```

### 구현 항목

1. **Orchestrator 지침 (CLAUDE.md)**
   - Container의 group CLAUDE.md에 orchestrator 역할 지침 추가
   - "task를 분석하고, 적절한 Persona를 TeamCreate로 spawn하라"
   - Persona 순서 결정 로직 (순차/병렬 판단 기준)

2. **Context 패키징 규칙**
   - Sub-agent spawn 시 prompt = SKILL.md 내용 + task context + 선행 결과물
   - 대용량 산출물은 파일시스템 경로로 전달 (context window 절약)
   - 소규모 판정/요약은 메시지로 직접 전달

3. **`sender` 필드 활용**
   - Sub-agent가 `mcp__nanoclaw__send_message` 호출 시 `sender` 필드에 Persona 이름 기입
   - Observer(§4)가 Persona별 미러링에 활용

### 단일 인스턴스 Persona 전환 대비 이점

- **Context window 효율**: 각 Sub-agent가 필요한 context만 수신
- **병렬 실행**: 독립적인 task는 동시에 실행 가능
- **실패 격리**: 한 Sub-agent 실패가 전체 파이프라인을 오염시키지 않음

## 제약 사항

- Agent Teams는 Claude Agent SDK 전용. 다른 런타임 지원은 [TODO/task-04-cross-runtime-subagent.md](../TODO/task-04-cross-runtime-subagent.md) 참조.

## Acceptance Criteria

- [ ] Orchestrator 지침이 group CLAUDE.md에 추가된다
- [ ] Main Agent가 task를 분석하여 `TeamCreate`로 Sub-agent를 spawn한다
- [ ] Sub-agent에게 Persona(SKILL.md)와 task context가 prompt로 전달된다
- [ ] Sub-agent 결과물이 Main Agent에 반환되어 다음 단계에 활용된다
- [ ] IPC 메시지의 `sender` 필드로 현재 Persona를 구분할 수 있다
- [ ] 최종 결과가 Egress를 통해 callback으로 전송된다
