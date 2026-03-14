# TTS Flow Internalization Design

**Date**: 2026-03-14
**Status**: Draft
**Scope**: FastAPI backend (`backend/`)
**Approach**: Option A — EventHandler-level internalization

---

## Summary

현재 TTS 흐름은 Backend가 `tts_ready_chunk` (text + emotion)을 Unity에 전송하면, Unity가 다시 `POST /v1/tts/synthesize` REST API를 호출하여 audio를 받아오는 구조다. 이는 불필요한 round-trip이며, "Unity = Dumb UI" 원칙에 위배된다.

변경 후 Backend가 TTS 생성까지 내부에서 처리한 뒤, text + audio + emotion + motion 메타데이터를 `tts_chunk` 메시지 하나로 Unity에 전송한다. Unity는 받아서 재생만 한다.

### What Changes

| Area | AS-IS | TO-BE |
|------|-------|-------|
| TTS 생성 주체 | Unity (HTTP 요청) | Backend (내부 처리) |
| WS 메시지 | `tts_ready_chunk` {text, emotion} | `tts_chunk` {seq, text, audio, emotion, motion, blendshape} |
| Unity 역할 | TTS HTTP 호출 + emotion→motion 매핑 + 큐잉 + 재생 | 수신 → 큐잉 → 재생 |
| REST API | 채팅 플로우 핵심 경로 | Deprecated (테스트/디버깅용 유지) |
| motion 매핑 | Unity 내부 로직 | Backend YAML 기반 dummy 테이블 |

---

## 1. Architecture

### 변경되는 파이프라인

```text
[현재]
Agent stream → TextChunkProcessor → TTSTextProcessor
  → tts_ready_chunk {text, emotion} ──WS──→ Unity
  → Unity ──HTTP──→ POST /v1/tts/synthesize ──→ Unity: queue & play

[변경 후]
Agent stream → TextChunkProcessor → TTSTextProcessor
  → asyncio.create_task(_synthesize_and_send())
    → asyncio.to_thread(generate_speech()) + EmotionMotionMapper.map()
    → tts_chunk {seq, text, audio_base64, emotion, motion, blendshape} ──WS──→ Unity
  → Unity: queue & play
```

### 핵심 설계 결정

- **EventHandler 레벨**: 기존 `_build_tts_event()` 위치에서 TTS 생성을 끼워넣는다. Agent 레이어 무변경.
- **`asyncio.create_task()`**: TTS 생성은 텍스트 스트리밍과 병렬. 스트리밍을 블로킹하지 않는다.
- **`asyncio.to_thread()`**: `TTSService.generate_speech()`가 동기이므로 thread pool에서 실행.
- **기존 파이프라인 재사용**: TextChunkProcessor (sentence split), TTSTextProcessor (emotion 추출) 그대로 유지.

---

## 2. New Components

### 2.1 EmotionMotionMapper

**File**: `src/services/tts_service/emotion_motion_mapper.py`

```python
class EmotionMotionMapper:
    """YAML-based emotion → motion/blendshape mapping."""

    def __init__(self, config: dict[str, dict[str, str]]):
        # config = { "joyful": {"motion": "happy_idle", "blendshape": "smile"}, ... }

    def map(self, emotion: str | None) -> tuple[str, str]:
        # Returns (motion_name, blendshape_name)
        # Unknown/None emotion → default values
```

- Dummy 매핑 테이블로 시작
- 추후 API로 테이블 업데이트 가능한 setter 메서드 준비
- 설정은 `yaml_files/tts_rules.yml`의 `emotion_motion_map` 섹션에서 로드

### 2.2 synthesize_chunk()

**File**: `src/services/tts_service/tts_pipeline.py`

```python
SILENT_MP3_BASE64: str = "..."  # Minimal silent MP3 constant

async def synthesize_chunk(
    tts_service: TTSService,
    mapper: EmotionMotionMapper,
    text: str,
    emotion: str | None,
    sequence: int,
    tts_enabled: bool = True,
    reference_id: str | None = None,
) -> TtsChunkMessage | None:
    """
    1. motion_name, blendshape_name = mapper.map(emotion)
    2. if tts_enabled:
           audio = await asyncio.to_thread(generate_speech(text, "base64", "mp3"))
           if audio is None → return None (caller sends warning + silent fallback)
       else:
           audio = SILENT_MP3_BASE64  (skip TTS API call)
    3. Assemble and return TtsChunkMessage
    """
```

---

## 3. Message Spec Changes

### 3.1 chat_message (FE → BE) — Field Addition

```json
{
  "type": "chat_message",
  "content": "string",
  "agent_id": "string",
  "user_id": "string",
  "session_id": "uuid | null",
  "persona": "string",
  "images": [{ "type": "image_url", "image_url": { "url": "..." } }],
  "tts_enabled": true
}
```

- `tts_enabled: bool = True` — 기본값 `true`로 기존 클라이언트 하위 호환

### 3.2 tts_chunk (BE → FE) — New

```json
{
  "type": "tts_chunk",
  "sequence": 0,
  "text": "안녕하세요!",
  "audio_base64": "//uQxAAA...",
  "emotion": "joyful",
  "motion_name": "happy_idle",
  "blendshape_name": "smile"
}
```

- `sequence`: FE 재생 순서 보장용 정수 (0부터 시작, turn 내 증가)
- `audio_base64`: MP3 포맷, base64 인코딩
- FE는 sequence 기반 priority queue로 순서대로 재생

### 3.3 warning (BE → FE) — New

```json
{
  "type": "warning",
  "code": "TTS_SYNTHESIS_FAILED",
  "message": "TTS synthesis failed for chunk 3, sending silent audio"
}
```

### 3.4 tts_ready_chunk — Deprecated

- 코드에서 즉시 삭제하지 않음
- `tts_enabled=true`일 때 `tts_chunk`만 전송, `tts_ready_chunk`는 전송하지 않음

### 3.5 MessageType Enum Additions

```python
TTS_CHUNK = "tts_chunk"
WARNING = "warning"
```

---

## 4. File-Level Changes

### 4.1 Modified Files

| File | Change |
|------|--------|
| `src/models/websocket.py` | `ChatMessage.tts_enabled` 추가, `TtsChunkMessage`/`WarningMessage` 모델 추가, `MessageType` enum 추가 |
| `src/services/websocket_service/message_processor/event_handlers.py` | `_build_tts_event()` → `_synthesize_and_send()` 교체, TTS 서비스/매퍼 의존성 주입, sequence 카운터 |
| `src/services/websocket_service/message_processor/processor.py` | `EventHandler` 생성 시 `tts_service`, `EmotionMotionMapper` 전달, `tts_enabled` 전파 |
| `src/services/websocket_service/message_processor/models.py` | `ConversationTurn.tts_enabled: bool` 추가 |
| `src/services/websocket_service/manager/handlers.py` | `chat_message`에서 `tts_enabled` 추출, MessageProcessor에 전달 |
| `src/api/routes/tts.py` | `POST /v1/tts/synthesize` deprecation 헤더/주석 추가 |
| `yaml_files/tts_rules.yml` | `emotion_motion_map` 섹션 추가 |

### 4.2 New Files

| File | Purpose |
|------|---------|
| `src/services/tts_service/emotion_motion_mapper.py` | Emotion → motion/blendshape dummy 매핑 |
| `src/services/tts_service/tts_pipeline.py` | `synthesize_chunk()` async 파이프라인 + `SILENT_MP3_BASE64` 상수 |

### 4.3 Unchanged

- `TTSService` ABC 및 구현체 (`fish_speech.py`, `vllm_omni.py`)
- `TTSTextProcessor`, `TextChunkProcessor`
- `openai_chat_agent.py`
- `tts_factory.py`, `service_manager.py`

---

## 5. Error Handling

### TTS 생성 실패

```text
_synthesize_and_send(text, emotion, sequence, tts_enabled):
  motion, blendshape = mapper.map(emotion)
  if tts_enabled:
      try:
          audio = await asyncio.to_thread(generate_speech(...))
          if audio is None → raise TTSSynthesisError
      except Exception:
          → warning 전송 (code: TTS_SYNTHESIS_FAILED)
          audio = SILENT_MP3_BASE64
  else:
      audio = SILENT_MP3_BASE64  (TTS API 호출 스킵)
  → tts_chunk { sequence, text, audio, emotion, motion, blendshape } 전송
```

- 실패해도 해당 sequence의 `tts_chunk`를 전송해야 FE 큐가 막히지 않음
- `warning`은 `tts_chunk` 직전에 전송

### tts_enabled=False

- TTS 서비스 호출을 스킵 (API 비용/latency 절약)
- `tts_chunk`는 **전송함** — `audio_base64 = SILENT_MP3_BASE64`, emotion/motion/blendshape는 정상 전달
- Unity가 motion/expression 애니메이션을 계속 재생할 수 있도록 보장
- 음성만 무음이고 캐릭터 움직임은 유지되는 "무음 모드"

### 연결 끊김 도중 TTS task

- 이벤트 큐 put 시 `is_closing` 플래그 체크 → 닫혔으면 조용히 drop
- TTS task는 `ConversationTurn.tasks` set에 추가 → turn 종료 시 일괄 cancel

### Concurrent Turn (4002)

- 기존 concurrent turn protection 그대로 유지
- 첫 번째 turn의 TTS task들이 아직 돌고 있어도 turn cancel 시 함께 cancel

---

## 6. Configuration

### yaml_files/tts_rules.yml — 추가 섹션

```yaml
emotion_motion_map:
  joyful:        { motion: "happy_idle",     blendshape: "smile" }
  sad:           { motion: "sad_idle",       blendshape: "sad" }
  angry:         { motion: "angry_idle",     blendshape: "angry" }
  surprised:     { motion: "surprised_idle", blendshape: "surprised" }
  scared:        { motion: "scared_idle",    blendshape: "scared" }
  disgusted:     { motion: "disgusted_idle", blendshape: "disgusted" }
  confused:      { motion: "confused_idle",  blendshape: "confused" }
  curious:       { motion: "curious_idle",   blendshape: "curious" }
  worried:       { motion: "worried_idle",   blendshape: "worried" }
  satisfied:     { motion: "satisfied_idle", blendshape: "smile" }
  sarcastic:     { motion: "neutral_idle",   blendshape: "smirk" }
  laughing:      { motion: "laughing_idle",  blendshape: "laugh" }
  crying loudly: { motion: "crying_idle",    blendshape: "cry" }
  sighing:       { motion: "sigh_idle",      blendshape: "tired" }
  whispering:    { motion: "whisper_idle",   blendshape: "neutral" }
  hesitating:    { motion: "hesitate_idle",  blendshape: "nervous" }
  default:       { motion: "neutral_idle",   blendshape: "neutral" }
```

---

## 7. Testing

### Unit Tests

| Target | Cases |
|--------|-------|
| `EmotionMotionMapper` | 등록 emotion → 올바른 반환, 미등록 → default, None → default |
| `synthesize_chunk()` | 정상 → TtsChunkMessage, generate_speech None → None, exception → None |
| `EventHandler._synthesize_and_send()` | tts_enabled=True + 정상 → 큐에 tts_chunk (실제 audio), 실패 → warning + 무음 tts_chunk, tts_enabled=False → 큐에 tts_chunk (무음 audio + motion 정상), is_closing → drop |
| `ChatMessage` model | tts_enabled 미전송 → True, False 명시 → 정상 파싱 |

### Integration Tests

| Test | Verification |
|------|-------------|
| WS chat_message { tts_enabled: true } | `tts_chunk` 수신, sequence 순서, audio_base64 유효성 |
| WS chat_message { tts_enabled: false } | `tts_chunk` 수신, audio_base64가 무음, emotion/motion/blendshape 정상 |

### Not Tested

- `generate_speech()` 내부 (기존 TTS 서비스 테스트 커버)
- `TextChunkProcessor`, `TTSTextProcessor` (기존 테스트 유지)
- Unity 측 재생 로직

---

## 8. Documentation Updates

| Document | Change |
|----------|--------|
| `docs/data_flow/chat/ADD_CHAT_MESSAGE.md` | 다이어그램 전면 수정: tts_chunk, stream_end 순서, images 형식, tts_enabled |
| `docs/websocket/WEBSOCKET_API_GUIDE.md` | `tts_ready_chunk` deprecated, `tts_chunk`/`warning` 추가 |
| `docs/api/TTS_Synthesize.md` | Deprecated 표기 |
| `docs/websocket/WebSocket_ChatMessage.md` | `tts_enabled` 필드 문서화 |

---

## 9. Unity (FE) Impact

Backend 변경에 따른 Unity 측 필요 작업 (이 Spec 범위 외, 참고용):

**제거:**
- `tts_ready_chunk` 핸들러
- `POST /v1/tts/synthesize` HTTP 호출 코드
- emotion → motion/blendshape 결정 로직

**추가:**
- `chat_message` 전송 시 `tts_enabled` 필드 포함
- `tts_chunk` 핸들러: sequence 기반 priority queue → audio_base64 디코딩 → 재생
- `warning` 핸들러: 코드/메시지 로깅

---

## Appendix

- [Current Data Flow](../../data_flow/chat/ADD_CHAT_MESSAGE.md)
- [WebSocket API Guide](../../websocket/WEBSOCKET_API_GUIDE.md)
- [TTS Synthesize API](../../api/TTS_Synthesize.md)
- [Agent Service](../../feature/service/Agent_Service.md)
