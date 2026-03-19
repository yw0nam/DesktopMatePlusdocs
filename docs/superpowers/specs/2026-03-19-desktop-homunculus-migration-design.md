# Desktop Homunculus Migration Design

**Date**: 2026-03-19
**Status**: Approved
**Scope**: Replace Unity UI with desktop-homunculus as Dumb UI

---

## Overview

Unity UI를 제거하고 desktop-homunculus를 Dumb UI로 교체한다. FastAPI 백엔드는 변경 없음 — WebSocket 프로토콜이 이미 프론트엔드 중립적이므로 MOD 레이어만 추가한다.

---

## Architecture

```
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

## Section 1: service.ts (Bridge Core)

FastAPI WebSocket 연결을 관리하고, UI에 RPC 메서드를 제공한다.

### WebSocket 이벤트 처리

| 수신 이벤트 | 처리 |
|---|---|
| `authorize_success` | 연결 완료 상태 저장, `dm-connection-status: connected` signal 전송 |
| `stream_start` | `dm-typing-start` signal broadcast |
| `tts_chunk` | `audio_base64` → homunculus speech API, `motion_name`/`blendshape_name` → animation API, `dm-tts-chunk` signal broadcast |
| `stream_end` | `dm-message-complete` signal broadcast (content, session_id), `dm-session-updated` signal broadcast |
| `ping` | `pong` 응답 |
| `error` | 에러 로깅, 재연결 트리거 |
| `authorize_error` | 연결 실패, `dm-connection-status: disconnected` signal 전송 |

### RPC 메서드 (UI → service.ts)

| RPC 메서드 | 동작 |
|---|---|
| `sendMessage(content, session_id?)` | WebSocket `chat_message` 전송 |
| `interruptStream()` | WebSocket `interrupt_stream` 전송 |
| `getSessions(user_id, agent_id)` | FastAPI `GET /v1/stm/sessions` 프록시 |
| `getChatHistory(session_id)` | FastAPI `GET /v1/stm/get-chat-history` 프록시 |
| `deleteSession(session_id)` | FastAPI `DELETE /v1/stm/sessions/{session_id}` 프록시 |
| `updateSessionMetadata(session_id, metadata)` | FastAPI `PATCH /v1/stm/sessions/{session_id}/metadata` 프록시 |

### 연결 관리

- 앱 시작 시 자동 연결 + `authorize` 메시지 전송
- ping/pong 하트비트 처리 (서버 30s 간격, 10s 내 pong 응답)
- 끊김 시 exponential backoff 재연결
- 연결 상태를 `dm-connection-status` signal로 UI에 전파

---

## Section 2: Chat UI (React WebView)

MOD WebView로 렌더링되는 채팅 인터페이스.

### 레이아웃

```
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

1. 사이드바 토글 ON, 채팅창 토글 OFF → 사이드바에서 New Chat 클릭 → 채팅창 숨김 상태지만 새 대화 시작
2. 사이드바 토글 ON, 채팅창 토글 OFF → 사이드바에서 기존 대화 클릭 → 채팅창 숨김 상태지만 해당 대화로 전환
3. 사이드바 토글 OFF, 채팅창 토글 ON → 메시지 전송 → 채팅창에 추가 + 사이드바 UpdatedAt 갱신
4. 사이드바 토글 OFF, 채팅창 토글 OFF → 메시지 전송 → 채팅창 + 사이드바 모두 갱신 (숨김 상태로)

---

## Section 3: service.ts ↔ UI 통신

### Signals (service.ts → UI, SSE broadcast)

| Signal | 시점 | 페이로드 |
|---|---|---|
| `dm-typing-start` | stream_start 수신 | `{ turn_id }` |
| `dm-tts-chunk` | tts_chunk 수신 | `{ sequence, text, motion_name, blendshape_name }` |
| `dm-message-complete` | stream_end 수신 | `{ turn_id, session_id, content }` |
| `dm-session-updated` | stream_end 후 | `{ session_id, updated_at }` |
| `dm-connection-status` | WS 연결/끊김 | `{ status: "connected" \| "disconnected" }` |

### TTS 처리 흐름

```
tts_chunk 수신
    ├── audio_base64 → homunculus speech timeline API (MP3 재생)
    ├── motion_name  → homunculus animation API (VRMA 재생)
    └── blendshape_name → homunculus expression API
```

audio_base64가 null인 경우(TTS 비활성화 또는 합성 실패) → 애니메이션만 적용, 오디오 스킵.

---

## Out of Scope

- FastAPI 백엔드 변경 없음
- NanoClaw 변경 없음
- Unity 코드 삭제는 별도 cleanup 태스크

---

## File Structure

```
desktop-homunculus/mods/desktopmate-bridge/
├── package.json          # MOD 등록 (homunculus key, service, menus)
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
