# Desktop Homunculus Migration Design

**Date**: 2026-03-19
**Status**: Approved
**Scope**: Replace Unity UI with desktop-homunculus as Dumb UI

---

## Overview

Unity UI를 제거하고 desktop-homunculus를 Dumb UI로 교체한다. FastAPI 백엔드는 WebSocket 프로토콜 구조는 유지하되, Unity 전용 임시 필드(motion_name/blendshape_name)를 homunculus 호환 형식으로 교체한다.

---

## Architecture

```text
FastAPI Backend (ws://127.0.0.1:5500/v1/chat/stream)
        │
        │ WebSocket
        ▼
┌─────────────────────────────────────────┐
│  MOD: mods/desktopmate-bridge/          │
│                                         │
│  service.ts  ←── RPC ──→  ui/ (React)  │
│      │                        │         │
│      └── Signals (SSE) ───────┘         │
└─────────────────────────────────────────┘
        │
        │ HTTP REST (localhost:3100)
        ▼
desktop-homunculus Engine
(VRM 렌더링, Speech Timeline, Animation)
```

**핵심 원칙**: desktop-homunculus는 Dumb UI — 렌더링과 입출력만 담당. 비즈니스 로직 없음.

---

## Backend Internal Changes (FastAPI)

> **⚠️ 미완료 작업**: 아래 변경 사항은 MOD 구현 전에 반드시 완료되어야 한다.
> 현재 백엔드 코드는 MP3 + motion_name/blendshape_name (Unity 임시 필드)를 사용 중이다.
> MOD는 변경 완료 후의 계약을 기준으로 구현한다.

Unity 전용 임시 필드를 homunculus 호환 형식으로 교체한다. WebSocket 메시지 구조 자체는 유지.

| 변경 항목 | 기존 (현재 코드) | 변경 후 |
|---|---|---|
| TTS 오디오 포맷 | MP3 (base64) | WAV (base64) — homunculus speech timeline API 요구사항 |
| `tts_chunk.motion_name` | Unity AnimationPlayer 이름 (임시) | 제거 |
| `tts_chunk.blendshape_name` | Unity blendshape 이름 (임시) | 제거 |
| `tts_chunk.keyframes` | 없음 | 추가 — `[{ duration: number, targets: Record<string, number> }]` |
| `tts_chunk.emotion` | 유지 | 유지 |

`keyframes` 형식은 desktop-homunculus `POST /vrm/{entity}/speech/timeline` API 명세를 따른다.

**구현 게이트**: `tts_pipeline.py` + `TtsChunkMessage` 모델 변경 완료 후 MOD service.ts 구현 시작.

---

## Section 1: service.ts (Bridge Core)

FastAPI WebSocket 연결을 관리하고, UI에 RPC 메서드를 제공한다.

### 초기화

앱 시작 시:
1. `config.yaml`에서 `entity_id` 로드 (제어할 VRM 캐릭터 식별자)
2. FastAPI WebSocket 연결 및 `authorize` 전송
3. `authorize_success` 수신 후 `connection_id` 저장 (향후 사용 대비)

`entity_id`는 `mods/desktopmate-bridge/config.yaml`에 하드코딩:
```yaml
fastapi:
  ws_url: "ws://127.0.0.1:5500/v1/chat/stream"
  token: "<auth_token>"
  user_id: "default"
  agent_id: "yuri"
homunculus:
  entity_id: "<vrm_entity_id>"
  api_url: "http://localhost:3100"
```

### WebSocket 이벤트 처리

| 수신 이벤트 | 처리 |
|---|---|
| `authorize_success` | `connection_id` 저장, `dm-connection-status: connected` signal 전송 |
| `authorize_error` | `dm-connection-status: disconnected` signal 전송, 재연결 금지 |
| `stream_start` | `dm-typing-start` signal broadcast (`{ turn_id, session_id }`) |
| `stream_token` | 무시 (서버 내부 이벤트, 클라이언트 불필요) |
| `tts_chunk` | audio_base64(WAV) + keyframes → homunculus speech timeline API 호출, `dm-tts-chunk` signal broadcast |
| `stream_end` | `dm-message-complete` signal broadcast, `dm-session-updated` signal broadcast |
| `ping` | `pong` 응답 (`pong_timeout` 설정값 내, 기본 10s) |
| `error` | 에러 코드 기반 처리 (아래 참조) |

### 에러 코드별 재연결 정책

| 코드 | 원인 | 처리 |
|---|---|---|
| 4000 | Ping timeout | 즉시 재연결 |
| 4001 | Auth 실패 | **재연결 금지** — `dm-connection-status: disconnected` 전송 후 중단 |
| 4002 | 동시 턴 충돌 | 재연결 없음, 현재 `stream_end` 대기 |
| 4003 | 사용자 중단 | 정상 종료, 재연결 없음 |
| 4004 | 턴 없음 | 무시 |
| 1011 | 서버 오류 | exponential backoff 재연결 |

재연결 정책: exponential backoff (1s → 2s → 4s → ... → max 30s).

### RPC 메서드 (UI → service.ts)

| RPC 메서드 | 동작 |
|---|---|
| `sendMessage(content, session_id?)` | WebSocket `chat_message` 전송 |
| `interruptStream()` | WebSocket `interrupt_stream` 전송 |
| `getSessions(user_id, agent_id)` | FastAPI `GET /v1/stm/sessions` 프록시 |
| `getChatHistory(session_id, user_id, agent_id)` | FastAPI `GET /v1/stm/get-chat-history` 프록시 |
| `deleteSession(session_id, user_id, agent_id)` | FastAPI `DELETE /v1/stm/sessions/{session_id}` 프록시 |
| `updateSessionMetadata(session_id, metadata)` | FastAPI `PATCH /v1/stm/sessions/{session_id}/metadata` 프록시 |

---

## Section 2: Chat UI (React WebView)

MOD WebView로 렌더링되는 채팅 인터페이스.

### 레이아웃

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ [세션 사이드바]                     |  [채팅창]                               │
│                                     |                                         │
│  Conversations                      |  AI: What is the most...    01:33:17   │
│                                     |                                         │
│  - Meeting Notes [✎] [🗑]          |  User: How are you...       01:33:39   │
│    - CreatedAt 2025-10-26           |  AI: What leads you...      01:33:53   │
│    - UpdatedAt 2025-10-28           |  User: Example Text...      01:33:39   │
│  - API Integration Plan [✎] [🗑]   |                                         │
│    - CreatedAt 2025-11-26           |  AI: What leads you...      01:33:53   │
│    - UpdatedAt 2026-01-11           |  User: Example Text...      01:33:39   │
│                                     |                                         │
│  [ + New Chat ]                     |  User: ...                  01:34:19   │
│                                     |                                         │
├──────────────────────────────────────────────────────────────────────────────┤
│                        ✔ Connected / disconnected                             │
│ [Drag] [    Enter message...    ]  [ Send/Stop ] [ChatHistory] [SessionList] │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 주요 컴포넌트

- **세션 사이드바**: 세션 목록 (CreatedAt/UpdatedAt 표시), [✎ 이름변경] [🗑 삭제], [+ New Chat]
- **채팅창**: AI/User 메시지 + 타임스탬프, typing indicator (stream_start ~ stream_end)
- **하단 컨트롤 바**:
  - 연결 상태 표시 (Connected/Disconnected)
  - [Drag] 버튼 — 채팅창 위치 드래그
  - 메시지 입력창
  - [Send/Stop] — AI 처리 중 Stop으로 전환, 입력창 비활성화
  - [ChatHistory Toggle] — 채팅창 표시/숨김
  - [SessionList Toggle] — 사이드바 표시/숨김

### Toggle 독립성 시나리오

채팅창·세션사이드바는 Toggle 여부와 관계없이 항상 동작해야 한다:

1. 사이드바 ON, 채팅창 OFF → 사이드바에서 New Chat 클릭 → 채팅창 숨김 상태지만 새 대화 시작
2. 사이드바 ON, 채팅창 OFF → 사이드바에서 기존 대화 클릭 → 채팅창 숨김 상태지만 해당 대화로 전환
3. 사이드바 OFF, 채팅창 ON → 메시지 전송 → 채팅창에 추가 + 사이드바 UpdatedAt 갱신
4. 사이드바 OFF, 채팅창 OFF → 메시지 전송 → 채팅창 + 사이드바 모두 갱신 (숨김 상태로)

---

## Section 3: service.ts ↔ UI 통신

### Signals (service.ts → UI, SSE broadcast)

| Signal | 시점 | 페이로드 |
|---|---|---|
| `dm-typing-start` | stream_start 수신 | `{ turn_id, session_id }` |
| `dm-tts-chunk` | tts_chunk 수신 | `{ sequence, text, emotion }` — audio_base64/keyframes는 homunculus API 호출에만 사용, signal에 포함 안 함 |
| `dm-message-complete` | stream_end 수신 | `{ turn_id, session_id, content }` |
| `dm-session-updated` | stream_end 직후 | `{ session_id, updated_at }` — `updated_at`은 service.ts가 `Date.now()` 생성 (낙관적 값). 이후 `getSessions()` 호출 시 STM의 실제 값으로 덮어씌워짐 |
| `dm-connection-status` | WS 연결/끊김 | `{ status: "connected" \| "disconnected" }` |

### TTS 처리 흐름

```text
tts_chunk 수신
    ├── audio_base64 (WAV) + keyframes
    │       → POST /vrm/{entity_id}/speech/timeline
    │         (audio: WAV base64, keyframes: TimelineKeyframe[])
    │
    └── audio_base64 = null → 오디오 스킵, API 호출 없음
```

WAV/keyframes 포맷은 FastAPI가 homunculus 호환 형식으로 생성하므로 MOD에서 변환 불필요.

**WS 끊김 시 재생 중인 TTS 처리**: 재생 중인 오디오는 완료까지 유지 (중단하지 않음). 이후 재연결 시도.

### package.json MOD 등록 필수 필드

```json
{
  "homunculus": {
    "service": "service.ts",
    "menus": [
      {
        "label": "Chat",
        "asset": "ui/index.html"
      }
    ]
  }
}
```

---

## File Structure

```text
desktop-homunculus/mods/desktopmate-bridge/
├── package.json          # MOD 등록 (homunculus.service, homunculus.menus)
├── config.yaml           # entity_id, FastAPI URL/token, user_id, agent_id
├── service.ts            # WebSocket 브리지 + RPC 메서드
└── ui/
    ├── index.html
    ├── src/
    │   ├── App.tsx
    │   ├── components/
    │   │   ├── SessionSidebar.tsx
    │   │   ├── ChatWindow.tsx
    │   │   └── ControlBar.tsx
    │   └── hooks/
    │       ├── useSignals.ts    # SSE 구독
    │       └── useRpc.ts        # RPC 호출
    └── vite.config.ts
```

---

## Out of Scope

- NanoClaw 변경 없음
- Unity 코드 삭제는 별도 cleanup 태스크
