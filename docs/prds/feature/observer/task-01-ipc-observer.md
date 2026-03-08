# Task 01: IPC Observer (add-ipc-observer Skill)

**Parent**: §4 The Observers & Bypasses
**Priority**: P2
**Depends on**: 없음 (완전 독립)

---

## Goal

NanoClaw 내부 IPC 흐름을 외부(Slack 등)로 미러링하는 독립 플러그인을 구현한다. Core 비즈니스 로직과 완전히 격리된다.

## Scope

### Staging Directory 패턴

1. Container의 `send_message`가 기록하는 경로를 `ipc/{group}/staging/`으로 변경
2. IPC watcher 루프 상단의 `promoteStagingFiles()` 함수가:
   - staging 파일을 읽어 Observer 채널(`IPC_OBSERVER_SLACK_JID`)로 mirror
   - `fs.renameSync`로 `messages/`로 atomic move (항상 실행)
3. Slack posting 실패 여부와 관계없이 promote는 항상 실행

### Skill Manifest

```yaml
skill: ipc-observer
version: 1.0.0
depends: []
modifies:
  - src/ipc.ts
  - container/agent-runner/src/ipc-mcp-stdio.ts
structured:
  env_additions:
    - IPC_OBSERVER_SLACK_JID
```

### Persona별 로깅

IPC 메시지의 `sender` 필드(ipc-mcp-stdio.ts에서 이미 지원)를 활용해 Persona별 로깅을 구분한다. 추가 Skill 의존 없이 Observer 단독으로 동작.

> **[TODO]** Slack Thread 분리 로깅: `sender` 필드 기반으로 Persona별 Slack Thread를 자동 생성/라우팅하는 로직. Observer 내부에서 처리 가능하며 외부 Skill 의존 불필요.

## 핵심 설계 원칙

- Observer는 core flow의 의존성이 아님 — 실패해도 메시지 전달에 영향 없음
- `renameSync`는 atomic이며 항상 실행됨

## Acceptance Criteria

- [ ] staging → messages 파일 이동이 atomic하게 동작한다
- [ ] Observer 채널로 IPC 메시지가 미러링된다
- [ ] Observer 실패 시에도 기존 IPC 흐름이 정상 동작한다
- [ ] `sender` 필드 기반 Persona별 로깅이 구분된다
