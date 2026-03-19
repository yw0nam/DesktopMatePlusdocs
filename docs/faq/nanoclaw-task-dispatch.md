# FAQ: NanoClaw Task Dispatch — IPC vs HTTP Channel

## Q. IPC(`ipc/{group}/tasks/`)와 HTTP Channel(`add-http` 스킬)은 같은 건가?

**아니다. 목적과 방향이 완전히 다르다.**

---

## IPC File Trigger

**역할**: NanoClaw → NanoClaw 자체 내부 태스크 디스패치

**사용 주체**: NanoClaw 자신, 또는 같은 호스트에서 파일을 직접 쓸 수 있는 프로세스

**동작 방식**:
```
파일 생성 → ipc/{group}/tasks/{task_id}.json
              ↓
         NanoClaw ipc watcher 감지
              ↓
         해당 group의 agent 실행
```

**주요 사용처**:
- 스케줄된 태스크 (`task-scheduler.ts`)
- 외부 스크립트가 NanoClaw agent를 직접 트리거할 때
- NanoClaw 내부 자기 호출

**관련 파일**: `nanoclaw/src/ipc.ts`

---

## HTTP Channel (`add-http` 스킬)

**역할**: FastAPI(Director) → NanoClaw(Artisan) 위임 브리지

**사용 주체**: FastAPI backend — `DelegateTaskTool`이 호출

**동작 방식**:
```
FastAPI PersonaAgent
  → DelegateTaskTool
    → POST /api/webhooks/fastapi (NanoClaw:4000)
      → 202 Accepted (즉시 반환, fire-and-forget)
        → NanoClaw agent 실행
          → POST {callback_url} (FastAPI:5500/v1/callback/nanoclaw/{session_id})
```

**설계 특징**:
- NanoClaw는 `202 Accepted`를 즉시 반환 — FastAPI가 블로킹되지 않음
- callback URL이 JID에 base64 인코딩됨 → NanoClaw 재시작해도 stateless 유지
- retry 없음 (의도적 — 피드백 루프 방지)
- Node.js 내장 `node:http` 사용 — 추가 npm 의존성 없음

**관련 파일**: `nanoclaw/src/channels/http.ts` (add-http 스킬 적용 후 생성)

---

## 한눈에 비교

| | IPC File Trigger | HTTP Channel |
|---|---|---|
| **방향** | 내부 자기 디스패치 | 외부(FastAPI) → NanoClaw |
| **사용 주체** | NanoClaw / 로컬 스크립트 | FastAPI DelegateTaskTool |
| **프로토콜** | 파일시스템 | HTTP (포트 4000) |
| **응답** | 없음 (단방향) | 202 → 비동기 callback |
| **NanoClaw 재시작 안전성** | O (파일 남아있음) | O (JID에 callback URL 인코딩) |
| **네트워크 필요** | X | O (루프백) |

---

## 자주 하는 혼동

**"IPC가 있으니까 HTTP Channel은 필요 없지 않나?"**

→ 아니다. IPC는 파일시스템 접근이 가능한 경우만 쓸 수 있다. FastAPI는 NanoClaw의 파일시스템에 직접 쓰지 않는다 — HTTP로 요청을 보낸다.

**"HTTP Channel을 Redis Queue로 대체하면 더 낫지 않나?"**

→ 현재 단일 사용자 데스크탑 환경에서는 오버엔지니어링이다. HTTP Channel은 이미 stateless하게 설계되어 있고 (JID = base64(callback_url)), 로컬 루프백에서 HTTP 유실은 실질적으로 없다. 멀티 워커가 필요해지는 시점에 재검토할 것.
