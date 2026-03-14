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
| `POST /v1/tts/synthesize` | 채팅 플로우 핵심 경로 | **즉시 삭제** |
| `tts_ready_chunk` | 전송됨 | **즉시 삭제** |
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
    → tts_chunk {seq, text, audio_base64|null, emotion, motion, blendshape} ──WS──→ Unity
  → await TTS task barrier with timeout
  → stream_end
  → Unity: queue & play
```

### 핵심 설계 결정

- **EventHandler 레벨**: 기존 `_build_tts_event()` 위치에서 TTS 생성을 끼워넣는다. Agent 레이어 무변경.
- **`asyncio.create_task()`**: TTS 생성은 텍스트 스트리밍과 병렬. 스트리밍을 블로킹하지 않는다.
- **`asyncio.to_thread()`**: `TTSService.generate_speech()`가 동기이므로 thread pool에서 실행.
- **기존 파이프라인 재사용**: TextChunkProcessor (sentence split), TTSTextProcessor (emotion 추출) 그대로 유지.
- **TTS task barrier with timeout**: `stream_end` 전에 `asyncio.wait_for(asyncio.gather(...), timeout=N)`으로 대기. timeout 초과 시 pending task cancel + warning 전송 후 stream_end. deadlock 방지.
- **`audio_base64: null`**: TTS 실패 또는 `tts_enabled=False` 시 가짜 데이터 대신 `null` 전송. FE가 null이면 오디오 재생 스킵, motion/emotion은 정상 처리.
- **레거시 즉시 삭제**: `tts_ready_chunk`, `POST /v1/tts/synthesize` 새 플로우 구현과 동시에 삭제.
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
async def synthesize_chunk(
    tts_service: TTSService,
    mapper: EmotionMotionMapper,
    text: str,
    emotion: str | None,
    sequence: int,
    tts_enabled: bool = True,
    reference_id: str | None = None,
) -> tuple[TtsChunkMessage, WarningMessage | None]:
    """
    항상 (TtsChunkMessage, warning_or_None) 튜플을 반환한다.
    실패/비활성 시 audio_base64=None으로 반환. SILENT 데이터 없음.

    1. motion_name, blendshape_name = mapper.map(emotion)
    2. if tts_enabled:
           try:
               # asyncio.to_thread()는 callable + args 형태 (동기 함수를 thread pool에서 실행)
               audio = await asyncio.to_thread(
                   tts_service.generate_speech, text, reference_id, "base64", "mp3"
               )
               if audio is None → raise TTSSynthesisError
           except Exception as e:
               audio = None
               warning = WarningMessage(code="TTS_SYNTHESIS_FAILED", message=str(e))
       else:
           audio = None   # tts_enabled=False: FE가 오디오 재생 스킵, motion은 정상 처리
           warning = None
    3. Return (
           TtsChunkMessage(sequence, text, audio, emotion, motion_name, blendshape_name),
           warning
       )
    """
```

**`audio_base64` 설계**: `Optional[str]`. `null`이면 FE는 오디오 재생만 스킵하고 motion/emotion 처리는 그대로 진행. SILENT MP3 상수는 사용하지 않는다. FE의 null 처리가 명확하고 테스트 가능한 계약.

**`reference_id` 전파 경로**: FE가 `chat_message`에 포함해서 전송. `handlers.py` → `ConversationTurn.metadata["reference_id"]` → `_synthesize_and_send()` → `synthesize_chunk()`. `reference_id`가 null이면 TTS 엔진 기본값 사용.

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
- `reference_id: str | null = null` — TTS 음성 합성에 사용할 reference voice ID. null이면 TTS 엔진 기본값 사용. 사용 가능한 값 목록은 `GET /v1/tts/voices`로 조회

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

실패/비활성 시:

```json
{
  "type": "tts_chunk",
  "sequence": 0,
  "text": "안녕하세요!",
  "audio_base64": null,
  "emotion": "joyful",
  "motion_name": "happy_idle",
  "blendshape_name": "smile"
}
```

- `sequence`: FE 재생 순서 보장용 정수 (0부터 시작, turn 내 증가)
- `audio_base64: Optional[str]`: MP3 포맷 base64. `null`이면 FE는 오디오 재생 스킵, motion/emotion은 정상 처리
- `text`: 기존 `tts_ready_chunk`의 `chunk` 필드를 `text`로 rename
- FE는 sequence 기반 priority queue로 순서대로 재생

**payload 크기 참고**: 3초 분량 128kbps MP3 ≈ 48KB raw → ~64KB base64. 추후 binary WebSocket frame으로 최적화 가능하나 현재 scope 외.

### 3.3 GET /v1/tts/voices — New REST API

사용 가능한 `reference_id` 목록을 반환한다.

```text
GET /v1/tts/voices
→ 200 OK
{ "voices": ["ナツメ", "Alice", "Bob"] }
```

**구현**: VLLMOmniTTS의 `ref_audio_dir/` 하위 디렉토리명을 스캔해서 반환. 각 디렉토리는 `merged_audio.mp3` + `combined.lab`을 포함해야 유효한 voice로 인정.

FishSpeech는 `reference_id` 스캔 방식이 다를 수 있으므로, `TTSService`에 `list_voices() -> list[str]` 추상 메서드를 추가해 구현체별로 처리.

**에러 응답**:

- `503 Service Unavailable`: TTS 서비스 미초기화 (기존 패턴과 동일)
- `ref_audio_dir` 미존재 시: 빈 리스트 반환 (`{"voices": []}`) — 예외 발생 없음

**Unity 사용 흐름**: 앱 시작 → `GET /v1/tts/voices` 호출 → 목소리 목록 UI 표시 → 유저 선택 → 이후 `chat_message`에 `reference_id` 포함

### 3.4 warning (BE → FE) — New

```json
{
  "type": "warning",
  "code": "TTS_SYNTHESIS_FAILED",
  "message": "TTS synthesis failed for chunk 3"
}
```

TTS barrier timeout 초과 시 code: `TTS_BARRIER_TIMEOUT`.

### 3.5 Deleted Messages

- `tts_ready_chunk` — 새 플로우 구현과 동시에 **즉시 삭제**
- `POST /v1/tts/synthesize` REST endpoint — **즉시 삭제**

### 3.6 MessageType Enum

```python
TTS_CHUNK = "tts_chunk"
WARNING = "warning"
# 삭제:
# TTS_READY_CHUNK = "tts_ready_chunk"
```

---

## 4. File-Level Changes

### 4.1 Modified Files

| File | Change |
| --- | --- |
| `src/models/websocket.py` | `ChatMessage.tts_enabled`, `ChatMessage.reference_id` 추가. `TtsChunkMessage`(`audio_base64: Optional[str]`)/`WarningMessage` 추가. `TTS_READY_CHUNK` enum 삭제. |
| `src/services/websocket_service/message_processor/event_handlers.py` | `_build_tts_event()` → `_synthesize_and_send()` 교체. sequence 카운터. `_flush_tts_buffer()`도 동일하게 async TTS 적용. 각 task를 `turn.tts_tasks`와 `_task_manager.track_task()` 양쪽에 등록. |
| `src/services/websocket_service/message_processor/processor.py` | `EventHandler` 생성 시 `tts_service`, `EmotionMotionMapper` 전달. `tts_enabled`/`reference_id` 전파. `stream_end` 전송 전 timeout barrier 추가. `cleanup()`은 수정 불필요. |
| `src/services/websocket_service/message_processor/models.py` | `ConversationTurn`에 `tts_enabled: bool`, `reference_id: Optional[str]`, `tts_tasks: list[Task]` 필드 추가 |
| `src/services/websocket_service/manager/handlers.py` | `chat_message`에서 `tts_enabled`, `reference_id` 추출, MessageProcessor에 전달 |
| `src/api/routes/tts.py` | `POST /v1/tts/synthesize` **삭제**. `GET /v1/tts/voices` 신규 엔드포인트 추가. |
| `src/services/tts_service/service.py` | `list_voices() -> list[str]` 추상 메서드 추가 |
| `src/services/tts_service/vllm_omni.py` | `list_voices()` 구현 — `ref_audio_dir/` 하위 유효 디렉토리 스캔 |
| `src/services/tts_service/fish_speech.py` | `list_voices()` 구현 — 빈 리스트 반환 |
| `src/services/service_manager.py` | `initialize_emotion_motion_mapper()`, `get_emotion_motion_mapper()` 추가 |
| `yaml_files/tts_rules.yml` | `emotion_motion_map` 섹션 추가 |

### 4.2 Deleted Files / Code

| Target | Action |
| --- | --- |
| `src/models/websocket.py` — `TTSReadyChunkMessage` 클래스 | 삭제 |
| `src/api/routes/tts.py` — `POST /v1/tts/synthesize` 핸들러 및 모델 | 삭제 |
| `src/models/tts.py` — `TTSRequest`, `TTSResponse` (synthesize 전용) | 삭제 |
| `src/services/websocket_service/message_processor/event_handlers.py` — `_build_tts_event()` | 삭제 |

### 4.3 New Files

| File | Purpose |
| --- | --- |
| `src/services/tts_service/emotion_motion_mapper.py` | Emotion → motion/blendshape dummy 매핑 |
| `src/services/tts_service/tts_pipeline.py` | `synthesize_chunk()` async 파이프라인 |

### 4.4 Unchanged

- `TTSService` ABC 및 구현체 내 `generate_speech()` (인터페이스 유지)
- `TTSTextProcessor`, `TextChunkProcessor`
- `openai_chat_agent.py`
- `tts_factory.py`

---

## 5. Dependency Injection & Propagation

### 5.1 tts_service / EmotionMotionMapper 주입

기존 서비스 로케이터 패턴 사용 (`get_agent_service()`, `get_stm_service()` 패턴과 동일).

```text
handlers.py:
  tts_service = get_tts_service()
  mapper = get_emotion_motion_mapper()

processor.py:
  MessageProcessor.__init__(tts_service, mapper)

event_handlers.py:
  EventHandler.__init__(processor)  → processor.tts_service, processor.mapper 참조
```

```python
# service_manager.py에 추가
def initialize_emotion_motion_mapper() -> EmotionMotionMapper:
    """yaml_files/tts_rules.yml의 emotion_motion_map 섹션 로드.
    TTSTextProcessor의 tts_rules.yml 로드 방식과 동일한 loader 사용."""
    config = load_yaml("yaml_files/tts_rules.yml")
    return EmotionMotionMapper(config.get("emotion_motion_map", {}))

def get_emotion_motion_mapper() -> EmotionMotionMapper:
    return _emotion_motion_mapper_instance
```

### 5.2 tts_enabled / reference_id 전파 체인

```text
1. FE → WS: chat_message { tts_enabled: true, reference_id: "ナツメ" }
2. handlers.py: tts_enabled, reference_id 추출
3. processor.start_turn(tts_enabled=tts_enabled, reference_id=reference_id)
4. ConversationTurn(tts_enabled=tts_enabled, reference_id=reference_id)
5. EventHandler._process_token_event() → turn.tts_enabled, turn.reference_id 참조
6. _synthesize_and_send(tts_enabled=..., reference_id=...)
7. synthesize_chunk(tts_enabled=..., reference_id=...)
```

---

## 6. Error Handling

### TTS 생성 실패

```text
_synthesize_and_send(text, emotion, sequence, tts_enabled, reference_id):
  motion, blendshape = mapper.map(emotion)
  chunk_msg, warning = await synthesize_chunk(
      tts_service, mapper, text, emotion, sequence, tts_enabled, reference_id
  )
  if warning:
      → warning 이벤트 큐 put
  → tts_chunk 이벤트 큐 put  (audio_base64가 null이더라도 항상 전송)
```

- **항상 `tts_chunk` 전송**: 실패/스킵 시 `audio_base64=null`로 전송. FE 큐의 sequence gap 방지.
- `warning`은 `tts_chunk` 직전에 전송.

### TTS Task Barrier with Timeout (stream_end 순서 보장)

```text
1. 토큰 스트리밍 중:
   _process_token_event() → asyncio.create_task(_synthesize_and_send())
   → task를 turn.tts_tasks에 append + _task_manager.track_task(task)

2. 토큰 스트리밍 완료:
   _flush_tts_buffer() → 마지막 청크도 동일하게 create_task()

3. stream_end 전송 전:
   try:
       await asyncio.wait_for(
           asyncio.gather(*turn.tts_tasks, return_exceptions=True),
           timeout=TTS_BARRIER_TIMEOUT_SECONDS  # 설정 가능, 기본 10초
       )
   except asyncio.TimeoutError:
       # 초과된 task cancel
       for task in turn.tts_tasks:
           task.cancel()
       → warning 전송 (code: TTS_BARRIER_TIMEOUT)
   → stream_end 전송
```

`TTS_BARRIER_TIMEOUT_SECONDS`는 `yaml_files/main.yml`의 websocket 섹션에 추가.

### tts_enabled=False ("무음 모드")

- TTS API 호출 스킵 → `audio_base64=null`
- `tts_chunk`는 **전송함** — emotion/motion/blendshape 정상 전달
- Unity: 오디오 재생만 스킵, 캐릭터 motion/expression 애니메이션 유지

### 연결 끊김 도중 TTS task

- 이벤트 큐 put 시 `is_closing` 플래그 체크 → 닫혔으면 조용히 drop
- TTS task는 `_task_manager.track_task()`를 통해 `turn.tasks`에 등록 → 기존 `cleanup()` 로직으로 자동 cancel

---

## 7. Configuration

### yaml_files/main.yml — 추가

```yaml
websocket:
  # ... 기존 필드 ...
  tts_barrier_timeout_seconds: 10.0  # TTS task barrier 타임아웃 (초)
```

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
| `synthesize_chunk()` | 정상 → (TtsChunkMessage with audio, None), generate_speech None → (TtsChunkMessage with null audio, WarningMessage), exception → (null audio, warning), tts_enabled=False → (null audio, None, TTS 미호출 확인) |
| `EventHandler._synthesize_and_send()` | 정상 → 큐에 tts_chunk(null 아닌 audio), 실패 → warning + null audio tts_chunk, tts_enabled=False → null audio tts_chunk + motion 정상, is_closing → drop |
| TTS task barrier | 정상 완료 → stream_end 마지막, timeout → warning(TTS_BARRIER_TIMEOUT) + stream_end 강제 전송 |
| `ChatMessage` model | tts_enabled 미전송 → True, reference_id 미전송 → None |

**모킹 필수**: `generate_speech`는 외부 TTS 엔진 호출이므로 단위 테스트에서 `AsyncMock` / `MagicMock`으로 완전히 모킹. CI/CD에서 실제 TTS 엔진에 의존하지 않음.

### Integration Tests

| Test | Verification |
| --- | --- |
| `tts_enabled: true`, TTS 정상 | `tts_chunk` 수신, audio_base64 비null, sequence 순서, `stream_end` 마지막 도착 |
| `tts_enabled: false` | `tts_chunk` 수신, audio_base64 null, emotion/motion/blendshape 정상 |
| TTS 실패 시뮬레이션 | `warning` 수신 후 `tts_chunk`(null audio) 수신 |
| barrier timeout | warning(TTS_BARRIER_TIMEOUT) + stream_end 도착 확인 |
| `stream_token` + `tts_chunk` 공존 | 두 이벤트 모두 수신 확인 |

### Not Tested

- `generate_speech()` 내부 (기존 TTS 서비스 테스트 커버)
- `TextChunkProcessor`, `TTSTextProcessor` (기존 테스트 유지)
- Unity 측 재생 로직

---

## 9. Implementation Task Breakdown

리드 아키텍트 권고 기준 5개 독립 태스크.

| Task | 내용 | 선행 조건 |
| --- | --- | --- |
| T1: DTO & WS 모델 | `ChatMessage` 필드 추가, `TtsChunkMessage`/`WarningMessage` 추가, `TTSReadyChunkMessage` 삭제, enum 업데이트 | 없음 |
| T2: 참조 API & Mapper | `GET /v1/tts/voices`, `list_voices()` ABC + 구현체, `EmotionMotionMapper`, `POST /v1/tts/synthesize` 삭제 | 없음 |
| T3: TTS 파이프라인 | `synthesize_chunk()` 구현, `asyncio.to_thread()` wrapping, 실패 시 null audio | T1 완료 |
| T4: EventHandler 통합 | `_build_tts_event()` → `_synthesize_and_send()` 교체, task 이중 등록, is_closing 체크 | T3 완료 |
| T5: Barrier & stream_end | `asyncio.wait_for` barrier, timeout + cancel + warning, `stream_end` 동기화 | T4 완료 |

T1, T2는 병렬 진행 가능.

---

## 10. Documentation Updates

| Document | Change |
| --- | --- |
| `docs/data_flow/chat/ADD_CHAT_MESSAGE.md` | 다이어그램 전면 수정: tts_chunk, stream_end 순서, images 형식, tts_enabled |
| `docs/websocket/WEBSOCKET_API_GUIDE.md` | `tts_ready_chunk` 삭제, `tts_chunk`/`warning` 추가 |
| `docs/api/TTS_Synthesize.md` | **삭제** (endpoint 자체 삭제) |
| `docs/websocket/WebSocket_ChatMessage.md` | `tts_enabled`, `reference_id` 필드 문서화 |
| `docs/api/TTS_Voices.md` | `GET /v1/tts/voices` 신규 API 문서 |

---

## 11. Unity (FE) Impact

Backend 변경에 따른 Unity 측 필요 작업 (이 Spec 범위 외, 참고용):

**제거:**

- `tts_ready_chunk` 핸들러
- `POST /v1/tts/synthesize` HTTP 호출 코드
- emotion → motion/blendshape 결정 로직

**추가:**

- 앱 시작 시 `GET /v1/tts/voices` 호출 → 목소리 선택 UI 제공
- `chat_message` 전송 시 `tts_enabled`, `reference_id` 필드 포함
- `tts_chunk` 핸들러: sequence 기반 priority queue → `audio_base64 != null`이면 디코딩 + 재생, null이면 재생 스킵 → motion/blendshape 항상 처리
- `warning` 핸들러: 코드/메시지 로깅

---

## Appendix

- [Current Data Flow](../../data_flow/chat/ADD_CHAT_MESSAGE.md)
- [WebSocket API Guide](../../websocket/WEBSOCKET_API_GUIDE.md)
- [Agent Service](../../feature/service/Agent_Service.md)
