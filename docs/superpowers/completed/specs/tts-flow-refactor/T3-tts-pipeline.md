# T3: TTS 파이프라인 (synthesize_chunk)

**선행 조건**: T1 완료 (`TtsChunkMessage` 모델 필요)
**차단 대상**: T4

---

## 목표

`synthesize_chunk()` 비동기 파이프라인 구현.
텍스트 + emotion → TTS 합성 + motion 매핑 → `TtsChunkMessage` 반환.
실패/비활성 시 `audio_base64=null`로 반환. 가짜 무음 데이터 없음.

---

## 신규 파일

### `src/services/tts_service/tts_pipeline.py`

```python
from asyncio import to_thread
from src.core.logger import logger
from src.models.websocket import TtsChunkMessage
from src.services.tts_service.service import TTSService
from src.services.tts_service.emotion_motion_mapper import EmotionMotionMapper


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
    항상 TtsChunkMessage 단일 객체를 반환한다.

    동작:
    - tts_enabled=True: asyncio.to_thread()로 generate_speech() 호출
    - tts_enabled=False: TTS API 호출 스킵, audio_base64=None
    - 실패 시: audio_base64=None, 에러는 백엔드 로그에만 기록

    반환값:
    - TtsChunkMessage.audio_base64 = None 이면 FE는 오디오 재생만 스킵
    - motion/blendshape는 항상 포함 (캐릭터 애니메이션 유지)
    """
    motion_name, blendshape_name = mapper.map(emotion)
    audio: str | None = None

    if tts_enabled:
        try:
            # generate_speech()는 동기 함수이므로 asyncio.to_thread()로 실행
            # callable + args 형태로 호출 (pre-call 아님)
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
            # 클라이언트에게 보내지 않고 백엔드에만 기록
            logger.error(f"TTS synthesis failed for sequence {sequence}: {e}")
            audio = None
    # tts_enabled=False: audio=None (정상 상태)

    return TtsChunkMessage(
        sequence=sequence,
        text=text,
        audio_base64=audio,
        emotion=emotion,
        motion_name=motion_name,
        blendshape_name=blendshape_name,
    )
```

---

## 인터페이스 계약

| 입력 | 타입 | 설명 |
| --- | --- | --- |
| `tts_service` | `TTSService` | TTS 엔진 인스턴스 |
| `mapper` | `EmotionMotionMapper` | emotion → motion 매핑 |
| `text` | `str` | TTS 합성할 텍스트 |
| `emotion` | `str \| None` | 감지된 emotion 태그 |
| `sequence` | `int` | turn 내 순서 번호 |
| `tts_enabled` | `bool` | False면 TTS API 스킵 |
| `reference_id` | `str \| None` | 참조 voice ID. None이면 엔진 기본값 |

| 반환 | 타입 | 설명 |
| --- | --- | --- |
| `TtsChunkMessage` | 항상 반환 | `audio_base64`는 성공 시 str, 실패/비활성 시 None |

**예외를 발생시키지 않는다.** 모든 에러는 백엔드 로깅패턴에 따라 error로 기록하고 `audio_base64=None`으로 처리.

---

## 테스트

**중요**: `generate_speech`는 외부 TTS 엔진 호출이므로 **반드시 Mock**. CI에서 실제 엔진 불필요.

### 단위 테스트

```python
from unittest.mock import MagicMock, patch

@pytest.mark.asyncio
async def test_synthesize_chunk_success():
    """TTS 성공: audio_base64 비null."""
    tts_service = MagicMock()
    tts_service.generate_speech.return_value = "base64encodedaudio=="
    mapper = MagicMock()
    mapper.map.return_value = ("happy_idle", "smile")

    chunk = await synthesize_chunk(
        tts_service, mapper, "안녕", "joyful", 0, tts_enabled=True
    )
    assert chunk.audio_base64 == "base64encodedaudio=="
    assert chunk.motion_name == "happy_idle"
    tts_service.generate_speech.assert_called_once()

@pytest.mark.asyncio
async def test_synthesize_chunk_generate_speech_returns_none():
    """generate_speech None 반환: audio=None, logger.error 호출."""
    tts_service = MagicMock()
    tts_service.generate_speech.return_value = None
    mapper = MagicMock()
    mapper.map.return_value = ("neutral_idle", "neutral")

    with patch("src.services.tts_service.tts_pipeline.logger") as mock_logger:
        chunk = await synthesize_chunk(tts_service, mapper, "텍스트", None, 1, True)
        assert chunk.audio_base64 is None
        mock_logger.error.assert_called_once()

@pytest.mark.asyncio
async def test_synthesize_chunk_exception():
    """generate_speech 예외: audio=None, logger.error 호출."""
    tts_service = MagicMock()
    tts_service.generate_speech.side_effect = ConnectionError("TTS server down")
    mapper = MagicMock()
    mapper.map.return_value = ("neutral_idle", "neutral")

    with patch("src.services.tts_service.tts_pipeline.logger") as mock_logger:
        chunk = await synthesize_chunk(tts_service, mapper, "텍스트", None, 2, True)
        assert chunk.audio_base64 is None
        mock_logger.error.assert_called_once()

@pytest.mark.asyncio
async def test_synthesize_chunk_tts_disabled():
    """tts_enabled=False: audio=None, generate_speech 미호출."""
    tts_service = MagicMock()
    mapper = MagicMock()
    mapper.map.return_value = ("sad_idle", "sad")

    chunk = await synthesize_chunk(tts_service, mapper, "텍스트", "sad", 3, False)
    assert chunk.audio_base64 is None
    tts_service.generate_speech.assert_not_called()
    assert chunk.motion_name == "sad_idle"
```

### 검증 기준

- 4가지 시나리오 모두 커버 (성공, None 반환, 예외, 비활성)
- `generate_speech`가 실제로 호출되지 않음 확인 (`assert_not_called()`)
- 반환 타입이 항상 `TtsChunkMessage` 단일 객체
- 에러 시나리오에서 `logger.error` 호출 확인 (Mock)
