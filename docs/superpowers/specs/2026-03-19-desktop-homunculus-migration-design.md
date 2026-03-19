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
        │                              │
        │ WebSocket                    │ REST (STM)
        ▼                              ▼
┌─────────────────────────────────────────────────┐
│  MOD: mods/desktopmate-bridge/                  │
│                                                 │
│  service.ts  ──Signals(SSE)──→  ui/ (React)    │
│      │              ←── RPC ──      │           │
│      │                         直접 HTTP 호출   │
│      │                    (localhost:5500 REST) │
└──────┼──────────────────────────────────────────┘
       │ HTTP REST (localhost:3100)
       ▼
desktop-homunculus Engine
(VRM 렌더링, Speech Timeline)
```

**역할 분리**:
- `service.ts`: FastAPI WebSocket 연결 + homunculus 엔진 제어 전담
- `ui/ (React)`: 채팅 UI 렌더링 + FastAPI STM REST 직접 호출
- Signals (SSE): service.ts → UI 단방향 이벤트 (desktop-homunculus 네이티브 IPC 메커니즘)

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

FastAPI WebSocket 연결과 homunculus 엔진 제어만 담당한다. STM REST 프록시 역할 없음.

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
| `stream_end` | `dm-message-complete` signal broadcast |
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
| 1011 | 서버 오류 | 재연결 (아래 정책 참조) |

재연결 정책 (로컬 데스크탑 앱 기준): 최대 3회 재시도 (1s → 2s → 3s). 모두 실패 시 `dm-connection-status: disconnected` + "백엔드 재시작 필요" 메시지 전송. 백엔드가 죽은 경우 장시간 대기는 불필요.

### RPC 메서드 (UI → service.ts)

WebSocket 제어 전용. STM REST 호출은 UI가 FastAPI로 직접.

| RPC 메서드 | 동작 |
|---|---|
| `sendMessage(content, session_id?)` | WebSocket `chat_message` 전송 |
| `interruptStream()` | WebSocket `interrupt_stream` 전송 |

---

## Section 2: Chat UI (React WebView)

MOD WebView로 렌더링되는 채팅 인터페이스. STM REST는 `localhost:5500`으로 직접 호출한다.

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
  - 연결 상태 표시 (Connected/Disconnected / 백엔드 재시작 필요)
  - [Drag] 버튼 — 채팅창 위치 드래그
  - 메시지 입력창
  - [Send/Stop] — AI 처리 중 Stop으로 전환, 입력창 비활성화
  - [ChatHistory Toggle] — 채팅창 표시/숨김
  - [SessionList Toggle] — 사이드바 표시/숨김

### 상태 관리

전역 상태(Zustand 등)를 사용한다. 컴포넌트는 mount 시 상태를 읽기만 하며, Toggle 여부와 무관하게 상태는 항상 갱신된다.

- `messages[]`: 현재 세션의 메시지 목록
- `sessions[]`: 세션 목록 (사이드바 렌더링용)
- `activeSessionId`: 현재 활성 세션
- `isTyping`: typing indicator 상태
- `connectionStatus`: connected / disconnected / restart-required

### Toggle 독립성 시나리오

UI가 숨겨져 있어도 상태는 갱신된다. 컴포넌트가 다시 표시될 때 최신 상태를 그대로 렌더링:

1. 사이드바 ON, 채팅창 OFF → New Chat 클릭 → `activeSessionId = null`, `messages = []` 갱신
2. 사이드바 ON, 채팅창 OFF → 기존 세션 클릭 → `activeSessionId` 변경, `messages` 로드
3. 사이드바 OFF, 채팅창 ON → 메시지 전송 → `messages` 추가, `sessions` UpdatedAt 갱신
4. 사이드바 OFF, 채팅창 OFF → 메시지 전송 → 동일하게 상태 갱신

### FastAPI REST 직접 호출 (UI → localhost:5500)

| 동작 | 엔드포인트 |
|---|---|
| 세션 목록 조회 | `GET /v1/stm/sessions?user_id=&agent_id=` |
| 채팅 히스토리 조회 | `GET /v1/stm/get-chat-history?session_id=&user_id=&agent_id=` |
| 세션 삭제 | `DELETE /v1/stm/sessions/{session_id}?user_id=&agent_id=` |
| 세션 메타데이터 수정 | `PATCH /v1/stm/sessions/{session_id}/metadata` |

`stream_end` 수신 후 `getSessions()`를 호출해 세션 목록 갱신 (UpdatedAt 포함). 낙관적 업데이트 없음.

---

## Section 3: service.ts ↔ UI 통신

### Signals (service.ts → UI, SSE broadcast)

desktop-homunculus MOD 시스템에서 service.ts(Node.js 프로세스)와 UI(CEF WebView)는 별도 프로세스이므로, 프레임워크가 제공하는 Signals API가 유일한 네이티브 IPC 메커니즘이다.

| Signal | 시점 | 페이로드 |
|---|---|---|
| `dm-typing-start` | stream_start 수신 | `{ turn_id, session_id }` |
| `dm-tts-chunk` | tts_chunk 수신 | `{ sequence, text, emotion }` — audio_base64/keyframes는 homunculus API 호출 전용, signal 미포함 |
| `dm-message-complete` | stream_end 수신 | `{ turn_id, session_id, content }` |
| `dm-connection-status` | WS 연결/끊김/재시도 초과 | `{ status: "connected" \| "disconnected" \| "restart-required" }` |

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

**WS 끊김 시 재생 중인 TTS**: 재생 중인 오디오는 완료까지 유지. 이후 재연결 시도.

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

## Development: Mock Server

UI 및 service.ts 개발 시 desktop-homunculus 전체 구동 없이 작업할 수 있도록 mock 서버를 제공한다.

```text
mods/desktopmate-bridge/scripts/mock-homunculus.ts
```

`localhost:3100`을 모방하며 모든 엔드포인트에 `200 OK`만 반환. `npm run mock` 으로 실행.

---

## File Structure

```text
desktop-homunculus/mods/desktopmate-bridge/
├── package.json          # MOD 등록 (homunculus.service, homunculus.menus)
├── config.yaml           # entity_id, FastAPI URL/token, user_id, agent_id
├── service.ts            # WebSocket 브리지 + homunculus 엔진 제어
├── scripts/
│   └── mock-homunculus.ts  # 개발용 homunculus mock 서버
└── ui/
    ├── index.html
    ├── src/
    │   ├── App.tsx
    │   ├── store.ts            # Zustand 전역 상태
    │   ├── components/
    │   │   ├── SessionSidebar.tsx
    │   │   ├── ChatWindow.tsx
    │   │   └── ControlBar.tsx
    │   └── hooks/
    │       └── useSignals.ts   # SSE 구독 (dm-* signals)
    └── vite.config.ts
```

---

## Out of Scope

- NanoClaw 변경 없음
