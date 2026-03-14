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
| --- | --- | --- |
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
  → await TTS task barrier (모든 tts_chunk 전송 완료 대기)
  → stream_end
  → Unity: queue & play
```

### 핵심 설계 결정

- **EventHandler 레벨**: 기존 `_build_tts_event()` 위치에서 TTS 생성을 끼워넣는다. Agent 레이어 무변경.
- **`asyncio.create_task()`**: TTS 생성은 텍스트 스트리밍과 병렬. 스트리밍을 블로킹하지 않는다.
- **`asyncio.to_thread()`**: `TTSService.generate_speech()`가 동기이므로 thread pool에서 실행.
- **기존 파이프라인 재사용**: TextChunkProcessor (sentence split), TTSTextProcessor (emotion 추출) 그대로 유지.
- **TTS task barrier**: `stream_end` 전송 전에 모든 pending TTS task를 `asyncio.gather()`로 대기. `tts_chunk`가 `stream_end` 이후에 도착하는 race condition 방지.
- **`stream_token` 유지**: 기존 `stream_token` 이벤트는 그대로 전송. FE는 `stream_token`으로 텍스트 렌더링, `tts_chunk`로 오디오/모션 재생. 두 이벤트는 독립적으로 동작.

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
- YAML 로드 패턴은 기존 `text_processors.py`의 `tts_rules.yml` 로드 방식과 동일하게 구현

### 2.2 synthesize_chunk()

**File**: `src/services/tts_service/tts_pipeline.py`

```python
# Minimal valid silent MP3 frame (MPEG1 Layer3, 128kbps, 44100Hz, ~26ms)
# Reference: http://www.mp3-tech.org/programmer/frame_header.html
SILENT_MP3_BASE64: str = "<실제 valid MP3 frame의 base64 인코딩>"

async def synthesize_chunk(
    tts_service: TTSService,
    mapper: EmotionMotionMapper,
    text: str,
    emotion: str | None,
    sequence: int,
    tts_enabled: bool = True,
    reference_id: str | None = None,
) -> TtsChunkMessage:
    """
    항상 TtsChunkMessage를 반환한다. 실패 시에도 무음 audio로 반환.

    1. motion_name, blendshape_name = mapper.map(emotion)
    2. if tts_enabled:
           try:
               audio = await asyncio.to_thread(generate_speech(text, "base64", "mp3"))
               if audio is None → audio = SILENT_MP3_BASE64, set warning flag
           except Exception:
               audio = SILENT_MP3_BASE64, set warning flag
       else:
           audio = SILENT_MP3_BASE64  (skip TTS API call)
    3. Return TtsChunkMessage(sequence, text, audio, emotion, motion_name, blendshape_name)
       + warning_message if failure occurred
    """
```

**반환 타입**: 항상 `TtsChunkMessage` (또는 `tuple[TtsChunkMessage, WarningMessage | None]`). 절대 `None`을 반환하지 않음. FE 큐가 sequence gap으로 stall하는 것을 원천 방지.

**`reference_id` 전파 경로**: FE가 `chat_message`에 포함해서 전송. `handlers.py` → `ConversationTurn.metadata["reference_id"]` → `_synthesize_and_send()` → `synthesize_chunk()`. `reference_id`가 null이면 백엔드 기본값(설정 가능) 사용.

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
  "tts_enabled": true,
  "reference_id": "ナツメ"
}
```

- `tts_enabled: bool = True` — 기본값 `true`로 기존 클라이언트 하위 호환
- `reference_id: str | null = null` — TTS 음성 합성에 사용할 reference voice ID. null이면 백엔드 기본값 사용. 사용 가능한 값 목록은 `GET /v1/tts/voices`로 조회

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
- `text`: 기존 `tts_ready_chunk`의 `chunk` 필드를 `text`로 rename. 새 메시지 타입이므로 하위 호환 영향 없음.
- FE는 sequence 기반 priority queue로 순서대로 재생

**payload 크기 참고**: 3초 분량 128kbps MP3 ≈ 48KB raw → ~64KB base64. Turn당 5~10 청크 기준 320~640KB. WebSocket 전송에 문제 없는 수준. 추후 binary WebSocket frame으로 최적화 가능하나 현재 scope 외.

### 3.3 GET /v1/tts/voices — New REST API

사용 가능한 `reference_id` 목록을 반환한다.

```
GET /v1/tts/voices
→ 200 OK
{
  "voices": ["ナツメ", "Alice", "Bob"]
}
```

**구현**: VLLMOmniTTS의 `ref_audio_dir/` 하위 디렉토리명을 스캔해서 반환. 각 디렉토리는 `merged_audio.mp3` + `combined.lab`을 포함해야 유효한 voice로 인정.

FishSpeech는 `reference_id` 스캔 방식이 다를 수 있으므로, `TTSService`에 `list_voices() -> list[str]` 추상 메서드를 추가해 구현체별로 처리.

**Unity 사용 흐름**: 앱 시작 → `GET /v1/tts/voices` 호출 → 목소리 목록 UI 표시 → 유저 선택 → 이후 `chat_message`에 `reference_id` 포함

### 3.4 warning (BE → FE) — New

```json
{
  "type": "warning",
  "code": "TTS_SYNTHESIS_FAILED",
  "message": "TTS synthesis failed for chunk 3, sending silent audio"
}
```

### 3.4 tts_ready_chunk — Deprecated

- 코드에서 즉시 삭제하지 않음
- `tts_chunk`만 전송, `tts_ready_chunk`는 전송하지 않음

### 3.5 MessageType Enum Additions

```python
TTS_CHUNK = "tts_chunk"
WARNING = "warning"
```

---

## 4. File-Level Changes

### 4.1 Modified Files

| File | Change |
| --- | --- |
| `src/models/websocket.py` | `ChatMessage.tts_enabled`, `ChatMessage.reference_id` 추가, `TtsChunkMessage`/`WarningMessage` 모델 추가, `MessageType` enum 추가 |
| `src/services/websocket_service/message_processor/event_handlers.py` | `_build_tts_event()` → `_synthesize_and_send()` 교체, sequence 카운터, `tts_tasks: list[asyncio.Task]` 추가, `_flush_tts_buffer()`도 동일하게 async TTS 적용 |
| `src/services/websocket_service/message_processor/processor.py` | `EventHandler` 생성 시 `tts_service`, `EmotionMotionMapper` 전달, `tts_enabled` 전파, `stream_end` 전송 전 TTS task barrier 추가 |
| `src/services/websocket_service/message_processor/models.py` | `ConversationTurn.tts_enabled: bool`, `ConversationTurn.tts_tasks: list[asyncio.Task]` 추가 |
| `src/services/websocket_service/manager/handlers.py` | `chat_message`에서 `tts_enabled` 추출, MessageProcessor에 전달 |
| `src/api/routes/tts.py` | `POST /v1/tts/synthesize` deprecation 헤더/주석 추가, `GET /v1/tts/voices` 신규 엔드포인트 추가 |
| `src/services/tts_service/service.py` | `list_voices() -> list[str]` 추상 메서드 추가 |
| `src/services/tts_service/vllm_omni.py` | `list_voices()` 구현 — `ref_audio_dir/` 하위 유효 디렉토리 스캔 |
| `src/services/tts_service/fish_speech.py` | `list_voices()` 구현 — 빈 리스트 반환 (Fish Speech는 reference voice 개념 없음) |
| `yaml_files/tts_rules.yml` | `emotion_motion_map` 섹션 추가 |

### 4.2 New Files

| File | Purpose |
| --- | --- |
| `src/services/tts_service/emotion_motion_mapper.py` | Emotion → motion/blendshape dummy 매핑 |
| `src/services/tts_service/tts_pipeline.py` | `synthesize_chunk()` async 파이프라인 + `SILENT_MP3_BASE64` 상수 |

### 4.3 Unchanged

- `TTSService` ABC 및 구현체 (`fish_speech.py`, `vllm_omni.py`)
- `TTSTextProcessor`, `TextChunkProcessor`
- `openai_chat_agent.py`
- `tts_factory.py`, `service_manager.py`

---

## 5. Dependency Injection & Propagation

### 5.1 tts_service / EmotionMotionMapper 주입

기존 코드 패턴을 따른다. `handlers.py`에서 `get_tts_service()` 서비스 로케이터 패턴 사용 (기존 `get_agent_service()`, `get_stm_service()` 패턴과 동일).

```text
handlers.py:
  tts_service = get_tts_service()
  mapper = get_emotion_motion_mapper()  # service_manager.py에 등록

processor.py:
  MessageProcessor.__init__(tts_service, mapper)

event_handlers.py:
  EventHandler.__init__(processor)  ← processor.tts_service, processor.mapper 참조
```

`EmotionMotionMapper`는 `service_manager.py`에서 앱 시작 시 초기화, 싱글턴으로 관리.

### 5.2 tts_enabled 전파 체인

```text
1. FE → WS: chat_message { tts_enabled: true }
2. handlers.py: data.get("tts_enabled", True) 추출
3. processor.start_turn(tts_enabled=tts_enabled)
4. ConversationTurn(tts_enabled=tts_enabled)
5. EventHandler._process_token_event() → turn.tts_enabled 참조
6. _synthesize_and_send(tts_enabled=turn.tts_enabled)
7. synthesize_chunk(tts_enabled=tts_enabled)
```

---

## 6. Error Handling

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

- **항상 `tts_chunk` 전송**: 실패해도, tts_enabled=false여도 해당 sequence의 `tts_chunk` 전송. FE 큐 stall 방지.
- `warning`은 `tts_chunk` 직전에 전송

### TTS Task Barrier (stream_end 순서 보장)

```text
1. 토큰 스트리밍 중:
   _process_token_event() → asyncio.create_task(_synthesize_and_send())
   → task를 turn.tts_tasks에 append

2. 토큰 스트리밍 완료 (sentinel 수신):
   _flush_tts_buffer() → 마지막 청크도 create_task()

3. stream_end 전송 전:
   await asyncio.gather(*turn.tts_tasks, return_exceptions=True)
   → 모든 tts_chunk가 FE에 전송된 후에만 stream_end 전송
```

이 barrier가 없으면 TTS 생성이 느린 마지막 청크의 `tts_chunk`가 `stream_end` 이후에 도착하여 FE가 drop하는 race condition 발생.

### tts_enabled=False

- TTS 서비스 호출을 스킵 (API 비용/latency 절약)
- `tts_chunk`는 **전송함** — `audio_base64 = SILENT_MP3_BASE64`, emotion/motion/blendshape는 정상 전달
- Unity가 motion/expression 애니메이션을 계속 재생할 수 있도록 보장
- 음성만 무음이고 캐릭터 움직임은 유지되는 "무음 모드"

### 연결 끊김 도중 TTS task

- 이벤트 큐 put 시 `is_closing` 플래그 체크 → 닫혔으면 조용히 drop
- TTS task는 `ConversationTurn.tasks` + `tts_tasks` 모두에서 관리 → turn 종료 시 일괄 cancel

### Concurrent Turn (4002)

- 기존 concurrent turn protection 그대로 유지
- 첫 번째 turn의 TTS task들이 아직 돌고 있어도 turn cancel 시 함께 cancel

---

## 7. Configuration

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

## 8. Testing

### Unit Tests

| Target | Cases |
| --- | --- |
| `EmotionMotionMapper` | 등록 emotion → 올바른 반환, 미등록 → default, None → default |
| `synthesize_chunk()` | 정상 → TtsChunkMessage (실제 audio), generate_speech None → TtsChunkMessage (무음 audio) + warning, exception → TtsChunkMessage (무음 audio) + warning, tts_enabled=False → TtsChunkMessage (무음 audio, TTS 미호출) |
| `EventHandler._synthesize_and_send()` | tts_enabled=True + 정상 → 큐에 tts_chunk (실제 audio), 실패 → warning + 무음 tts_chunk, tts_enabled=False → 큐에 tts_chunk (무음 audio + motion 정상), is_closing → drop |
| `ChatMessage` model | tts_enabled 미전송 → True, False 명시 → 정상 파싱 |
| TTS task barrier | 모든 TTS task 완료 전 stream_end 미전송 확인 |

### Integration Tests

| Test | Verification |
| --- | --- |
| WS chat_message { tts_enabled: true } | `tts_chunk` 수신, sequence 순서, audio_base64 유효성, `stream_end`가 마지막 `tts_chunk` 이후 도착 |
| WS chat_message { tts_enabled: false } | `tts_chunk` 수신, audio_base64가 무음, emotion/motion/blendshape 정상 |
| `stream_token` + `tts_chunk` 공존 | 두 이벤트 모두 수신되는지 확인 |

### Not Tested

- `generate_speech()` 내부 (기존 TTS 서비스 테스트 커버)
- `TextChunkProcessor`, `TTSTextProcessor` (기존 테스트 유지)
- Unity 측 재생 로직

---

## 9. Documentation Updates

| Document | Change |
| --- | --- |
| `docs/data_flow/chat/ADD_CHAT_MESSAGE.md` | 다이어그램 전면 수정: tts_chunk, stream_end 순서, images 형식, tts_enabled |
| `docs/websocket/WEBSOCKET_API_GUIDE.md` | `tts_ready_chunk` deprecated, `tts_chunk`/`warning` 추가 |
| `docs/api/TTS_Synthesize.md` | Deprecated 표기 |
| `docs/websocket/WebSocket_ChatMessage.md` | `tts_enabled`, `reference_id` 필드 문서화 |
| `docs/api/TTS_Voices.md` | `GET /v1/tts/voices` 신규 API 문서 |

---

## 10. Unity (FE) Impact

Backend 변경에 따른 Unity 측 필요 작업 (이 Spec 범위 외, 참고용):

**제거:**

- `tts_ready_chunk` 핸들러
- `POST /v1/tts/synthesize` HTTP 호출 코드
- emotion → motion/blendshape 결정 로직

**추가:**

- 앱 시작 시 `GET /v1/tts/voices` 호출 → 목소리 선택 UI 제공
- `chat_message` 전송 시 `tts_enabled`, `reference_id` 필드 포함
- `tts_chunk` 핸들러: sequence 기반 priority queue → audio_base64 디코딩 → 재생
- `warning` 핸들러: 코드/메시지 로깅

---

## Appendix

- [Current Data Flow](../../data_flow/chat/ADD_CHAT_MESSAGE.md)
- [WebSocket API Guide](../../websocket/WEBSOCKET_API_GUIDE.md)
- [TTS Synthesize API](../../api/TTS_Synthesize.md)
- [Agent Service](../../feature/service/Agent_Service.md)
