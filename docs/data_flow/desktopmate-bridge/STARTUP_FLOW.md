# desktopmate-bridge Startup Flow

Updated: 2026-04-05

## Overview

`service.ts`가 homunculus engine에 의해 실행될 때의 초기화 순서와 WebSocket 연결 흐름.
`tsx` 런타임으로 직접 실행 (빌드 스텝 없음).

---

## 시작 시퀀스

```mermaid
sequenceDiagram
    participant Engine as desktop-homunculus Engine
    participant Svc as service.ts
    participant Prefs as preferences (SQLite)
    participant VRM as Vrm API (homunculus_api)
    participant UI as React UI (WebView)
    participant BE as FastAPI Backend

    Engine->>Svc: 프로세스 시작 (node --import tsx service.ts)

    Note over Svc: --- 동기 초기화 ---
    Svc->>Svc: loadConfig() → config.yaml 파싱

    Note over Svc: --- VRM 스폰 (await) ---
    Svc->>Prefs: preferences.load("transform::desktopmate-bridge:elmer")
    Prefs-->>Svc: TransformArgs (없으면 undefined)
    Svc->>VRM: Vrm.spawn("desktopmate-bridge:elmer", { transform })
    VRM-->>Svc: vrm instance
    Svc->>VRM: vrm.playVrma("vrma:idle-maid", { repeat: forever, transitionSecs: 0.5 })
    Svc->>VRM: vrm.events().on("state-change", handleVrmStateChange)

    Note over Svc: --- TTS Queue 생성 ---
    Svc->>Svc: _ttsQueue = createTtsQueue(vrm)

    Note over Svc: --- connectAndServe (fire-and-forget) ---
    Svc->>UI: signals.send("dm-config", { user_id, agent_id, ... })
    UI->>UI: store.setSettings(config)

    Svc->>Svc: startRpcServer(config)\n메서드 등록: sendMessage, interruptStream,\nupdateConfig, getStatus, listWindows,\ncaptureScreen, captureWindow, reconnect

    Svc->>BE: connectWithRetry → new WebSocket(ws_url)

    BE-->>Svc: WebSocket open
    Svc->>BE: { type: "authorize", token, user_id, agent_id }

    BE-->>Svc: { type: "authorize_success", connection_id }
    Svc->>UI: signals.send("dm-connection-status", { status: "connected" })
    UI->>UI: 연결 상태 표시 갱신
```

---

## VRM 상태 머신

VRM이 드래그/클릭 등 사용자 인터랙션에 따라 상태를 변경할 때 자동으로 애니메이션이 전환된다.

```mermaid
stateDiagram-v2
    [*] --> idle: Vrm.spawn() 완료

    idle --> drag: state-change "drag"\nvrm.unlook()\nvrma:grabbed (resetSpringBones)

    drag --> idle: state-change "idle"\nvrma:idle-maid\nsleep(500ms) → lookAtCursor()

    idle --> sitting: state-change "sitting"\nvrma:idle-sitting\nsleep(500ms) → lookAtCursor()

    sitting --> idle: state-change "idle"\nvrma:idle-maid\nsleep(500ms) → lookAtCursor()
```

모든 애니메이션: `repeat.forever()`, `transitionSecs: 0.5`

---

## WebSocket 재연결 정책

```mermaid
flowchart TD
    A[WebSocket close 이벤트] --> B{code?}
    B -- 4001 또는 authorize_error --> Z[재연결 없음\n인증 실패]
    B -- 4002 / 4003 / 4004 --> Z2[재연결 없음\n정상 종료]
    B -- 기타 non-retry code --> Z3[disconnected 시그널\n재연결 없음]
    B -- 4000 / 1011 --> C{attempts < 3?}
    C -- Yes --> D[sleep RETRY_DELAYS_MS\n1s → 2s → 3s\nconnectWithRetry attempts+1]
    C -- No --> E[dm-connection-status:\nrestart-required]
```

| close code | 의미 | 재연결 |
|------------|------|--------|
| 4000 | Ping timeout | 최대 3회 |
| 1011 | Internal server error | 최대 3회 |
| 4001 | Auth failed | 없음 |
| 4002 | Concurrent turn | 없음 |
| 4003 | Stream interrupted | 없음 |
| 4004 | Turn not found | 없음 |

---

## TTS Chunk 처리 흐름

```mermaid
sequenceDiagram
    participant BE as FastAPI Backend
    participant Queue as TtsChunkQueue
    participant VRM as vrm.speakWithTimeline
    participant UI as React UI (dm-tts-chunk signal)

    BE-->>Queue: tts_chunk { sequence, text, emotion, audio_base64, keyframes }
    Note over Queue: sequence 순서 보장 버퍼링
    Queue->>Queue: flush() on stream_end

    Queue->>VRM: speakWithTimeline(audioBytes, keyframes, { waitForCompletion: true })
    Note over VRM: WAV 재생 + keyframes 기반 립싱크
    VRM-->>Queue: 완료

    Queue->>UI: signals.send("dm-tts-chunk", { sequence, text, emotion })
    Note over UI: 자막 표시 등 UI 업데이트
```

---

## Appendix

- 구현: `desktop-homunculus/mods/desktopmate-bridge/src/service.ts`
- VRM 에셋 ID: `desktopmate-bridge:elmer` (하드코딩, TODO: UI 설정 연동)
- config 경로: `mods/desktopmate-bridge/config.yaml`
- transform 저장: `preferences.db` key `"transform::desktopmate-bridge:elmer"`
