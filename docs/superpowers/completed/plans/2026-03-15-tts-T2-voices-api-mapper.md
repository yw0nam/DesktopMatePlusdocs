# T2: 참조 API & EmotionMotionMapper Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `GET /v1/tts/voices` API, create `EmotionMotionMapper` from YAML config, and delete the legacy `POST /v1/tts/synthesize` endpoint along with its now-unused models.

**Architecture:** `EmotionMotionMapper` is a thin pure-Python class initialized from the `emotion_motion_map:` section of `yaml_files/tts_rules.yml` and stored as a singleton in `service_manager.py`. `list_voices()` is added as a new abstract method on `TTSService` — `VLLMOmniTTSService` scans the `ref_audio_dir` once at `__init__` time, `FishSpeechTTS` returns an empty list. The voices route replaces the synthesize route in `tts.py`.

**Tech Stack:** Python 3.13, Pydantic v2, FastAPI, pytest, uv

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `backend/src/models/tts.py` | Remove `TTSRequest`/`TTSResponse`; add `VoicesResponse` |
| Modify | `backend/src/api/routes/tts.py` | Remove `POST /v1/tts/synthesize`; add `GET /v1/tts/voices` |
| Modify | `backend/src/services/tts_service/service.py` | Add abstract `list_voices()` |
| Modify | `backend/src/services/tts_service/vllm_omni.py` | Add `_scan_voices()` + `list_voices()` |
| Modify | `backend/src/services/tts_service/fish_speech.py` | Add `list_voices() -> []` |
| Create | `backend/src/services/tts_service/emotion_motion_mapper.py` | `EmotionMotionMapper` class |
| Modify | `backend/src/services/service_manager.py` | Add mapper singleton + initializer + getter |
| Modify | `backend/src/services/__init__.py` | Export new mapper symbols |
| Modify | `backend/src/main.py` | Call `initialize_emotion_motion_mapper()` in lifespan |
| Modify | `backend/yaml_files/tts_rules.yml` | Add `emotion_motion_map:` section |
| Create | `backend/tests/services/test_emotion_motion_mapper.py` | Unit tests for mapper |
| Create | `backend/tests/services/test_list_voices.py` | Unit tests for `list_voices()` on both impls |
| Create | `backend/tests/api/test_tts_voices_api.py` | API integration tests for `/v1/tts/voices` |
| Delete | `backend/tests/api/test_tts_api_integration.py` | Old synthesize API tests |
| Delete | `backend/docs/api/TTS_Synthesize.md` | Legacy API doc |

---

## Chunk 1: EmotionMotionMapper — pure class + tests

This chunk creates and fully tests `EmotionMotionMapper` with no dependency on any other modified file.

### Task 1: EmotionMotionMapper unit tests (write failing first)

**Files:**
- Create: `backend/tests/services/test_emotion_motion_mapper.py`
- Create: `backend/src/services/tts_service/emotion_motion_mapper.py`

- [ ] **Step 1: Write the failing tests**

Create `/home/spow12/codes/2025_lower/DesktopMatePlus/backend/tests/services/test_emotion_motion_mapper.py`:

```python
"""Unit tests for EmotionMotionMapper."""

import pytest

from src.services.tts_service.emotion_motion_mapper import EmotionMotionMapper


SAMPLE_CONFIG: dict[str, dict[str, str]] = {
    "joyful": {"motion": "happy_idle", "blendshape": "smile"},
    "sad": {"motion": "sad_idle", "blendshape": "sad"},
    "default": {"motion": "neutral_idle", "blendshape": "neutral"},
}


class TestEmotionMotionMapperRegistered:
    """Registered emotion returns correct tuple."""

    def test_joyful_returns_correct_motion(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        motion, blendshape = mapper.map("joyful")
        assert motion == "happy_idle"
        assert blendshape == "smile"

    def test_sad_returns_correct_motion(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        motion, blendshape = mapper.map("sad")
        assert motion == "sad_idle"
        assert blendshape == "sad"


class TestEmotionMotionMapperDefault:
    """Unregistered or None emotion returns default."""

    def test_unregistered_emotion_returns_default(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        motion, blendshape = mapper.map("unknown_emotion")
        assert motion == "neutral_idle"
        assert blendshape == "neutral"

    def test_none_emotion_returns_default(self):
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        motion, blendshape = mapper.map(None)
        assert motion == "neutral_idle"
        assert blendshape == "neutral"

    def test_empty_string_returns_default(self):
        """Empty string is not a registered key — should fall through to default."""
        mapper = EmotionMotionMapper(SAMPLE_CONFIG)
        motion, blendshape = mapper.map("")
        assert motion == "neutral_idle"
        assert blendshape == "neutral"


class TestEmotionMotionMapperFallback:
    """When config has no 'default' key, hardcoded fallback is used."""

    def test_missing_default_key_uses_hardcoded_fallback(self):
        config_without_default: dict[str, dict[str, str]] = {
            "joyful": {"motion": "happy_idle", "blendshape": "smile"},
        }
        mapper = EmotionMotionMapper(config_without_default)
        motion, blendshape = mapper.map("unregistered")
        assert motion == "neutral_idle"
        assert blendshape == "neutral"

    def test_empty_config_returns_hardcoded_fallback(self):
        mapper = EmotionMotionMapper({})
        motion, blendshape = mapper.map(None)
        assert motion == "neutral_idle"
        assert blendshape == "neutral"

    def test_partial_entry_missing_blendshape_falls_back_to_default_blendshape(self):
        """An entry with only 'motion' key — blendshape falls back to default."""
        config = {
            "odd": {"motion": "odd_idle"},   # no blendshape
            "default": {"motion": "neutral_idle", "blendshape": "neutral"},
        }
        mapper = EmotionMotionMapper(config)
        motion, blendshape = mapper.map("odd")
        assert motion == "odd_idle"
        assert blendshape == "neutral"   # from default
```

- [ ] **Step 2: Run tests to confirm they fail (ImportError expected)**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_emotion_motion_mapper.py -v
```

Expected: `ImportError: cannot import name 'EmotionMotionMapper'`

- [ ] **Step 3: Implement EmotionMotionMapper**

Create `/home/spow12/codes/2025_lower/DesktopMatePlus/backend/src/services/tts_service/emotion_motion_mapper.py`:

```python
"""Emotion-to-motion/blendshape mapper loaded from YAML config."""


_HARDCODED_DEFAULT: dict[str, str] = {
    "motion": "neutral_idle",
    "blendshape": "neutral",
}


class EmotionMotionMapper:
    """Maps emotion keyword strings to Unity motion + blendshape names.

    Config format (from yaml_files/tts_rules.yml, section emotion_motion_map):
        joyful: {motion: happy_idle, blendshape: smile}
        default: {motion: neutral_idle, blendshape: neutral}

    Rules:
    - Registered emotion → exact entry values
    - Unregistered / empty string → default entry values
    - None → default entry values
    - If a matching entry is missing 'motion' or 'blendshape', the corresponding
      field falls back to the default entry's value.
    """

    def __init__(self, config: dict[str, dict[str, str]]):
        self._map = config
        self._default: dict[str, str] = config.get("default", _HARDCODED_DEFAULT)

    def map(self, emotion: str | None) -> tuple[str, str]:
        """Return (motion_name, blendshape_name) for the given emotion.

        Args:
            emotion: Emotion keyword, or None.

        Returns:
            Tuple of (motion_name, blendshape_name).
        """
        entry: dict[str, str] | None = self._map.get(emotion) if emotion else None
        if not entry:
            entry = self._default
        return (
            entry.get("motion", self._default.get("motion", _HARDCODED_DEFAULT["motion"])),
            entry.get("blendshape", self._default.get("blendshape", _HARDCODED_DEFAULT["blendshape"])),
        )
```

- [ ] **Step 4: Run tests to verify all pass**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_emotion_motion_mapper.py -v
```

Expected: All 9 tests PASSED.

- [ ] **Step 5: Commit**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add src/services/tts_service/emotion_motion_mapper.py tests/services/test_emotion_motion_mapper.py
git commit -m "feat(tts): add EmotionMotionMapper with YAML config support"
```

---

## Chunk 2: list_voices() — abstract method + both implementations

### Task 2: list_voices() tests for VLLMOmniTTSService (write failing first)

**Files:**
- Create: `backend/tests/services/test_list_voices.py`
- Modify: `backend/src/services/tts_service/service.py`
- Modify: `backend/src/services/tts_service/vllm_omni.py`
- Modify: `backend/src/services/tts_service/fish_speech.py`

- [ ] **Step 1: Write failing tests**

Create `/home/spow12/codes/2025_lower/DesktopMatePlus/backend/tests/services/test_list_voices.py`:

```python
"""Unit tests for list_voices() on TTS service implementations."""

import pytest

from src.services.tts_service.fish_speech import FishSpeechTTS
from src.services.tts_service.vllm_omni import VLLMOmniTTSService


class TestVLLMOmniListVoices:
    """VLLMOmniTTSService.list_voices() scans ref_audio_dir at __init__ time."""

    def test_missing_ref_audio_dir_returns_empty(self, tmp_path):
        """Non-existent ref_audio_dir returns empty list — no exception."""
        nonexistent = tmp_path / "does_not_exist"
        tts = VLLMOmniTTSService(
            base_url="http://localhost:5517",
            ref_audio_dir=str(nonexistent),
        )
        assert tts.list_voices() == []

    def test_empty_ref_audio_dir_returns_empty(self, tmp_path):
        """Existing but empty dir returns empty list."""
        tts = VLLMOmniTTSService(
            base_url="http://localhost:5517",
            ref_audio_dir=str(tmp_path),
        )
        assert tts.list_voices() == []

    def test_valid_voice_dir_is_included(self, tmp_path):
        """Dir with both merged_audio.mp3 + combined.lab is included."""
        voice_dir = tmp_path / "aria"
        voice_dir.mkdir()
        (voice_dir / "merged_audio.mp3").write_bytes(b"mp3data")
        (voice_dir / "combined.lab").write_text("reference text", encoding="utf-8")

        tts = VLLMOmniTTSService(
            base_url="http://localhost:5517",
            ref_audio_dir=str(tmp_path),
        )
        assert "aria" in tts.list_voices()

    def test_incomplete_dir_mp3_only_is_excluded(self, tmp_path):
        """Dir with only merged_audio.mp3 (missing combined.lab) is excluded."""
        bad_dir = tmp_path / "incomplete"
        bad_dir.mkdir()
        (bad_dir / "merged_audio.mp3").write_bytes(b"mp3data")

        tts = VLLMOmniTTSService(
            base_url="http://localhost:5517",
            ref_audio_dir=str(tmp_path),
        )
        assert "incomplete" not in tts.list_voices()

    def test_incomplete_dir_lab_only_is_excluded(self, tmp_path):
        """Dir with only combined.lab (missing merged_audio.mp3) is excluded."""
        bad_dir = tmp_path / "labonly"
        bad_dir.mkdir()
        (bad_dir / "combined.lab").write_text("text", encoding="utf-8")

        tts = VLLMOmniTTSService(
            base_url="http://localhost:5517",
            ref_audio_dir=str(tmp_path),
        )
        assert "labonly" not in tts.list_voices()

    def test_multiple_voices_returned_sorted(self, tmp_path):
        """Multiple valid voices are returned in sorted order."""
        for name in ("zebra", "alpha", "bravo"):
            d = tmp_path / name
            d.mkdir()
            (d / "merged_audio.mp3").write_bytes(b"mp3")
            (d / "combined.lab").write_text("t", encoding="utf-8")

        tts = VLLMOmniTTSService(
            base_url="http://localhost:5517",
            ref_audio_dir=str(tmp_path),
        )
        voices = tts.list_voices()
        assert voices == sorted(voices)
        assert set(voices) == {"zebra", "alpha", "bravo"}

    def test_list_voices_returns_cached_value(self, tmp_path):
        """list_voices() returns the same list object (scan happens only once)."""
        voice_dir = tmp_path / "voice1"
        voice_dir.mkdir()
        (voice_dir / "merged_audio.mp3").write_bytes(b"mp3")
        (voice_dir / "combined.lab").write_text("t", encoding="utf-8")

        tts = VLLMOmniTTSService(
            base_url="http://localhost:5517",
            ref_audio_dir=str(tmp_path),
        )
        assert tts.list_voices() is tts.list_voices()

    def test_file_at_root_level_is_ignored(self, tmp_path):
        """A plain file in ref_audio_dir (not a directory) is ignored."""
        (tmp_path / "README.txt").write_text("not a voice")

        tts = VLLMOmniTTSService(
            base_url="http://localhost:5517",
            ref_audio_dir=str(tmp_path),
        )
        assert tts.list_voices() == []


class TestFishSpeechListVoices:
    """FishSpeechTTS.list_voices() always returns []."""

    def test_list_voices_returns_empty_list(self):
        tts = FishSpeechTTS(base_url="http://localhost:8080/v1/tts")
        assert tts.list_voices() == []

    def test_list_voices_return_type_is_list(self):
        tts = FishSpeechTTS(base_url="http://localhost:8080/v1/tts")
        result = tts.list_voices()
        assert isinstance(result, list)
```

- [ ] **Step 2: Run to confirm failure**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_list_voices.py -v
```

Expected: `AttributeError: 'VLLMOmniTTSService' object has no attribute 'list_voices'`

- [ ] **Step 3: Add abstract list_voices() to TTSService base class**

Edit `src/services/tts_service/service.py`. After the `is_healthy` abstract method, add:

```python
    @abstractmethod
    def list_voices(self) -> list[str]:
        """Return available reference voice IDs.

        Returns:
            List of voice ID strings (directory names under ref_audio_dir
            for providers that support reference voices; empty list otherwise).
        """
        pass
```

- [ ] **Step 4: Add _scan_voices() and list_voices() to VLLMOmniTTSService**

Edit `src/services/tts_service/vllm_omni.py`.

In `__init__`, after `self._ref_cache: dict[str, tuple[str, str]] = {}`, add:

```python
        self._available_voices: list[str] = self._scan_voices()
```

Add two new methods after `__init__`:

```python
    def _scan_voices(self) -> list[str]:
        """Scan ref_audio_dir for valid voice directories.

        A valid voice directory contains both:
        - merged_audio.mp3
        - combined.lab

        Returns:
            Sorted list of valid voice directory names. Empty list if
            ref_audio_dir does not exist.
        """
        if not self.ref_audio_dir.exists():
            return []
        voices: list[str] = []
        for d in sorted(self.ref_audio_dir.iterdir()):
            if d.is_dir():
                if (d / "merged_audio.mp3").exists() and (d / "combined.lab").exists():
                    voices.append(d.name)
        return voices

    def list_voices(self) -> list[str]:
        """Return available reference voice IDs (scanned once at init)."""
        return self._available_voices
```

- [ ] **Step 5: Add list_voices() to FishSpeechTTS**

Edit `src/services/tts_service/fish_speech.py`. After the `is_healthy` method, add:

```python
    def list_voices(self) -> list[str]:
        """FishSpeech does not manage reference voice directories."""
        return []
```

- [ ] **Step 6: Run tests to confirm they all pass**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_list_voices.py -v
```

Expected: All 10 tests PASSED.

- [ ] **Step 7: Run existing TTS synthesis tests to ensure no regressions**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/services/test_tts_synthesis.py -v
```

Expected: All existing tests still pass.

- [ ] **Step 8: Commit**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add \
  src/services/tts_service/service.py \
  src/services/tts_service/vllm_omni.py \
  src/services/tts_service/fish_speech.py \
  tests/services/test_list_voices.py
git commit -m "feat(tts): add list_voices() abstract method and implementations"
```

---

## Chunk 3: Models — remove legacy, add VoicesResponse

**Files:**
- Modify: `backend/src/models/tts.py`

- [ ] **Step 1: Replace the entire content of src/models/tts.py**

```python
"""TTS API response models."""

from pydantic import BaseModel


class VoicesResponse(BaseModel):
    """Response model for the list-voices endpoint."""

    voices: list[str]


__all__ = ["VoicesResponse"]
```

- [ ] **Step 2: Verify the models module loads cleanly**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run python -c "from src.models.tts import VoicesResponse; print(VoicesResponse(voices=['a','b']))"
```

Expected: `voices=['a', 'b']`

- [ ] **Step 3: Commit**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add src/models/tts.py
git commit -m "feat(tts): replace TTSRequest/TTSResponse with VoicesResponse model"
```

---

## Chunk 4: Route — delete synthesize, add voices endpoint + its tests

**Files:**
- Create: `backend/tests/api/test_tts_voices_api.py`
- Modify: `backend/src/api/routes/tts.py`
- Delete: `backend/tests/api/test_tts_api_integration.py`

- [ ] **Step 1: Write the failing API tests**

Create `/home/spow12/codes/2025_lower/DesktopMatePlus/backend/tests/api/test_tts_voices_api.py`:

```python
"""Integration tests for GET /v1/tts/voices endpoint."""

from unittest.mock import Mock, patch

import pytest
from fastapi import status


class TestListVoicesEndpoint:
    """Tests for GET /v1/tts/voices."""

    @patch("src.api.routes.tts.get_tts_service")
    def test_returns_200_with_voice_list(self, mock_get_tts, client):
        """When TTS service is available, returns 200 with list of voices."""
        mock_tts = Mock()
        mock_tts.list_voices.return_value = ["aria", "natsume", "voice_b"]
        mock_get_tts.return_value = mock_tts

        response = client.get("/v1/tts/voices")

        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "voices" in data
        assert data["voices"] == ["aria", "natsume", "voice_b"]

    @patch("src.api.routes.tts.get_tts_service")
    def test_returns_200_with_empty_list_when_no_voices(self, mock_get_tts, client):
        """When TTS service returns no voices, endpoint still returns 200."""
        mock_tts = Mock()
        mock_tts.list_voices.return_value = []
        mock_get_tts.return_value = mock_tts

        response = client.get("/v1/tts/voices")

        assert response.status_code == status.HTTP_200_OK
        assert response.json()["voices"] == []

    @patch("src.api.routes.tts.get_tts_service")
    def test_returns_503_when_tts_service_not_initialized(self, mock_get_tts, client):
        """When TTS service is None, endpoint returns 503."""
        mock_get_tts.return_value = None

        response = client.get("/v1/tts/voices")

        assert response.status_code == status.HTTP_503_SERVICE_UNAVAILABLE
        data = response.json()
        assert "detail" in data
        assert "TTS service not available" in data["detail"]

    def test_synthesize_endpoint_no_longer_exists(self, client):
        """POST /v1/tts/synthesize must return 404 after deletion."""
        response = client.post(
            "/v1/tts/synthesize",
            json={"text": "hello"},
        )
        assert response.status_code == status.HTTP_404_NOT_FOUND

    @patch("src.api.routes.tts.get_tts_service")
    def test_list_voices_calls_service_list_voices(self, mock_get_tts, client):
        """Endpoint delegates to tts_service.list_voices(), not generate_speech."""
        mock_tts = Mock()
        mock_tts.list_voices.return_value = ["voice_x"]
        mock_get_tts.return_value = mock_tts

        client.get("/v1/tts/voices")

        mock_tts.list_voices.assert_called_once_with()
        mock_tts.generate_speech.assert_not_called()
```

- [ ] **Step 2: Run to confirm failure**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/api/test_tts_voices_api.py -v
```

Expected: `AttributeError` or 404 errors — the route does not exist yet.

- [ ] **Step 3: Replace tts.py route file entirely**

Write `/home/spow12/codes/2025_lower/DesktopMatePlus/backend/src/api/routes/tts.py`:

```python
"""TTS API routes."""

from fastapi import APIRouter, HTTPException, status

from src.models.tts import VoicesResponse
from src.services import get_tts_service

router = APIRouter(prefix="/v1/tts", tags=["TTS"])


@router.get(
    "/voices",
    summary="List available TTS reference voices",
    response_model=VoicesResponse,
    status_code=status.HTTP_200_OK,
    responses={
        200: {
            "description": "List of available reference voice IDs",
            "content": {
                "application/json": {
                    "example": {"voices": ["aria", "natsume"]}
                }
            },
        },
        503: {
            "description": "TTS service not initialized",
            "content": {
                "application/json": {
                    "example": {"detail": "TTS service not available"}
                }
            },
        },
    },
)
async def list_voices() -> VoicesResponse:
    """List available reference voice IDs.

    Scans the configured ref_audio_dir for valid voice directories
    (each must contain merged_audio.mp3 and combined.lab).

    Returns:
        VoicesResponse: Object containing a list of voice ID strings.

    Raises:
        HTTPException: 503 if TTS service is not initialized.
    """
    tts_service = get_tts_service()
    if tts_service is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="TTS service not available",
        )
    return VoicesResponse(voices=tts_service.list_voices())


__all__ = ["router"]
```

- [ ] **Step 4: Delete the old synthesize test file**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
rm tests/api/test_tts_api_integration.py
```

- [ ] **Step 5: Run the new voices API tests**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/api/test_tts_voices_api.py -v
```

Expected: All 5 tests PASSED.

- [ ] **Step 6: Run full test suite**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest --ignore=tests/api/test_real_e2e.py -v
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add \
  src/api/routes/tts.py \
  tests/api/test_tts_voices_api.py
git rm tests/api/test_tts_api_integration.py
git commit -m "feat(tts): replace POST /synthesize with GET /voices endpoint"
```

---

## Chunk 5: Service manager — EmotionMotionMapper singleton + YAML section + main.py wiring

**Files:**
- Modify: `backend/yaml_files/tts_rules.yml`
- Modify: `backend/src/services/service_manager.py`
- Modify: `backend/src/services/__init__.py`
- Modify: `backend/src/main.py`

- [ ] **Step 1: Add emotion_motion_map section to yaml_files/tts_rules.yml**

Append to the end of `yaml_files/tts_rules.yml`:

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

- [ ] **Step 2: Verify YAML parses cleanly**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run python -c "
import yaml, pathlib
data = yaml.safe_load(pathlib.Path('yaml_files/tts_rules.yml').read_text())
assert 'emotion_motion_map' in data
assert 'joyful' in data['emotion_motion_map']
assert data['emotion_motion_map']['joyful']['motion'] == 'happy_idle'
print('YAML OK — sections:', list(data.keys()))
"
```

- [ ] **Step 3: Add singleton infrastructure to service_manager.py**

Edit `src/services/service_manager.py`:
- Add import: `from src.services.tts_service.emotion_motion_mapper import EmotionMotionMapper`
- Add global: `_emotion_motion_mapper_instance: EmotionMotionMapper | None = None`
- Add at end (before `__all__`):

```python
def initialize_emotion_motion_mapper(
    config_path: str | Path | None = None,
) -> EmotionMotionMapper:
    """Initialize EmotionMotionMapper from yaml_files/tts_rules.yml."""
    global _emotion_motion_mapper_instance

    if config_path is None:
        config_path = (
            Path(__file__).parent.parent.parent / "yaml_files" / "tts_rules.yml"
        )

    config = _load_yaml_config(config_path)
    emotion_map = config.get("emotion_motion_map", {})
    _emotion_motion_mapper_instance = EmotionMotionMapper(emotion_map)
    logger.info("EmotionMotionMapper initialized")
    return _emotion_motion_mapper_instance


def get_emotion_motion_mapper() -> EmotionMotionMapper | None:
    """Get the initialized EmotionMotionMapper instance."""
    return _emotion_motion_mapper_instance
```

- Extend `__all__` to include `"initialize_emotion_motion_mapper"` and `"get_emotion_motion_mapper"`

- [ ] **Step 4: Export new symbols from src/services/__init__.py**

Add `initialize_emotion_motion_mapper` and `get_emotion_motion_mapper` to the import block and `__all__` in `src/services/__init__.py`.

- [ ] **Step 5: Call initialize_emotion_motion_mapper() in main.py lifespan**

Edit `src/main.py`. Add `initialize_emotion_motion_mapper` to the lifespan import, then call it after `initialize_tts_service()`:

```python
            initialize_emotion_motion_mapper()
```

- [ ] **Step 6: Smoke-test the wiring**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run python -c "
from src.services.service_manager import (
    initialize_emotion_motion_mapper,
    get_emotion_motion_mapper,
)
mapper = initialize_emotion_motion_mapper()
motion, blendshape = mapper.map('joyful')
assert motion == 'happy_idle'
assert blendshape == 'smile'
assert get_emotion_motion_mapper() is mapper
print('All assertions passed.')
"
```

- [ ] **Step 7: Run full test suite**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest --ignore=tests/api/test_real_e2e.py -v
```

- [ ] **Step 8: Commit**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add \
  yaml_files/tts_rules.yml \
  src/services/service_manager.py \
  src/services/__init__.py \
  src/main.py
git commit -m "feat(tts): wire EmotionMotionMapper singleton into service_manager and lifespan"
```

---

## Chunk 6: Cleanup — delete legacy doc, lint

- [ ] **Step 1: Delete the legacy API doc**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git rm docs/api/TTS_Synthesize.md
```

- [ ] **Step 2: Run lint check**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
sh scripts/lint.sh
```

- [ ] **Step 3: Final full test suite run**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest --ignore=tests/api/test_real_e2e.py -v
```

- [ ] **Step 4: Final commit**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add -u
git commit -m "chore(tts): delete legacy TTS_Synthesize.md API doc"
```

---

## Implementation Order Summary

| Chunk | What | Depends On |
|-------|------|------------|
| 1 | EmotionMotionMapper class + tests | None |
| 2 | list_voices() on abstract + VLLMOmni + FishSpeech | None |
| 3 | Replace tts.py models | None |
| 4 | New route + delete old route + delete old tests | Chunks 2 & 3 |
| 5 | YAML + service_manager + main.py wiring | Chunk 1 |
| 6 | Delete doc + lint | All above |
