# T4: EventHandler 파이프라인 통합

**선행 조건**: T3 완료 (`synthesize_chunk()` 사용)
**차단 대상**: T5

---

## 목표

`EventHandler`에서 기존 `_build_tts_event()` → `_synthesize_and_send()` 교체.
각 sentence마다 TTS 합성을 `asyncio.create_task()`로 병렬 실행.
`is_closing` 체크로 연결 끊김 시 조용히 drop.

---

## 변경 파일

### `src/services/websocket_service/message_processor/event_handlers.py`

#### 현재 → 변경 후

| 항목 | AS-IS | TO-BE |
| --- | --- | --- |
| TTS 처리 | `_build_tts_event()` 동기 호출 → `tts_ready_chunk` 이벤트 put | `asyncio.create_task(_synthesize_and_send())` |
| 이벤트 타입 | `tts_ready_chunk` | `tts_chunk` |
| sequence 관리 | 없음 | `tts_sequence: int` 카운터 (`ConversationTurn` 소유) |
| task 추적 | 없음 | `turn.tts_tasks` + `_task_manager.track_task()` 양쪽 등록 |
| 연결 끊김 처리 | 없음 | `is_closing` 체크 후 조용히 drop |

#### `EventHandler.__init__()` 변경

```python
def __init__(self, processor: MessageProcessor):
    self.processor = processor
    # tts_service, mapper는 processor를 통해 접근
    # processor.tts_service, processor.mapper
    # sequence 카운터는 ConversationTurn 소유 (turn.tts_sequence)
```

#### `_build_tts_event()` — **삭제**

#### `_synthesize_and_send()` — **신규**

```python
async def _synthesize_and_send(
    self,
    turn_id: str,
    text: str,
    emotion: str | None,
    sequence: int,
    tts_enabled: bool,
    reference_id: str | None,
) -> None:
    """
    TTS 합성 후 이벤트 큐에 put.
    is_closing이면 조용히 drop.
    """
    # 연결 종료 중이면 스킵
    if self.processor.is_connection_closing():
        return

    chunk_msg = await synthesize_chunk(
        tts_service=self.processor.tts_service,
        mapper=self.processor.mapper,
        text=text,
        emotion=emotion,
        sequence=sequence,
        tts_enabled=tts_enabled,
        reference_id=reference_id,
    )

    # 연결 종료 중이면 drop
    if self.processor.is_connection_closing():
        return

    await self.processor._put_event(turn_id, {
        "type": "tts_chunk",
        "sequence": chunk_msg.sequence,
        "text": chunk_msg.text,
        "audio_base64": chunk_msg.audio_base64,
        "emotion": chunk_msg.emotion,
        "motion_name": chunk_msg.motion_name,
        "blendshape_name": chunk_msg.blendshape_name,
    })
```

#### `_process_token_event()` 변경

기존 `_build_tts_event()` 호출 부분을 교체:

```python
# AS-IS
tts_event = self._build_tts_event(turn_id, base_event, filtered_text, emotion_tag)
await self.processor._put_event(turn_id, tts_event)

# TO-BE
task = asyncio.create_task(
    self._synthesize_and_send(
        turn_id=turn_id,
        text=filtered_text,
        emotion=emotion_tag,
        sequence=turn.tts_sequence,
        tts_enabled=turn.tts_enabled,
        reference_id=turn.reference_id,
    )
)
turn.tts_sequence += 1
turn.tts_tasks.append(task)
self.processor._task_manager.track_task(task)  # cleanup()에서 cancel 가능
```

#### `_flush_tts_buffer()` 변경

동일하게 `asyncio.create_task(_synthesize_and_send(...))` 패턴 적용.

---

### `src/services/websocket_service/message_processor/models.py`

`ConversationTurn`에 필드 추가:

```python
@dataclass
class ConversationTurn:
    # ... 기존 필드 ...
    tts_enabled: bool = True
    reference_id: str | None = None
    tts_tasks: list[asyncio.Task] = field(default_factory=list)  # barrier용
    tts_sequence: int = 0  # 이 Turn에서 발급할 다음 시퀀스 번호
```

---

### `src/services/websocket_service/message_processor/processor.py`

#### `MessageProcessor` 초기화 변경

```python
class MessageProcessor:
    def __init__(
        self,
        # ... 기존 파라미터 ...
        tts_service: TTSService,
        mapper: EmotionMotionMapper,
    ):
        self.tts_service = tts_service
        self.mapper = mapper
```

#### `start_turn()` 변경

```python
def start_turn(
    self,
    # ... 기존 파라미터 ...
    tts_enabled: bool = True,
    reference_id: str | None = None,
) -> ConversationTurn:
    turn = ConversationTurn(
        # ... 기존 필드 ...
        tts_enabled=tts_enabled,
        reference_id=reference_id,
        tts_tasks=[],
        tts_sequence=0,
    )
```

---

### `src/services/websocket_service/manager/handlers.py`

`handle_chat_message()` 내 `chat_message` 파싱 부분:

```python
# 기존
tts_enabled = data.get("tts_enabled", True)
reference_id = data.get("reference_id", None)

# MessageProcessor.start_turn()에 전달
processor.start_turn(
    # ... 기존 파라미터 ...
    tts_enabled=tts_enabled,
    reference_id=reference_id,
)
```

`tts_service`, `mapper`를 `MessageProcessor` 생성 시 주입:

```python
tts_service = get_tts_service()
mapper = get_emotion_motion_mapper()
processor = MessageProcessor(..., tts_service=tts_service, mapper=mapper)
```

---

## 테스트

**중요**: `synthesize_chunk` 자체는 T3에서 테스트 완료. T4는 `synthesize_chunk`를 mock하고 `EventHandler`의 orchestration 로직만 테스트.

### 단위 테스트

```python
@pytest.mark.asyncio
async def test_synthesize_and_send_success():
    """정상: tts_chunk 이벤트 큐에 put."""
    with patch("...synthesize_chunk") as mock_synth:
        mock_synth.return_value = TtsChunkMessage(audio_base64="base64...", ...)
        await event_handler._synthesize_and_send(...)
        # 검증: tts_chunk 이벤트 1회 put 확인
        processor._put_event.assert_called_once()
        call_args = processor._put_event.call_args[0][1]
        assert call_args["type"] == "tts_chunk"

@pytest.mark.asyncio
async def test_synthesize_and_send_tts_failure():
    """TTS 실패: audio_base64=None인 tts_chunk 단일 전송 (warning 없음)."""
    with patch("...synthesize_chunk") as mock_synth:
        mock_synth.return_value = TtsChunkMessage(audio_base64=None, ...)
        await event_handler._synthesize_and_send(...)
        processor._put_event.assert_called_once()
        call_args = processor._put_event.call_args[0][1]
        assert call_args["type"] == "tts_chunk"
        assert call_args["audio_base64"] is None

@pytest.mark.asyncio
async def test_synthesize_and_send_is_closing_drop():
    """is_closing=True: 조용히 drop, 이벤트 미전송."""
    # processor.is_connection_closing() → True 반환하도록 mock
    # 검증: _put_event 미호출
    processor.is_connection_closing.return_value = True
    await event_handler._synthesize_and_send(...)
    processor._put_event.assert_not_called()

@pytest.mark.asyncio
async def test_tts_task_registered_in_both_lists():
    """create_task 결과가 turn.tts_tasks + _task_manager.track_task() 양쪽에 등록."""

@pytest.mark.asyncio
async def test_tts_sequence_increments_per_turn():
    """turn.tts_sequence가 청크마다 단조 증가."""
    # _process_token_event() 2회 호출 후 turn.tts_sequence == 2 확인
```

### 검증 기준

- `_build_tts_event()` 관련 테스트 전부 삭제
- `tts_ready_chunk` 이벤트 생성 코드 없음 확인
- `turn.tts_sequence`가 turn 시작 시 0, 청크마다 단조 증가 확인
- 에러 발생 시 warning 이벤트 전송 없이 `audio_base64=None` tts_chunk만 전송 확인
