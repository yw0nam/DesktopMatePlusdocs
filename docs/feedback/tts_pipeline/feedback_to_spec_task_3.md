## Architecture Overview

전체 아키텍처 건강도: 🔴 (Significant issues - 이전 단계에서 합의된 설계 원칙(Dumb UI)을 위배하고 죽은 개념을 부활시킴)


비동기 I/O 처리를 위해 `asyncio.to_thread`를 사용하여 동기 함수인 `generate_speech`를 감싼 것은 정확하고 훌륭한 접근입니다. 성공과 실패 시나리오를 분기하여 `audio_base64`에 적절히 데이터를 담거나 `None`을 할당하는 논리 흐름도 완벽합니다. 단, 존재해서는 안 될 `WarningMessage`를 생성하고 반환하느라 함수의 시그니처가 불필요하게 복잡해졌습니다.

## Step 1 Findings — Questionable Requirements

* **[CRITICAL] `tuple[TtsChunkMessage, WarningMessage | None]` 반환 타입:** 이 함수는 왜 튜플을 반환합니까? T1에서 결정했듯 프론트엔드는 에러 상세 내역을 알 필요가 없습니다. 호출자(Caller)에게 `WarningMessage`를 넘겨서 호출자가 다시 WebSocket으로 쏘게 만들려는 의도라면, 당장 멈추십시오. 이 함수는 오직 완성된 `TtsChunkMessage` 단 하나만 반환해야 합니다.

## Step 2 Findings — Candidates for Deletion

* **[CRITICAL] `WarningMessage` 관련 모든 로직:** * `from src.models.websocket import WarningMessage` 임포트 삭제.
* `warning` 변수 초기화 및 할당 로직 삭제.
* 함수의 return 문에서 `warning` 반환 삭제 (`return chunk_msg` 로 끝낼 것).



## Step 3 Findings — Simplification Opportunities

* **[IMPORTANT] 백엔드 로깅으로 대체:** 에러가 났을 때 `WarningMessage` 객체를 만드는 대신, 파이썬 표준 `logging` (또는 프로젝트에서 사용하는 로거)을 사용하여 백엔드 로그에 에러를 기록하십시오. 코드가 훨씬 간결해집니다.

```python
import logging
from asyncio import to_thread
from src.models.websocket import TtsChunkMessage
from src.services.tts_service.service import TTSService
from src.services.tts_service.emotion_motion_mapper import EmotionMotionMapper

logger = logging.getLogger(__name__)

async def synthesize_chunk(
    tts_service: TTSService,
    mapper: EmotionMotionMapper,
    text: str,
    emotion: str | None,
    sequence: int,
    tts_enabled: bool = True,
    reference_id: str | None = None,
) -> TtsChunkMessage:
    motion_name, blendshape_name = mapper.map(emotion)
    audio: str | None = None

    if tts_enabled:
        try:
            result = await to_thread(
                tts_service.generate_speech, text, reference_id, "base64", "mp3"
            )
            if result is None:
                raise ValueError("generate_speech returned None")
            audio = result
        except Exception as e:
            # 클라이언트에게 보내지 않고 백엔드에만 기록합니다.
            logger.error(f"TTS synthesis failed for sequence {sequence}: {e}", exc_info=True)
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
Note, 실제 로깅 코드는 backend/docs/guidelines/LOGGING_GUIDE.md 패턴을 참조.

## Step 4 Findings — Cycle Time Blockers

* 해당 사항 없습니다.

## Step 5 Findings — Automation Assessment

* **[IMPORTANT] 단위 테스트 갱신:** 함수가 더 이상 튜플을 반환하지 않으므로, 제안하신 단위 테스트 코드도 수정되어야 합니다. `chunk, warning = await synthesize_chunk(...)` 형태의 테스트 코드를 모두 `chunk = await synthesize_chunk(...)`로 변경하십시오. 에러 발생 시나리오 테스트에서는 `audio_base64 is None`인지와 `logger.error`가 호출되었는지(Mocking) 확인하는 것으로 족합니다.

---

## Priority Actions

1. **반환 타입 단순화:** 함수의 리턴 타입을 `TtsChunkMessage` 단일 객체로 변경하십시오.
2. **`WarningMessage` 완전 폐기:** 코드 내부의 객체 생성 및 반환 로직을 백엔드 `logger.error()` 로 교체하십시오.
3. **테스트 코드 수정:** 튜플 반환을 기대하는 기존 테스트 코드를 단일 객체 반환에 맞게 수정하십시오.