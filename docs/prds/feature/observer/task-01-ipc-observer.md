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

### 선택적 연동

- `add-slack-swarm` 설치 시: `sender`/`thread_ts` 필드를 활용해 Persona별 Slack Thread 로깅
- `add-slack-swarm` 미설치 시: 단순 채널 메시지로 로깅

## 핵심 설계 원칙

- Observer는 core flow의 의존성이 아님 — 실패해도 메시지 전달에 영향 없음
- `renameSync`는 atomic이며 항상 실행됨

## Acceptance Criteria

- [ ] staging → messages 파일 이동이 atomic하게 동작한다
- [ ] Observer 채널로 IPC 메시지가 미러링된다
- [ ] Observer 실패 시에도 기존 IPC 흐름이 정상 동작한다
- [ ] `add-slack-swarm` 없이도 단독으로 동작한다
