# Task 01: HTTP Channel (add-fastapi-channel Skill)

**Parent**: §2 The Artisan Team (NanoClaw)
**Priority**: P0
**Depends on**: NanoClaw Channel Registry 패턴 이해

---

## Goal

NanoClaw에 HTTP 채널을 추가하여 FastAPI와의 비동기 위임 전용 입출력 단자를 구현한다. 기존 `add-slack` 채널과 동일한 self-registration 패턴을 따른다.

## Scope

### Ingress (수신)

- `POST /api/webhooks/fastapi` 엔드포인트
- 수신 payload: `{ task, task_id, session_id, callback_url, context }`
- `callback_url` 기반 synthetic JID 생성 (매핑 저장 방식 - base64 또는 in-memory map)
- 내용을 `groupQueue`에 push 후 `202 Accepted` 즉시 반환

### Egress (송신)

- Container 실행 완료 시 `sendMessage(jid, text)` 호출
- JID에서 `callback_url`을 복원하여 FastAPI Callback Endpoint로 POST
  - `{ task_id, status, summary }`
- `status === 'error'` 시 `status: "failed"` + 에러 메시지 포함
- Callback 전송 실패 시 retry 하지 않음 (FastAPI Background Sweep이 TTL로 처리)

### Skill Manifest

```yaml
skill: fastapi-channel
version: 1.0.0
depends: []
adds:
  - src/channels/http.ts
modifies:
  - src/channels/index.ts
structured:
  npm_dependencies: {}  # node:http 내장 모듈 사용, 외부 의존성 없음
  env_additions:
    - HTTP_PORT
    - FASTAPI_CALLBACK_URL
```

> **구현 노트**: POST 1개 + outbound fetch 1개이므로 `node:http` 내장 모듈로 충분하다. Fastify 등 외부 프레임워크는 불필요한 의존성.

## JID 설계 결정

**결정: Option A (stateless base64)**

`http:{base64(callback_url)}` — JID 자체에서 URL 복원 가능. 프로세스 재시작에도 유실 없음.

## Acceptance Criteria

- [ ] NanoClaw channel registry에 HTTP channel이 정상 등록된다
- [ ] FastAPI에서 보낸 task가 `groupQueue`에 들어간다
- [ ] Container 완료 후 callback_url로 결과가 POST된다
- [ ] Callback 실패 시 에러 로그만 남기고 진행한다 (retry 없음)
- [ ] 기존 Slack 채널과 독립적으로 동작한다
