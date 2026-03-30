# Backend TTS Migration: Unity → desktop-homunculus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Unity-specific TTS fields (`motion_name`, `blendshape_name`, MP3 audio) in `TtsChunkMessage` with desktop-homunculus compatible fields (`keyframes`, WAV audio).

**Architecture:** `EmotionMotionMapper.map()` is extended to return `list[TimelineKeyframe]` instead of a `(motion_name, blendshape_name)` tuple. `TtsChunkMessage` drops the two Unity fields and gains a `keyframes` field. `tts_pipeline.py` and `event_handlers.py` are updated to thread the new data through. Audio format changes from MP3 to WAV throughout.

**Tech Stack:** Python 3.13, FastAPI, Pydantic V2, pytest, uv

---

## File Map

| File | Change |
|---|---|
| `backend/src/models/websocket.py` | Add `TimelineKeyframe` type alias; replace `motion_name`/`blendshape_name` with `keyframes` in `TtsChunkMessage`; update docstring |
| `backend/src/services/tts_service/emotion_motion_mapper.py` | Change `map()` return type from `tuple[str, str]` to `list[TimelineKeyframe]`; update config structure |
| `backend/src/services/tts_service/tts_pipeline.py` | Change audio format `"mp3"` → `"wav"`; update `mapper.map()` call site; update `TtsChunkMessage` construction |
| `backend/src/services/websocket_service/message_processor/event_handlers.py` | Update `_synthesize_and_send()` dict to use `keyframes` instead of `motion_name`/`blendshape_name` |
| `backend/tests/models/test_websocket_models.py` | Update `TestTtsChunkMessage` tests to reflect new fields |
| `backend/tests/services/test_emotion_motion_mapper.py` | Update all tests to check `list[dict]` return instead of `tuple[str, str]` |
| `backend/tests/services/test_tts_pipeline.py` | Update tests to check `keyframes` field; assert WAV format passed to `generate_speech` |
| `backend/tests/core/test_event_handler_tts.py` | Update `TtsChunkMessage` fixture construction; assert `keyframes` in put_event dict |

---

## Task 1: Add `TimelineKeyframe` type and update `TtsChunkMessage` model

**Files:**
- Modify: `backend/src/models/websocket.py:209-228`
- Test: `backend/tests/models/test_websocket_models.py`

- [ ] **Step 1: Write failing tests for the new model shape**

Open `backend/tests/models/test_websocket_models.py` and **replace** the entire `TestTtsChunkMessage` class with:

```python
class TestTtsChunkMessage:
    def test_required_fields(self):
        msg = TtsChunkMessage(
            sequence=0,
            text="Hello!",
            keyframes=[],
        )
        assert msg.sequence == 0
        assert msg.type == MessageType.TTS_CHUNK

    def test_audio_base64_optional_none(self):
        msg = TtsChunkMessage(sequence=0, text="Hi", keyframes=[])
        assert msg.audio_base64 is None

    def test_audio_base64_can_be_set(self):
        msg = TtsChunkMessage(
            sequence=1,
            text="Hi",
            audio_base64="SGVsbG8=",
            keyframes=[{"duration": 0.5, "targets": {"happy": 1.0}}],
        )
        assert msg.audio_base64 == "SGVsbG8="

    def test_emotion_optional_none(self):
        msg = TtsChunkMessage(sequence=0, text="Hi", keyframes=[])
        assert msg.emotion is None

    def test_sequence_is_required(self):
        with pytest.raises(ValidationError):
            TtsChunkMessage(text="Hi", keyframes=[])

    def test_type_is_tts_chunk(self):
        msg = TtsChunkMessage(sequence=0, text="Hi", keyframes=[])
        assert msg.type == MessageType.TTS_CHUNK

    def test_keyframes_stores_list(self):
        kf = [{"duration": 0.3, "targets": {"neutral": 1.0}}]
        msg = TtsChunkMessage(sequence=0, text="Hi", keyframes=kf)
        assert msg.keyframes == kf

    def test_keyframes_empty_list(self):
        msg = TtsChunkMessage(sequence=0, text="Hi", keyframes=[])
        assert msg.keyframes == []

    def test_no_motion_name_field(self):
        msg = TtsChunkMessage(sequence=0, text="Hi", keyframes=[])
        assert not hasattr(msg, "motion_name")

    def test_no_blendshape_name_field(self):
        msg = TtsChunkMessage(sequence=0, text="Hi", keyframes=[])
        assert not hasattr(msg, "blendshape_name")

    def test_serialization(self):
        msg = TtsChunkMessage(
            sequence=2,
            text="Hello.",
            keyframes=[{"duration": 0.5, "targets": {"happy": 0.8}}],
        )
        data = msg.model_dump()
        assert data["type"] == "tts_chunk"
        assert data["audio_base64"] is None
        assert "keyframes" in data
        assert "motion_name" not in data
        assert "blendshape_name" not in data
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/models/test_websocket_models.py::TestTtsChunkMessage -v
```

Expected: Multiple FAILED — `motion_name` required, `keyframes` not found.

- [ ] **Step 3: Update `TtsChunkMessage` in `backend/src/models/websocket.py`**

Add the `TimelineKeyframe` type alias just before the `TtsChunkMessage` class. Then replace the class body.

Replace this block (lines 209–228):

```python
class TtsChunkMessage(BaseMessage):
    """Server message with TTS synthesis result and motion metadata.

    Backend → Unity. Sent after TTS synthesis completes for each sentence.
    audio_base64 is None when TTS is disabled (tts_enabled=False) or synthesis failed.
    """

    type: MessageType = MessageType.TTS_CHUNK
    sequence: int = Field(
        ..., description="Sequence number within the turn, starting from 0"
    )
    text: str = Field(..., description="Text used for TTS synthesis")
    audio_base64: Optional[str] = Field(
        default=None,
        description="MP3 audio encoded as base64. None means skip audio playback.",
    )
    emotion: Optional[str] = Field(default=None, description="Detected emotion tag")
    motion_name: str = Field(..., description="Unity AnimationPlayer motion to play")
    blendshape_name: str = Field(..., description="Unity blendshape to apply")
```

With:

```python
# TimelineKeyframe matches desktop-homunculus POST /vrm/{entity}/speech/timeline format.
# { "duration": float, "targets": { "expression_name": weight } }
TimelineKeyframe = dict[str, float | dict[str, float]]


class TtsChunkMessage(BaseMessage):
    """Server message with TTS synthesis result and keyframe animation metadata.

    Backend → desktop-homunculus. Sent after TTS synthesis completes for each sentence.
    audio_base64 is None when TTS is disabled (tts_enabled=False) or synthesis failed.
    keyframes drives the VRM expression timeline via POST /vrm/{entity}/speech/timeline.
    """

    type: MessageType = MessageType.TTS_CHUNK
    sequence: int = Field(
        ..., description="Sequence number within the turn, starting from 0"
    )
    text: str = Field(..., description="Text used for TTS synthesis")
    audio_base64: Optional[str] = Field(
        default=None,
        description="WAV audio encoded as base64. None means skip audio playback.",
    )
    emotion: Optional[str] = Field(default=None, description="Detected emotion tag")
    keyframes: list[TimelineKeyframe] = Field(
        ...,
        description=(
            "Expression timeline keyframes for desktop-homunculus VRM animation. "
            "Each entry: {duration: float, targets: {expression_name: weight}}."
        ),
    )
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/models/test_websocket_models.py::TestTtsChunkMessage -v
```

Expected: All PASSED.

- [ ] **Step 5: Run full model test file**

```bash
uv run pytest tests/models/test_websocket_models.py -v
```

Expected: All PASSED.

- [ ] **Step 6: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend add src/models/websocket.py tests/models/test_websocket_models.py
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend commit -m "feat: replace motion_name/blendshape_name with keyframes in TtsChunkMessage"
```

---

## Task 2: Update `EmotionMotionMapper` to return keyframes

**Files:**
- Modify: `backend/src/services/tts_service/emotion_motion_mapper.py`
- Test: `backend/tests/services/test_emotion_motion_mapper.py`

### Background

Currently `map()` returns `tuple[str, str]` — `(motion_name, blendshape_name)`. The new return type is `list[TimelineKeyframe]` — a list of dicts matching the desktop-homunculus timeline format. Each dict has `duration` (float) and `targets` (dict mapping expression name to blend weight float 0–1).

Example YAML config shape (to be set up in `yaml_files/`):
```yaml
joyful:
  keyframes:
    - duration: 0.3
      targets:
        happy: 1.0
default:
  keyframes:
    - duration: 0.3
      targets:
        neutral: 1.0
```

- [ ] **Step 1: Write failing tests**

Replace the entire content of `backend/tests/services/test_emotion_motion_mapper.py`:

```python
"""Unit tests for EmotionMotionMapper — keyframes return format."""

from src.services.tts_service.emotion_motion_mapper import EmotionMotionMapper

SAMPLE_CONFIG = {
    "joyful": {
        "keyframes": [{"duration": 0.3, "targets": {"happy": 1.0}}]
    },
    "sad": {
        "keyframes": [{"duration": 0.4, "targets": {"sad": 0.8}}]
    },
    "default": {
        "keyframes": [{"duration": 0.3, "targets": {"neutral": 1.0}}]
    },
}


class TestEmotionMotionMapperRegistered:
    def test_joyful_returns_keyframes(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        keyframes = mapper.map("joyful")
        assert keyframes == [{"duration": 0.3, "targets": {"happy": 1.0}}]

    def test_sad_returns_keyframes(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        keyframes = mapper.map("sad")
        assert keyframes == [{"duration": 0.4, "targets": {"sad": 0.8}}]


class TestEmotionMotionMapperDefault:
    def test_unregistered_emotion_returns_default(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        keyframes = mapper.map("unknown_emotion")
        assert keyframes == [{"duration": 0.3, "targets": {"neutral": 1.0}}]

    def test_none_emotion_returns_default(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        keyframes = mapper.map(None)
        assert keyframes == [{"duration": 0.3, "targets": {"neutral": 1.0}}]

    def test_empty_string_returns_default(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        keyframes = mapper.map("")
        assert keyframes == [{"duration": 0.3, "targets": {"neutral": 1.0}}]


class TestEmotionMotionMapperFallback:
    def test_missing_default_key_uses_hardcoded_fallback(self):
        config = {
            "joyful": {"keyframes": [{"duration": 0.3, "targets": {"happy": 1.0}}]}
        }
        mapper = EmotionMotionMapper(config)
        keyframes = mapper.map("unregistered")
        # Should return hardcoded default: neutral expression
        assert isinstance(keyframes, list)
        assert len(keyframes) == 1
        assert "targets" in keyframes[0]
        assert "neutral" in keyframes[0]["targets"]

    def test_empty_config_returns_hardcoded_fallback(self):
        mapper = EmotionMotionMapper({})
        keyframes = mapper.map(None)
        assert isinstance(keyframes, list)
        assert len(keyframes) >= 1

    def test_returns_list_type(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        result = mapper.map("joyful")
        assert isinstance(result, list)

    def test_multiple_keyframes_preserved(self):
        config = {
            "excited": {
                "keyframes": [
                    {"duration": 0.2, "targets": {"happy": 0.5}},
                    {"duration": 0.3, "targets": {"happy": 1.0}},
                ]
            },
            "default": {
                "keyframes": [{"duration": 0.3, "targets": {"neutral": 1.0}}]
            },
        }
        mapper = EmotionMotionMapper(config)
        keyframes = mapper.map("excited")
        assert len(keyframes) == 2
        assert keyframes[0]["duration"] == 0.2
        assert keyframes[1]["duration"] == 0.3
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_emotion_motion_mapper.py -v
```

Expected: FAILED — `map()` still returns `tuple[str, str]`.

- [ ] **Step 3: Rewrite `EmotionMotionMapper`**

Replace the entire content of `backend/src/services/tts_service/emotion_motion_mapper.py`:

```python
"""Emotion-to-keyframe mapper loaded from YAML config.

Config format:
    emotion_name:
      keyframes:
        - duration: 0.3
          targets:
            expression_name: weight   # float 0.0–1.0
    default:
      keyframes:
        - duration: 0.3
          targets:
            neutral: 1.0

Keyframe list format matches desktop-homunculus POST /vrm/{entity}/speech/timeline.
"""

from src.models.websocket import TimelineKeyframe

_HARDCODED_DEFAULT: list[TimelineKeyframe] = [
    {"duration": 0.3, "targets": {"neutral": 1.0}}
]


class EmotionMotionMapper:
    """Maps emotion keyword strings to desktop-homunculus timeline keyframes."""

    def __init__(self, config: dict[str, dict]):
        self._map = config
        default_entry = config.get("default", {})
        self._default: list[TimelineKeyframe] = (
            default_entry.get("keyframes") or _HARDCODED_DEFAULT
        )

    def map(self, emotion: str | None) -> list[TimelineKeyframe]:
        """Return keyframes list for the given emotion.

        Returns the default keyframes when emotion is None, empty, or unregistered.
        """
        entry = self._map.get(emotion) if emotion else None
        if entry is None:
            return self._default
        return entry.get("keyframes") or self._default
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_emotion_motion_mapper.py -v
```

Expected: All PASSED.

- [ ] **Step 5: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend add \
  src/services/tts_service/emotion_motion_mapper.py \
  tests/services/test_emotion_motion_mapper.py
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend commit -m "feat: change EmotionMotionMapper.map() to return keyframes list"
```

---

## Task 3: Update `tts_pipeline.py` — WAV format + keyframes

**Files:**
- Modify: `backend/src/services/tts_service/tts_pipeline.py`
- Test: `backend/tests/services/test_tts_pipeline.py`

### What changes

1. `generate_speech()` is called with `"wav"` instead of `"mp3"`.
2. `mapper.map(emotion)` now returns `list[TimelineKeyframe]` — no tuple unpacking.
3. `TtsChunkMessage(...)` is constructed with `keyframes=` instead of `motion_name=`/`blendshape_name=`.

- [ ] **Step 1: Write failing tests**

Replace the entire content of `backend/tests/services/test_tts_pipeline.py`:

```python
"""Tests for synthesize_chunk() TTS pipeline.

Note: asyncio_mode=auto (pyproject.toml) — @pytest.mark.asyncio decorator is NOT needed.
generate_speech() MUST be mocked in all tests — no real TTS engine in CI.
"""

from unittest.mock import MagicMock, call, patch

from src.services.tts_service.tts_pipeline import synthesize_chunk


async def test_synthesize_chunk_success():
    """TTS success: audio_base64 non-null, keyframes populated from mapper."""
    tts_service = MagicMock()
    tts_service.generate_speech.return_value = "base64encodedaudio=="
    mapper = MagicMock()
    mapper.map.return_value = [{"duration": 0.3, "targets": {"happy": 1.0}}]

    chunk = await synthesize_chunk(
        tts_service=tts_service,
        mapper=mapper,
        text="안녕",
        emotion="joyful",
        sequence=0,
        tts_enabled=True,
    )

    assert chunk.audio_base64 == "base64encodedaudio=="
    assert chunk.keyframes == [{"duration": 0.3, "targets": {"happy": 1.0}}]
    assert chunk.sequence == 0
    assert chunk.text == "안녕"
    assert chunk.emotion == "joyful"
    tts_service.generate_speech.assert_called_once()


async def test_synthesize_chunk_uses_wav_format():
    """generate_speech must be called with 'wav' audio format."""
    tts_service = MagicMock()
    tts_service.generate_speech.return_value = "wavbase64=="
    mapper = MagicMock()
    mapper.map.return_value = [{"duration": 0.3, "targets": {"neutral": 1.0}}]

    await synthesize_chunk(
        tts_service=tts_service,
        mapper=mapper,
        text="hello",
        emotion=None,
        sequence=0,
        tts_enabled=True,
    )

    # Fourth positional arg to generate_speech is the audio format
    args = tts_service.generate_speech.call_args
    positional = args[0] if args[0] else []
    keyword = args[1] if args[1] else {}
    audio_format = positional[3] if len(positional) > 3 else keyword.get("audio_format")
    assert audio_format == "wav", f"Expected 'wav', got {audio_format!r}"


async def test_synthesize_chunk_generate_speech_returns_none():
    """generate_speech returns None → audio=None, logger.error called once."""
    tts_service = MagicMock()
    tts_service.generate_speech.return_value = None
    mapper = MagicMock()
    mapper.map.return_value = [{"duration": 0.3, "targets": {"neutral": 1.0}}]

    with patch("src.services.tts_service.tts_pipeline.logger") as mock_logger:
        chunk = await synthesize_chunk(
            tts_service=tts_service,
            mapper=mapper,
            text="텍스트",
            emotion=None,
            sequence=1,
            tts_enabled=True,
        )

    assert chunk.audio_base64 is None
    assert chunk.sequence == 1
    assert chunk.keyframes == [{"duration": 0.3, "targets": {"neutral": 1.0}}]
    mock_logger.error.assert_called_once()


async def test_synthesize_chunk_exception():
    """generate_speech raises exception → audio=None, logger.error called once."""
    tts_service = MagicMock()
    tts_service.generate_speech.side_effect = ConnectionError("TTS server down")
    mapper = MagicMock()
    mapper.map.return_value = [{"duration": 0.3, "targets": {"neutral": 1.0}}]

    with patch("src.services.tts_service.tts_pipeline.logger") as mock_logger:
        chunk = await synthesize_chunk(
            tts_service=tts_service,
            mapper=mapper,
            text="텍스트",
            emotion=None,
            sequence=2,
            tts_enabled=True,
        )

    assert chunk.audio_base64 is None
    assert chunk.sequence == 2
    mock_logger.error.assert_called_once()


async def test_synthesize_chunk_tts_disabled():
    """tts_enabled=False → audio=None, generate_speech NOT called, keyframes still set."""
    tts_service = MagicMock()
    mapper = MagicMock()
    mapper.map.return_value = [{"duration": 0.4, "targets": {"sad": 0.8}}]

    chunk = await synthesize_chunk(
        tts_service=tts_service,
        mapper=mapper,
        text="텍스트",
        emotion="sad",
        sequence=3,
        tts_enabled=False,
    )

    assert chunk.audio_base64 is None
    assert chunk.keyframes == [{"duration": 0.4, "targets": {"sad": 0.8}}]
    assert chunk.sequence == 3
    tts_service.generate_speech.assert_not_called()
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_tts_pipeline.py -v
```

Expected: FAILED — `TtsChunkMessage` still requires `motion_name`/`blendshape_name`, `keyframes` field missing.

- [ ] **Step 3: Update `tts_pipeline.py`**

Replace the entire content of `backend/src/services/tts_service/tts_pipeline.py`:

```python
"""TTS synthesis pipeline — text + emotion → TtsChunkMessage.

synthesize_chunk() never raises. All errors are logged to backend only.
"""

from asyncio import to_thread

from src.core.logger import logger
from src.models.websocket import TtsChunkMessage, TimelineKeyframe
from src.services.tts_service.emotion_motion_mapper import EmotionMotionMapper
from src.services.tts_service.service import TTSService


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
    Always returns a single TtsChunkMessage.

    Behavior:
    - tts_enabled=True: calls generate_speech() via asyncio.to_thread()
    - tts_enabled=False: skips TTS API, audio_base64=None (normal state)
    - On failure: audio_base64=None, error logged backend-only — never raised

    Args:
        tts_service: TTS engine instance (TTSService ABC)
        mapper: EmotionMotionMapper for emotion → keyframes
        text: Text to synthesize
        emotion: Detected emotion tag (None → mapper returns default)
        sequence: Chunk order within turn (starts at 0)
        tts_enabled: False → skip TTS API entirely
        reference_id: Voice reference ID. None → engine default

    Returns:
        TtsChunkMessage with audio_base64=None on failure/disabled,
        keyframes always populated.
    """
    keyframes: list[TimelineKeyframe] = mapper.map(emotion)
    audio: str | None = None

    if tts_enabled:
        try:
            result = await to_thread(
                tts_service.generate_speech,
                text,
                reference_id,
                "base64",
                "wav",
            )
            if result is None:
                logger.error(f"TTS synthesis returned None for sequence {sequence}")
                audio = None
            else:
                audio = result
        except Exception as e:
            logger.error(f"TTS synthesis failed for sequence {sequence}: {e}")
            audio = None

    return TtsChunkMessage(
        sequence=sequence,
        text=text,
        audio_base64=audio,
        emotion=emotion,
        keyframes=keyframes,
    )
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_tts_pipeline.py -v
```

Expected: All PASSED.

- [ ] **Step 5: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend add \
  src/services/tts_service/tts_pipeline.py \
  tests/services/test_tts_pipeline.py
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend commit -m "feat: use WAV format and keyframes in tts_pipeline synthesize_chunk"
```

---

## Task 4: Update `event_handlers.py` and its tests

**Files:**
- Modify: `backend/src/services/websocket_service/message_processor/event_handlers.py:300-311`
- Test: `backend/tests/core/test_event_handler_tts.py`

### What changes

`_synthesize_and_send()` currently puts `motion_name` and `blendshape_name` into the event dict. Change it to put `keyframes` instead. The test fixtures also construct `TtsChunkMessage` with the old fields — update them.

- [ ] **Step 1: Write failing tests**

Replace the entire content of `backend/tests/core/test_event_handler_tts.py`:

```python
"""Tests for EventHandler._synthesize_and_send() orchestration."""

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.services.websocket_service.message_processor.event_handlers import EventHandler
from src.services.websocket_service.message_processor.models import ConversationTurn


def _make_processor(turn_id: str, is_closing: bool = False):
    """Build a minimal mock MessageProcessor."""
    proc = MagicMock()
    proc.is_connection_closing.return_value = is_closing
    proc._put_event = AsyncMock()
    proc._task_manager = MagicMock()
    proc._task_manager.track_task = MagicMock()

    turn = ConversationTurn(
        turn_id=turn_id,
        user_message="hi",
        session_id="s1",
        tts_enabled=True,
        reference_id=None,
        tts_tasks=[],
        tts_sequence=0,
    )
    turn.event_queue = asyncio.Queue()
    proc.turns = {turn_id: turn}
    proc.tts_service = MagicMock()
    proc.mapper = MagicMock()
    return proc, turn


@pytest.mark.asyncio
async def test_synthesize_and_send_success():
    """Success: _put_event called once with type=='tts_chunk' and keyframes."""
    from src.models.websocket import TtsChunkMessage

    turn_id = "t1"
    proc, turn = _make_processor(turn_id)
    handler = EventHandler(proc)

    fake_chunk = TtsChunkMessage(
        sequence=0,
        text="Hello",
        audio_base64="abc123",
        emotion="joyful",
        keyframes=[{"duration": 0.3, "targets": {"happy": 1.0}}],
    )

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(return_value=fake_chunk),
    ):
        await handler._synthesize_and_send(
            turn_id=turn_id,
            text="Hello",
            emotion="joyful",
            sequence=0,
            tts_enabled=True,
            reference_id=None,
        )

    proc._put_event.assert_called_once()
    call_event = proc._put_event.call_args[0][1]
    assert call_event["type"] == "tts_chunk"
    assert call_event["audio_base64"] == "abc123"
    assert call_event["sequence"] == 0
    assert call_event["keyframes"] == [{"duration": 0.3, "targets": {"happy": 1.0}}]
    assert "motion_name" not in call_event
    assert "blendshape_name" not in call_event


@pytest.mark.asyncio
async def test_synthesize_and_send_tts_failure_still_puts_chunk():
    """TTS failure: audio_base64=None still puts tts_chunk with keyframes."""
    from src.models.websocket import TtsChunkMessage

    turn_id = "t2"
    proc, turn = _make_processor(turn_id)
    handler = EventHandler(proc)

    fake_chunk = TtsChunkMessage(
        sequence=1,
        text="Hi",
        audio_base64=None,
        emotion=None,
        keyframes=[{"duration": 0.3, "targets": {"neutral": 1.0}}],
    )

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(return_value=fake_chunk),
    ):
        await handler._synthesize_and_send(
            turn_id=turn_id,
            text="Hi",
            emotion=None,
            sequence=1,
            tts_enabled=True,
            reference_id=None,
        )

    proc._put_event.assert_called_once()
    call_event = proc._put_event.call_args[0][1]
    assert call_event["type"] == "tts_chunk"
    assert call_event["audio_base64"] is None
    assert "keyframes" in call_event


@pytest.mark.asyncio
async def test_synthesize_and_send_is_closing_drops_silently():
    """is_closing=True before synthesize: no _put_event call, no synthesize_chunk call."""
    turn_id = "t3"
    proc, turn = _make_processor(turn_id, is_closing=True)
    handler = EventHandler(proc)

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(),
    ) as mock_synth:
        await handler._synthesize_and_send(
            turn_id=turn_id,
            text="Test",
            emotion=None,
            sequence=0,
            tts_enabled=True,
            reference_id=None,
        )

    proc._put_event.assert_not_called()
    mock_synth.assert_not_called()


@pytest.mark.asyncio
async def test_tts_task_registered_in_both_lists():
    """_process_token_event creates a task that ends up in tts_tasks AND track_task."""
    from unittest.mock import ANY

    from src.models.websocket import TtsChunkMessage

    turn_id = "t4"
    proc, turn = _make_processor(turn_id)
    handler = EventHandler(proc)

    fake_chunk = TtsChunkMessage(
        sequence=0,
        text="Hello world",
        audio_base64=None,
        keyframes=[{"duration": 0.3, "targets": {"neutral": 1.0}}],
    )

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(return_value=fake_chunk),
    ):
        # Long enough sentence (>= min_chunk_length) so the chunker yields it immediately
        await handler._process_token_event(
            turn_id,
            {
                "chunk": "Hello world, this is a long enough sentence to pass the minimum threshold."
            },
        )
        # Let the asyncio task actually run
        await asyncio.gather(*turn.tts_tasks)

    assert len(turn.tts_tasks) == 1
    proc._task_manager.track_task.assert_called_once_with(turn_id, ANY)


@pytest.mark.asyncio
async def test_tts_sequence_increments_per_chunk():
    """turn.tts_sequence increments monotonically: after 2 calls == 2."""
    from src.models.websocket import TtsChunkMessage

    turn_id = "t5"
    proc, turn = _make_processor(turn_id)
    handler = EventHandler(proc)

    def make_chunk(seq):
        return TtsChunkMessage(
            sequence=seq,
            text="text",
            audio_base64=None,
            keyframes=[{"duration": 0.3, "targets": {"neutral": 1.0}}],
        )

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(side_effect=[make_chunk(0), make_chunk(1)]),
    ):
        task1 = asyncio.create_task(
            handler._synthesize_and_send(
                turn_id=turn_id,
                text="sentence one",
                emotion=None,
                sequence=turn.tts_sequence,
                tts_enabled=True,
                reference_id=None,
            )
        )
        turn.tts_sequence += 1
        turn.tts_tasks.append(task1)

        task2 = asyncio.create_task(
            handler._synthesize_and_send(
                turn_id=turn_id,
                text="sentence two",
                emotion=None,
                sequence=turn.tts_sequence,
                tts_enabled=True,
                reference_id=None,
            )
        )
        turn.tts_sequence += 1
        turn.tts_tasks.append(task2)

        await asyncio.gather(task1, task2)

    assert turn.tts_sequence == 2
    assert len(turn.tts_tasks) == 2
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/core/test_event_handler_tts.py -v
```

Expected: FAILED — `TtsChunkMessage` still has old field names in some tests, and `_synthesize_and_send` still emits `motion_name`/`blendshape_name`.

- [ ] **Step 3: Update `_synthesize_and_send` in `event_handlers.py`**

Find the `_synthesize_and_send` method's `_put_event` call (lines 300–311). Replace:

```python
        await self.processor._put_event(
            turn_id,
            {
                "type": "tts_chunk",
                "sequence": chunk_msg.sequence,
                "text": chunk_msg.text,
                "audio_base64": chunk_msg.audio_base64,
                "emotion": chunk_msg.emotion,
                "motion_name": chunk_msg.motion_name,
                "blendshape_name": chunk_msg.blendshape_name,
            },
        )
```

With:

```python
        await self.processor._put_event(
            turn_id,
            {
                "type": "tts_chunk",
                "sequence": chunk_msg.sequence,
                "text": chunk_msg.text,
                "audio_base64": chunk_msg.audio_base64,
                "emotion": chunk_msg.emotion,
                "keyframes": chunk_msg.keyframes,
            },
        )
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/core/test_event_handler_tts.py -v
```

Expected: All PASSED.

- [ ] **Step 5: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend add \
  src/services/websocket_service/message_processor/event_handlers.py \
  tests/core/test_event_handler_tts.py
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend commit -m "feat: emit keyframes instead of motion_name/blendshape_name in event_handlers"
```

---

## Task 5: Update YAML config for emotion mapper + run full suite

**Files:**
- Modify: `backend/yaml_files/` — update the TTS emotion mapper config file

- [ ] **Step 1: Find the emotion mapper config file**

```bash
grep -r "motion\|blendshape\|joyful\|neutral_idle" /home/spow12/codes/2025_lower/DesktopMatePlus/backend/yaml_files/ --include="*.yml" -l
```

Note the file path. It will be something like `yaml_files/tts_emotions.yml` or similar.

- [ ] **Step 2: Update the YAML to use keyframes format**

The old format had entries like:
```yaml
joyful:
  motion: happy_idle
  blendshape: smile
default:
  motion: neutral_idle
  blendshape: neutral
```

Replace **every entry** to use the new keyframes format:
```yaml
joyful:
  keyframes:
    - duration: 0.3
      targets:
        happy: 1.0
sad:
  keyframes:
    - duration: 0.3
      targets:
        sad: 0.8
angry:
  keyframes:
    - duration: 0.3
      targets:
        angry: 0.8
surprised:
  keyframes:
    - duration: 0.3
      targets:
        surprised: 0.9
default:
  keyframes:
    - duration: 0.3
      targets:
        neutral: 1.0
```

Preserve any emotions that existed before; only change the value structure.

- [ ] **Step 3: Run the full test suite**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest -v
```

Expected: All tests PASSED. Pay special attention to:
- `tests/models/test_websocket_models.py`
- `tests/services/test_emotion_motion_mapper.py`
- `tests/services/test_tts_pipeline.py`
- `tests/core/test_event_handler_tts.py`

If any tests fail due to old fields still being used elsewhere, fix them before proceeding.

- [ ] **Step 4: Run lint**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
sh scripts/lint.sh
```

Expected: No errors. Fix any ruff complaints before committing.

- [ ] **Step 5: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend add yaml_files/
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend commit -m "chore: update emotion mapper YAML config to keyframes format"
```

---

## Task 6: Update `examples/realtime_tts_streaming_demo.py`

Per `backend/CLAUDE.md`: "Update `examples/realtime_tts_streaming_demo.py` for any api or websocket interface changes."

**Files:**
- Modify: `backend/examples/realtime_tts_streaming_demo.py`

- [ ] **Step 1: Open the demo file and find TTS chunk handling**

```bash
grep -n "motion_name\|blendshape_name\|tts_chunk\|keyframes" \
  /home/spow12/codes/2025_lower/DesktopMatePlus/backend/examples/realtime_tts_streaming_demo.py
```

- [ ] **Step 2: Update the TTS chunk handler**

Replace any references to `motion_name` and `blendshape_name` with `keyframes`. For example, if you see:

```python
motion = data.get("motion_name")
blendshape = data.get("blendshape_name")
print(f"  Motion: {motion}, Blendshape: {blendshape}")
```

Replace with:

```python
keyframes = data.get("keyframes", [])
print(f"  Keyframes: {keyframes}")
```

- [ ] **Step 3: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend add examples/realtime_tts_streaming_demo.py
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/backend commit -m "chore: update demo script for keyframes TTS format"
```

---

## Final Verification

- [ ] **Run the complete backend test suite one last time**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest -v --tb=short 2>&1 | tail -30
```

Expected: All PASSED, zero FAILED.

- [ ] **Run lint**

```bash
sh scripts/lint.sh
```

Expected: No errors.

- [ ] **Confirm no Unity-specific field references remain in source**

```bash
grep -r "motion_name\|blendshape_name" \
  /home/spow12/codes/2025_lower/DesktopMatePlus/backend/src/ \
  --include="*.py"
```

Expected: No output.
