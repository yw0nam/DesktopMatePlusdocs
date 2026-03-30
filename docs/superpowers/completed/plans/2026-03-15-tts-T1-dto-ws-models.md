# T1: DTO & WebSocket 모델 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update WebSocket message models for new TTS flow and delete legacy models

**Architecture:** Modify `src/models/websocket.py` to add `tts_enabled`/`reference_id` to `ChatMessage`, introduce `TtsChunkMessage`, update `MessageType` enum, and delete `TTSReadyChunkMessage`/`WarningMessage`. Update all references across the codebase.

**Tech Stack:** Python 3.13, Pydantic v2, pytest, uv

---

## Chunk 1: 테스트 파일 생성 — `ChatMessage` 신규 필드

**Files:**
- Create: `backend/tests/models/test_websocket_models.py` (신규)

### Step 1-1: 테스트 디렉터리 및 `__init__.py` 확인

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
ls tests/
```

Expected: `models/` 디렉터리가 없는 경우 생성 필요 (`tests/models/__init__.py`)

- [ ] `tests/models/` 디렉터리 및 `__init__.py` 생성

```bash
mkdir -p tests/models
touch tests/models/__init__.py
```

### Step 1-2: `ChatMessage` 기본값 테스트 작성 (RED)

`tests/models/test_websocket_models.py` 파일을 아래 내용으로 생성:

```python
"""Unit tests for WebSocket message models."""

import pytest
from pydantic import ValidationError

from src.models.websocket import ChatMessage, MessageType, TtsChunkMessage


class TestChatMessageDefaults:
    """ChatMessage backward-compat and new field defaults."""

    def test_tts_enabled_default_is_true(self):
        """tts_enabled defaults to True when not supplied — backward compat."""
        msg = ChatMessage(content="hello", agent_id="a1", user_id="u1")
        assert msg.tts_enabled is True

    def test_reference_id_default_is_none(self):
        """reference_id defaults to None when not supplied."""
        msg = ChatMessage(content="hello", agent_id="a1", user_id="u1")
        assert msg.reference_id is None

    def test_tts_enabled_can_be_set_false(self):
        """Client can explicitly disable TTS."""
        msg = ChatMessage(
            content="hello", agent_id="a1", user_id="u1", tts_enabled=False
        )
        assert msg.tts_enabled is False

    def test_reference_id_can_be_set(self):
        """Client can specify a TTS voice reference."""
        msg = ChatMessage(
            content="hello",
            agent_id="a1",
            user_id="u1",
            reference_id="ナツメ",
        )
        assert msg.reference_id == "ナツメ"

    def test_existing_fields_still_work(self):
        """Existing ChatMessage fields remain functional (backward compat)."""
        msg = ChatMessage(
            content="hello",
            agent_id="agent-001",
            user_id="user-001",
            limit=5,
        )
        assert msg.content == "hello"
        assert msg.agent_id == "agent-001"
        assert msg.user_id == "user-001"
        assert msg.limit == 5
        assert msg.type == MessageType.CHAT_MESSAGE

    def test_serialization_includes_new_fields(self):
        """model_dump() includes tts_enabled and reference_id."""
        msg = ChatMessage(
            content="hello",
            agent_id="a1",
            user_id="u1",
            tts_enabled=True,
            reference_id="voice-x",
        )
        data = msg.model_dump()
        assert "tts_enabled" in data
        assert "reference_id" in data
        assert data["tts_enabled"] is True
        assert data["reference_id"] == "voice-x"
```

### Step 1-3: 테스트 실행 → RED 확인

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/models/test_websocket_models.py::TestChatMessageDefaults -v
```

Expected (RED): `AttributeError` 또는 `ValidationError` — `tts_enabled` 필드가 없으므로 실패

---

## Chunk 2: `ChatMessage` 신규 필드 구현

**Files:**
- Modify: `backend/src/models/websocket.py`

### Step 2-1: `ChatMessage`에 필드 추가

`src/models/websocket.py`의 `ChatMessage` 클래스 내 `metadata` 필드 아래에 두 필드 추가:

```python
    tts_enabled: bool = Field(
        default=True,
        description="Whether TTS synthesis is enabled for this message. Defaults to True for backward compatibility.",
    )
    reference_id: Optional[str] = Field(
        default=None,
        description="TTS voice reference ID. Uses engine default when None.",
    )
```

### Step 2-2: 테스트 실행 → GREEN 확인

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/models/test_websocket_models.py::TestChatMessageDefaults -v
```

Expected (GREEN): 모든 `TestChatMessageDefaults` 테스트 통과

---

## Chunk 3: `TtsChunkMessage` 신규 클래스 테스트 작성 (RED)

**Files:**
- Modify: `backend/tests/models/test_websocket_models.py`

### Step 3-1: `TtsChunkMessage` 테스트 추가

`tests/models/test_websocket_models.py`에 아래 클래스 추가:

```python
class TestTtsChunkMessage:
    """TtsChunkMessage validation and field tests."""

    def test_required_fields(self):
        """sequence, text, motion_name, blendshape_name are required."""
        msg = TtsChunkMessage(
            sequence=0,
            text="Hello world!",
            motion_name="idle",
            blendshape_name="aa",
        )
        assert msg.sequence == 0
        assert msg.text == "Hello world!"
        assert msg.motion_name == "idle"
        assert msg.blendshape_name == "aa"
        assert msg.type == MessageType.TTS_CHUNK

    def test_audio_base64_optional_none(self):
        """audio_base64 is None by default (TTS disabled or failed)."""
        msg = TtsChunkMessage(
            sequence=0,
            text="Hi",
            motion_name="idle",
            blendshape_name="aa",
        )
        assert msg.audio_base64 is None

    def test_audio_base64_can_be_set(self):
        """audio_base64 accepts a base64 string."""
        msg = TtsChunkMessage(
            sequence=1,
            text="Hi",
            audio_base64="SGVsbG8=",
            motion_name="talking",
            blendshape_name="oh",
        )
        assert msg.audio_base64 == "SGVsbG8="

    def test_emotion_optional_none(self):
        """emotion is None by default."""
        msg = TtsChunkMessage(
            sequence=0,
            text="Hi",
            motion_name="idle",
            blendshape_name="aa",
        )
        assert msg.emotion is None

    def test_emotion_can_be_set(self):
        """emotion accepts a string tag."""
        msg = TtsChunkMessage(
            sequence=0,
            text="That is fun.",
            emotion="laughing",
            motion_name="laugh",
            blendshape_name="ee",
        )
        assert msg.emotion == "laughing"

    def test_sequence_is_required(self):
        """Omitting sequence raises ValidationError."""
        with pytest.raises(ValidationError):
            TtsChunkMessage(
                text="Hi",
                motion_name="idle",
                blendshape_name="aa",
            )

    def test_type_is_tts_chunk(self):
        """type field is TTS_CHUNK enum value."""
        msg = TtsChunkMessage(
            sequence=0,
            text="Hi",
            motion_name="idle",
            blendshape_name="aa",
        )
        assert msg.type == MessageType.TTS_CHUNK

    def test_serialization(self):
        """model_dump_json() produces correct JSON including all fields."""
        msg = TtsChunkMessage(
            sequence=2,
            text="Hello.",
            audio_base64=None,
            emotion=None,
            motion_name="idle",
            blendshape_name="aa",
        )
        data = msg.model_dump()
        assert data["type"] == "tts_chunk"
        assert data["sequence"] == 2
        assert data["text"] == "Hello."
        assert data["audio_base64"] is None
        assert data["emotion"] is None
        assert data["motion_name"] == "idle"
        assert data["blendshape_name"] == "aa"
```

### Step 3-2: 테스트 실행 → RED 확인

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/models/test_websocket_models.py::TestTtsChunkMessage -v
```

Expected (RED): `ImportError` — `TtsChunkMessage`와 `MessageType.TTS_CHUNK`이 없으므로 실패

---

## Chunk 4: `MessageType` 업데이트 + `TtsChunkMessage` 구현

**Files:**
- Modify: `backend/src/models/websocket.py`

### Step 4-1: `MessageType` enum 수정

`MessageType` enum에서:
- `TTS_READY_CHUNK = "tts_ready_chunk"` 라인을 삭제
- `TTS_CHUNK = "tts_chunk"` 를 Server → Client 섹션에 추가

변경 후 Server → Client 섹션:

```python
    # Server -> Client
    AUTHORIZE_SUCCESS = "authorize_success"
    AUTHORIZE_ERROR = "authorize_error"
    PING = "ping"
    STREAM_START = "stream_start"
    STREAM_TOKEN = "stream_token"
    STREAM_END = "stream_end"
    TTS_CHUNK = "tts_chunk"
    TOOL_CALL = "tool_call"
    TOOL_RESULT = "tool_result"
    ERROR = "error"
    AVATAR_CONFIG_FILES = "avatar_config_files"
    AVATAR_CONFIG_SWITCHED = "avatar_config_switched"
    SET_MODEL_AND_CONF = "set_model_and_conf"
```

### Step 4-2: `TtsChunkMessage` 클래스 추가 + `TTSReadyChunkMessage` 삭제

`TTSReadyChunkMessage` 클래스 전체를 아래 `TtsChunkMessage`로 **대체**:

```python
class TtsChunkMessage(BaseMessage):
    """Server message with TTS synthesis result and motion metadata.

    Backend → Unity. Sent after TTS synthesis completes for each sentence.
    audio_base64 is None when TTS is disabled (tts_enabled=False) or synthesis failed.
    """

    type: MessageType = MessageType.TTS_CHUNK
    sequence: int = Field(..., description="Sequence number within the turn, starting from 0")
    text: str = Field(..., description="Text used for TTS synthesis")
    audio_base64: Optional[str] = Field(
        default=None,
        description="MP3 audio encoded as base64. None means skip audio playback.",
    )
    emotion: Optional[str] = Field(default=None, description="Detected emotion tag")
    motion_name: str = Field(..., description="Unity AnimationPlayer motion to play")
    blendshape_name: str = Field(..., description="Unity blendshape to apply")
```

### Step 4-3: `ServerMessage` Union 업데이트

`ServerMessage` Union에서 `TTSReadyChunkMessage`를 `TtsChunkMessage`로 교체:

```python
ServerMessage = Union[
    AuthorizeSuccessMessage,
    AuthorizeErrorMessage,
    PingMessage,
    StreamStartMessage,
    StreamTokenMessage,
    ToolCallMessage,
    ToolResultMessage,
    StreamEndMessage,
    TtsChunkMessage,
    ErrorMessage,
]
```

### Step 4-4: 테스트 실행 → GREEN 확인

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/models/test_websocket_models.py -v
```

Expected (GREEN): `TestChatMessageDefaults`와 `TestTtsChunkMessage` 모두 통과

---

## Chunk 5: 레거시 참조 제거 확인

**Files:**
- Check: `backend/src/` 전체

### Step 5-1: 남은 `TTS_READY_CHUNK` / `TTSReadyChunkMessage` 참조 전체 검색

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
grep -rn "TTS_READY_CHUNK\|TTSReadyChunkMessage\|tts_ready_chunk" src/ --include="*.py"
```

Expected 결과:
- `src/models/websocket.py` — 삭제되었으므로 0건
- `src/services/websocket_service/message_processor/event_handlers.py` — `"tts_ready_chunk"` 문자열만 남음 → T4에서 처리 예정
- 그 외 다른 파일: 0건

> **중요**: `event_handlers.py`는 내부적으로 Python dict를 사용하며 `TTSReadyChunkMessage` 클래스를 직접 import하지 않습니다. T1에서 해당 클래스를 삭제해도 컴파일 에러가 발생하지 않습니다. `"tts_ready_chunk"` 문자열 교체는 T4 범위입니다.

### Step 5-2: 기존 웹소켓 테스트 통과 확인

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/websocket/ -v
```

Expected (GREEN): 모든 websocket 테스트 통과

---

## Chunk 6: 전체 테스트 + lint + 커밋

### Step 6-1: 전체 테스트 실행

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest -v
```

Expected (GREEN): 전체 통과. 실패 시 `ImportError: cannot import name 'TTSReadyChunkMessage'` 확인 후 해당 파일에서 import 제거.

### Step 6-2: lint 실행

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
sh scripts/lint.sh
```

Expected: ruff 오류 0건

### Step 6-3: 커밋

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add src/models/websocket.py tests/models/__init__.py tests/models/test_websocket_models.py
git commit -m "feat(models): add TtsChunkMessage, tts_enabled/reference_id to ChatMessage, remove TTSReadyChunkMessage"
```

---

## 변경 요약

| 항목 | 변경 유형 | 비고 |
|------|-----------|------|
| `MessageType.TTS_READY_CHUNK` | 삭제 | `MessageType.TTS_CHUNK` 추가 |
| `ChatMessage.tts_enabled` | 신규 필드 | `bool = True` (하위 호환) |
| `ChatMessage.reference_id` | 신규 필드 | `Optional[str] = None` |
| `TtsChunkMessage` | 신규 클래스 | `TTSReadyChunkMessage` 대체 |
| `TTSReadyChunkMessage` | 삭제 | `ServerMessage` Union에서도 제거 |
| `WarningMessage` | 해당 없음 | 현재 코드에 존재하지 않음 |
| `MessageType.WARNING` | 해당 없음 | 현재 코드에 존재하지 않음 |
| `tests/models/test_websocket_models.py` | 신규 | `ChatMessage` + `TtsChunkMessage` 단위 테스트 |

## T4 의존 사항 (T1에서 처리하지 않는 것)

- `event_handlers.py`의 `_build_tts_event()` 내 `"tts_ready_chunk"` 딕셔너리 이벤트 → T4에서 제거
- `test_websocket_service.py`의 `"tts_ready_chunk"` assertion → T4에서 `"tts_chunk"` 로 전환
- `examples/realtime_tts_streaming_demo.py` → T5 완료 후 업데이트
