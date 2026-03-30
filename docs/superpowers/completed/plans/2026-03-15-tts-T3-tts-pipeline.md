# T3: TTS 파이프라인 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `synthesize_chunk()` 비동기 파이프라인을 구현하여 text+emotion 입력에서 TTS 합성+motion 매핑을 수행하고 항상 `TtsChunkMessage` 단일 객체를 반환한다. 실패/비활성 시 `audio_base64=None`으로 반환하며 예외는 절대 caller에 전파하지 않는다.

**Architecture:** 단일 파일 `tts_pipeline.py`에 `synthesize_chunk()` 함수 하나만 둔다. 동기 TTS 엔진(`TTSService.generate_speech()`)은 `asyncio.to_thread()`로 이벤트루프 블로킹을 방지한다. 모든 에러는 `logger.error()`로 백엔드에만 기록 — FE(Unity)에는 에러 이벤트 없음.

**Tech Stack:** Python 3.13, asyncio, pytest-asyncio (`asyncio_mode=auto` — `@pytest.mark.asyncio` 데코레이터 불필요), unittest.mock.MagicMock, uv

**Prerequisites (T3 시작 전 완료 필수):**
- **T1 완료**: `TtsChunkMessage` 클래스가 `src/models/websocket.py`에 존재. 필드: `sequence: int`, `text: str`, `audio_base64: Optional[str]`, `emotion: Optional[str]`, `motion_name: str`, `blendshape_name: str`
- **T2 완료**: `EmotionMotionMapper` 클래스가 `src/services/tts_service/emotion_motion_mapper.py`에 존재. `map(emotion: str | None) -> tuple[str, str]` 메서드 구현

---

## Chunk 1: 테스트 파일 작성 (Red Phase)

**Files:**
- Create: `backend/tests/services/test_tts_pipeline.py`

### Task 1: 테스트 파일 전체 작성 (4개 시나리오 전부 포함)

- [ ] **Step 1: 테스트 파일 작성**

`backend/tests/services/test_tts_pipeline.py`:

```python
"""Tests for synthesize_chunk() TTS pipeline.

Note: asyncio_mode=auto (pyproject.toml) — @pytest.mark.asyncio decorator is NOT needed.
generate_speech() MUST be mocked in all tests — no real TTS engine in CI.
"""

from unittest.mock import MagicMock, patch

from src.services.tts_service.tts_pipeline import synthesize_chunk


async def test_synthesize_chunk_success():
    """TTS success: audio_base64 is non-null, motion mapped correctly."""
    tts_service = MagicMock()
    tts_service.generate_speech.return_value = "base64encodedaudio=="
    mapper = MagicMock()
    mapper.map.return_value = ("happy_idle", "smile")

    chunk = await synthesize_chunk(
        tts_service=tts_service,
        mapper=mapper,
        text="안녕",
        emotion="joyful",
        sequence=0,
        tts_enabled=True,
    )

    assert chunk.audio_base64 == "base64encodedaudio=="
    assert chunk.motion_name == "happy_idle"
    assert chunk.blendshape_name == "smile"
    assert chunk.sequence == 0
    assert chunk.text == "안녕"
    assert chunk.emotion == "joyful"
    tts_service.generate_speech.assert_called_once()


async def test_synthesize_chunk_generate_speech_returns_none():
    """generate_speech returns None → audio=None, logger.error called once."""
    tts_service = MagicMock()
    tts_service.generate_speech.return_value = None
    mapper = MagicMock()
    mapper.map.return_value = ("neutral_idle", "neutral")

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
    assert chunk.motion_name == "neutral_idle"
    mock_logger.error.assert_called_once()


async def test_synthesize_chunk_exception():
    """generate_speech raises exception → audio=None, logger.error called once."""
    tts_service = MagicMock()
    tts_service.generate_speech.side_effect = ConnectionError("TTS server down")
    mapper = MagicMock()
    mapper.map.return_value = ("neutral_idle", "neutral")

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
    """tts_enabled=False → audio=None, generate_speech NOT called, motion still set."""
    tts_service = MagicMock()
    mapper = MagicMock()
    mapper.map.return_value = ("sad_idle", "sad")

    chunk = await synthesize_chunk(
        tts_service=tts_service,
        mapper=mapper,
        text="텍스트",
        emotion="sad",
        sequence=3,
        tts_enabled=False,
    )

    assert chunk.audio_base64 is None
    assert chunk.motion_name == "sad_idle"
    assert chunk.blendshape_name == "sad"
    assert chunk.sequence == 3
    tts_service.generate_speech.assert_not_called()
```

- [ ] **Step 2: 테스트가 실패하는지 확인 (모듈 미존재)**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_tts_pipeline.py -v
```

Expected: `ImportError: cannot import name 'synthesize_chunk' from 'src.services.tts_service.tts_pipeline'`

만약 T1 미완료 시 `ImportError: cannot import name 'TtsChunkMessage'`가 먼저 발생. T1 완료 후 진행.

---

## Chunk 2: 구현 작성 (Green Phase)

**Files:**
- Create: `backend/src/services/tts_service/tts_pipeline.py`

### Task 2: `synthesize_chunk()` 구현

- [ ] **Step 1: `tts_pipeline.py` 작성**

`backend/src/services/tts_service/tts_pipeline.py`:

```python
"""TTS synthesis pipeline — text + emotion → TtsChunkMessage.

synthesize_chunk() never raises. All errors are logged to backend only.
"""

from asyncio import to_thread

from src.core.logger import logger
from src.models.websocket import TtsChunkMessage
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
        mapper: EmotionMotionMapper for emotion → motion/blendshape
        text: Text to synthesize
        emotion: Detected emotion tag (None → mapper returns default)
        sequence: Chunk order within turn (starts at 0)
        tts_enabled: False → skip TTS API entirely
        reference_id: Voice reference ID. None → engine default

    Returns:
        TtsChunkMessage with audio_base64=None on failure/disabled,
        motion/blendshape always populated.
    """
    motion_name, blendshape_name = mapper.map(emotion)
    audio: str | None = None

    if tts_enabled:
        try:
            result = await to_thread(
                tts_service.generate_speech,
                text,
                reference_id,
                "base64",
                "mp3",
            )
            if result is None:
                raise ValueError("generate_speech returned None")
            audio = result
        except Exception as e:
            logger.error(f"TTS synthesis failed for sequence {sequence}: {e}")
            audio = None

    return TtsChunkMessage(
        sequence=sequence,
        text=text,
        audio_base64=audio,
        emotion=emotion,
        motion_name=motion_name,
        blendshape_name=blendshape_name,
    )
```

> **주의**: `to_thread(tts_service.generate_speech, text, reference_id, "base64", "mp3")` — 위치 인자는 `(text, reference_id, output_format, output_filename)` 순서로 전달. `output_filename` 위치에 `"mp3"`가 들어가지만 이는 spec이 정의한 인터페이스.

- [ ] **Step 2: 4개 테스트 모두 통과 확인**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_tts_pipeline.py -v
```

Expected output:
```
tests/services/test_tts_pipeline.py::test_synthesize_chunk_success PASSED
tests/services/test_tts_pipeline.py::test_synthesize_chunk_generate_speech_returns_none PASSED
tests/services/test_tts_pipeline.py::test_synthesize_chunk_exception PASSED
tests/services/test_tts_pipeline.py::test_synthesize_chunk_tts_disabled PASSED

4 passed
```

만약 `test_synthesize_chunk_generate_speech_returns_none` 실패 시 `patch` 경로 확인: `"src.services.tts_service.tts_pipeline.logger"` — 모듈 내 `logger` 객체를 직접 patch해야 함.

---

## Chunk 3: 회귀 검증 + lint + 커밋

### Task 3: 전체 회귀 테스트 + lint + 커밋

- [ ] **Step 1: 기존 TTS 테스트 회귀 없음 확인**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_tts_synthesis.py -v
```

Expected: 기존 테스트 전부 `PASSED`. T3는 기존 파일을 수정하지 않으므로 회귀 없어야 함.

- [ ] **Step 2: 전체 테스트 스위트 실행 (T1, T2 완료 후)**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest -v --tb=short
```

Expected: 기존 테스트 + 신규 4개 모두 `PASSED`.

- [ ] **Step 3: ruff lint + format 체크**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
sh scripts/lint.sh
```

Expected: 에러 없음. lint 에러 발생 시:

```bash
uv run ruff format src/services/tts_service/tts_pipeline.py tests/services/test_tts_pipeline.py
uv run ruff check src/services/tts_service/tts_pipeline.py tests/services/test_tts_pipeline.py --fix
```

- [ ] **Step 4: 커밋**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add src/services/tts_service/tts_pipeline.py tests/services/test_tts_pipeline.py
git commit -m "feat: add synthesize_chunk TTS pipeline (T3)"
```

---

## 완료 체크리스트

- [ ] `backend/src/services/tts_service/tts_pipeline.py` 생성 (4가지 시나리오 모두 동작)
- [ ] `backend/tests/services/test_tts_pipeline.py` 생성 (4개 테스트 모두 `PASSED`)
- [ ] `generate_speech`가 모든 테스트에서 `MagicMock()`으로 mock됨 — CI에서 실제 TTS 엔진 불필요
- [ ] `tts_enabled=False`일 때 `generate_speech.assert_not_called()` 통과
- [ ] 에러 시나리오(None 반환/예외 발생)에서 `mock_logger.error.assert_called_once()` 통과
- [ ] 반환 타입이 항상 `TtsChunkMessage` 단일 객체 (예외 없음)
- [ ] `sh scripts/lint.sh` 통과
- [ ] 기존 `test_tts_synthesis.py` 회귀 없음
