# desktopmate-bridge ↔ FastAPI 구현 현황

Updated: 2026-03-23

## 1. WebSocket (`/v1/chat/stream`)

**구현 완료.** `service.ts`가 FastAPI에 WebSocket 연결을 유지.

### 메시지 프로토콜

| 방향 | 타입 | 페이로드 | 설명 |
|------|------|---------|------|
| UI→BE | `authorize` | `{ token, user_id, agent_id }` | 연결 직후 인증 |
| UI→BE | `chat_message` | `{ content, session_id, user_id, agent_id }` | 채팅 전송 (RPC `sendMessage` 경유) |
| UI→BE | `interrupt_stream` | — | 스트림 중단 |
| UI→BE | `pong` | — | 서버 ping에 응답 |
| BE→UI | `authorize_success` | `{ connection_id }` | 인증 성공 |
| BE→UI | `authorize_error` | — | 인증 실패 (재연결 없음) |
| BE→UI | `stream_start` | `{ turn_id, session_id }` | AI 응답 시작 |
| BE→UI | `tts_chunk` | `{ sequence, text, emotion, audio_base64, keyframes }` | 오디오 청크 + 립싱크 |
| BE→UI | `stream_end` | `{ turn_id, session_id, content }` | 응답 완료 |
| BE→UI | `ping` | — | heartbeat |

### 재연결 정책

- 코드 4000 / 1011: 최대 3회 재시도 (1s → 2s → 3s 딜레이)
- 코드 4001 / `authorize_error`: 재연결 없음
- 코드 4002 / 4003 / 4004: 재연결 없음 (정상 종료)
- 3회 초과: `dm-connection-status: restart-required` 시그널 발송

---

## 2. REST API (`api.ts` → FastAPI `/v1/stm/`)

| 메서드 | 엔드포인트 | 용도 | 상태 |
|--------|-----------|------|------|
| GET | `/v1/stm/sessions?user_id=&agent_id=` | 세션 목록 | ✅ |
| GET | `/v1/stm/get-chat-history?session_id=&user_id=&agent_id=` | 채팅 히스토리 | ✅ |
| DELETE | `/v1/stm/sessions/{session_id}?user_id=&agent_id=` | 세션 삭제 | ✅ |
| PATCH | `/v1/stm/sessions/{session_id}/metadata` | 세션 이름 변경 | ✅ |

---

## 3. Signals (service.ts → desktop-homunculus SDK → UI)

`service.ts`가 `@hmcs/sdk signals`로 브로드캐스트:

| 시그널 | 페이로드 | 트리거 |
|--------|---------|--------|
| `dm-connection-status` | `{ status: "connected" \| "disconnected" \| "restart-required" }` | WS 연결/해제 |
| `dm-typing-start` | `{ turn_id, session_id }` | `stream_start` 수신 시 |
| `dm-message-complete` | `{ turn_id, session_id, content }` | `stream_end` 수신 시 |
| `dm-tts-chunk` | `{ sequence, text, emotion }` | `tts_chunk` 수신 시 |
| `dm-config` | `{ user_id, agent_id, fastapi_rest_url, ... }` | 시작 시 + config 변경 시 |

---

## 4. RPC Methods (UI → service.ts)

UI가 `rpc.call()`로 service.ts에 요청:

| 메서드 | 입력 | 동작 |
|--------|------|------|
| `sendMessage` | `{ content, session_id? }` | WS로 `chat_message` 전송 |
| `interruptStream` | — | WS로 `interrupt_stream` 전송 |
| `updateConfig` | 설정 전체 | `config.yaml` 갱신 + `dm-config` 브로드캐스트 |

---

## 5. VRM 연동

| 이벤트 | 동작 |
|--------|------|
| `tts_chunk` 수신 | `vrm.speakWithTimeline(audioBytes, keyframes)` — 립싱크 포함 음성 재생 |
| VRM state `idle` | `vrma:idle-maid` + `vrm.lookAtCursor()` |
| VRM state `drag` | `vrma:grabbed` + `vrm.unlook()` |
| VRM state `sitting` | `vrma:idle-sitting` + `vrm.lookAtCursor()` |

---

## 6. 미구현 / TODO

| 항목 | 위치 | 내용 |
|------|------|------|
| VRM 캐릭터 에셋 설정 | `service.ts:224` | `desktopmate-bridge:elmer` 하드코딩 → UI 설정 연동 필요 |
| RPC graceful shutdown | `service.ts:274` | `rpcServer.stop()` 미구현 — SDK가 `stop()` API 미제공 |
