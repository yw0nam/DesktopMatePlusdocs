# T4: EventHandler 파이프라인 통합 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace synchronous `_build_tts_event()` with async `_synthesize_and_send()` using `asyncio.create_task()` for parallel TTS synthesis per sentence

**Architecture:** EventHandler calls `synthesize_chunk()` via `create_task` (fire-and-forget), task tracked in `ConversationTurn.tts_tasks` for barrier in T5. Connection-closing check prevents orphaned events. `tts_service` and `mapper` are injected into `MessageProcessor` constructor and accessed via `self.processor`.

**Prerequisites:** T1 (`TtsChunkMessage`, `MessageType.TTS_CHUNK` in `src/models/websocket.py`), T2 (`EmotionMotionMapper` in `src/services/tts_service/emotion_motion_mapper.py`, `get_emotion_motion_mapper()` in `service_manager.py`), T3 (`synthesize_chunk()` in `src/services/tts_service/tts_pipeline.py`)

**Tech Stack:** Python 3.13, asyncio, pytest-asyncio, MagicMock, AsyncMock, uv

---

## Critical Observations from Codebase Exploration

Before starting, note these discrepancies between the spec and the actual codebase:

1. **`track_task()` signature**: The existing `TaskManager.track_task()` takes `(turn_id: str, task: asyncio.Task)` — use the correct two-argument form: `self.processor._task_manager.track_task(turn_id, task)`.

2. **`is_connection_closing()` does not exist yet**: Must be added to `MessageProcessor`. Checks `self._shutdown_event.is_set()`.

3. **Existing tests referencing `tts_ready_chunk`**: `tests/core/test_message_processor_stream_pipeline.py`, `tests/core/test_message_processor.py`, and `tests/websocket/test_websocket_service.py` all assert `"tts_ready_chunk"` event type. These tests must be updated in T4.

4. **`MessageProcessor.__init__` currently takes `(connection_id, user_id, *, queue_maxsize)`** — `tts_service` and `mapper` are new required parameters. All existing tests that instantiate `MessageProcessor` without these params will fail and must be updated.

5. **`ConversationTurn` uses `tasks: Set[asyncio.Task]`** (existing) for general tracking. The new `tts_tasks: list[asyncio.Task]` field is separate and used only for T5 barrier.

---

## Chunk 1: `ConversationTurn` — add TTS fields

**Files:**
- Modify: `backend/src/services/websocket_service/message_processor/models.py`
- Modify: `backend/tests/core/test_message_processor.py`

### Task 1: Add TTS fields to ConversationTurn (TDD)

- [ ] **Step 1: Write failing test**

In `tests/core/test_message_processor.py`, add:

```python
def test_conversation_turn_tts_fields_defaults():
    turn = ConversationTurn(turn_id="t1", user_message="hi", session_id="s1")
    assert turn.tts_enabled is True
    assert turn.reference_id is None
    assert turn.tts_tasks == []
    assert turn.tts_sequence == 0
```

- [ ] **Step 2: Run to confirm RED**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/core/test_message_processor.py::test_conversation_turn_tts_fields_defaults -v
```

Expected: `AttributeError` — fields don't exist yet.

- [ ] **Step 3: Add fields to `ConversationTurn` in `models.py`**

After the existing `tts_processor` field, add:

```python
tts_enabled: bool = True
reference_id: str | None = None
tts_tasks: list[asyncio.Task] = field(default_factory=list)
tts_sequence: int = 0
```

- [ ] **Step 4: Run to confirm GREEN**

```bash
uv run pytest tests/core/test_message_processor.py::test_conversation_turn_tts_fields_defaults -v
```

---

## Chunk 2: `MessageProcessor` — add `tts_service`, `mapper`, `is_connection_closing()`

**Files:**
- Modify: `backend/src/services/websocket_service/message_processor/processor.py`

### Task 2: Update MessageProcessor constructor and add is_connection_closing()

- [ ] **Step 1: Write failing tests**

In `tests/core/test_message_processor.py`, add:

```python
def test_processor_stores_tts_service_and_mapper():
    from unittest.mock import MagicMock
    tts_service = MagicMock()
    mapper = MagicMock()
    proc = MessageProcessor(
        connection_id=uuid4(), user_id="u",
        tts_service=tts_service, mapper=mapper
    )
    assert proc.tts_service is tts_service
    assert proc.mapper is mapper


def test_is_connection_closing_false_by_default():
    from unittest.mock import MagicMock
    proc = MessageProcessor(
        connection_id=uuid4(), user_id="u",
        tts_service=MagicMock(), mapper=MagicMock()
    )
    assert proc.is_connection_closing() is False


@pytest.mark.asyncio
async def test_is_connection_closing_true_after_shutdown():
    from unittest.mock import MagicMock
    proc = MessageProcessor(
        connection_id=uuid4(), user_id="u",
        tts_service=MagicMock(), mapper=MagicMock()
    )
    await proc.shutdown(cleanup_delay=0)
    assert proc.is_connection_closing() is True
```

- [ ] **Step 2: Run to confirm RED**

```bash
uv run pytest tests/core/test_message_processor.py -k "tts_service_and_mapper or is_connection_closing" -v
```

- [ ] **Step 3: Update `processor.py`**

Add imports:

```python
from src.services.tts_service.service import TTSService
from src.services.tts_service.emotion_motion_mapper import EmotionMotionMapper
```

Update `__init__` signature:

```python
def __init__(
    self,
    connection_id: UUID,
    user_id: str,
    *,
    tts_service: TTSService,
    mapper: EmotionMotionMapper,
    queue_maxsize: int = 100,
):
```

Inside `__init__`, add:

```python
self.tts_service = tts_service
self.mapper = mapper
```

Add `is_connection_closing()` method:

```python
def is_connection_closing(self) -> bool:
    """Return True if shutdown has been requested for this processor."""
    return self._shutdown_event.is_set()
```

Update `start_turn()` signature and `ConversationTurn` construction:

```python
async def start_turn(
    self,
    session_id: str,
    user_input: str,
    *,
    agent_stream: Optional[AsyncIterator[Dict[str, Any]]] = None,
    metadata: Optional[Dict[str, Any]] = None,
    tts_enabled: bool = True,
    reference_id: str | None = None,
) -> str:
    ...
    turn = ConversationTurn(
        turn_id=turn_id,
        user_message=user_input,
        session_id=session_id,
        metadata=metadata or {},
        tts_enabled=tts_enabled,
        reference_id=reference_id,
        tts_tasks=[],
        tts_sequence=0,
    )
```

- [ ] **Step 4: Run to confirm GREEN**

```bash
uv run pytest tests/core/test_message_processor.py -k "tts_service_and_mapper or is_connection_closing" -v
```

- [ ] **Step 5: Fix all existing tests broken by new required params**

Update `@pytest.fixture def processor()` in ALL test files that use `MessageProcessor`:

```python
# In tests/core/test_message_processor.py, tests/core/test_message_processor_stream_pipeline.py
@pytest.fixture
async def processor():
    from unittest.mock import MagicMock
    mp = MessageProcessor(
        connection_id=uuid4(), user_id="test_user",
        tts_service=MagicMock(), mapper=MagicMock()
    )
    try:
        yield mp
    finally:
        await mp.shutdown(cleanup_delay=0)
```

In `tests/websocket/test_websocket_service.py`, update any direct `MessageProcessor(...)` instantiation to include `tts_service=MagicMock()` and `mapper=MagicMock()`.

```bash
# Run full test suite to find all breakage
uv run pytest tests/ -v --tb=short 2>&1 | grep FAILED
```

---

## Chunk 3: `EventHandler` — add `_synthesize_and_send()`, remove `_build_tts_event()`

**Files:**
- Modify: `backend/src/services/websocket_service/message_processor/event_handlers.py`
- Create: `backend/tests/core/test_event_handler_tts.py`

### Task 3: Write tests for _synthesize_and_send() orchestration

- [ ] **Step 1: Create `tests/core/test_event_handler_tts.py`**

```python
"""Tests for EventHandler._synthesize_and_send() orchestration."""
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from src.services.websocket_service.message_processor.models import ConversationTurn
from src.services.websocket_service.message_processor.event_handlers import EventHandler


def _make_processor(turn_id: str, is_closing: bool = False):
    """Build a minimal mock MessageProcessor."""
    proc = MagicMock()
    proc.is_connection_closing.return_value = is_closing
    proc._put_event = AsyncMock()
    proc._task_manager = MagicMock()
    proc._task_manager.track_task = MagicMock()

    turn = ConversationTurn(
        turn_id=turn_id, user_message="hi", session_id="s1",
        tts_enabled=True, reference_id=None, tts_tasks=[], tts_sequence=0
    )
    turn.event_queue = asyncio.Queue()
    proc.turns = {turn_id: turn}
    proc.tts_service = MagicMock()
    proc.mapper = MagicMock()
    return proc, turn


@pytest.mark.asyncio
async def test_synthesize_and_send_success():
    """Success: _put_event called once with type=='tts_chunk'."""
    from src.models.websocket import TtsChunkMessage

    turn_id = "t1"
    proc, turn = _make_processor(turn_id)
    handler = EventHandler(proc)

    fake_chunk = TtsChunkMessage(
        sequence=0, text="Hello", audio_base64="abc123",
        emotion="joyful", motion_name="happy_idle", blendshape_name="smile"
    )

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(return_value=fake_chunk)
    ):
        await handler._synthesize_and_send(
            turn_id=turn_id, text="Hello", emotion="joyful",
            sequence=0, tts_enabled=True, reference_id=None,
        )

    proc._put_event.assert_called_once()
    call_event = proc._put_event.call_args[0][1]
    assert call_event["type"] == "tts_chunk"
    assert call_event["audio_base64"] == "abc123"
    assert call_event["sequence"] == 0


@pytest.mark.asyncio
async def test_synthesize_and_send_tts_failure_still_puts_chunk():
    """TTS failure: audio_base64=None still puts tts_chunk, no warning."""
    from src.models.websocket import TtsChunkMessage

    turn_id = "t2"
    proc, turn = _make_processor(turn_id)
    handler = EventHandler(proc)

    fake_chunk = TtsChunkMessage(
        sequence=1, text="Hi", audio_base64=None,
        emotion=None, motion_name="neutral_idle", blendshape_name="neutral"
    )

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(return_value=fake_chunk)
    ):
        await handler._synthesize_and_send(
            turn_id=turn_id, text="Hi", emotion=None,
            sequence=1, tts_enabled=True, reference_id=None,
        )

    proc._put_event.assert_called_once()
    call_event = proc._put_event.call_args[0][1]
    assert call_event["type"] == "tts_chunk"
    assert call_event["audio_base64"] is None


@pytest.mark.asyncio
async def test_synthesize_and_send_is_closing_drops_silently():
    """is_closing=True before synthesize: no _put_event call, no synthesize_chunk call."""
    turn_id = "t3"
    proc, turn = _make_processor(turn_id, is_closing=True)
    handler = EventHandler(proc)

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock()
    ) as mock_synth:
        await handler._synthesize_and_send(
            turn_id=turn_id, text="Test", emotion=None,
            sequence=0, tts_enabled=True, reference_id=None,
        )

    proc._put_event.assert_not_called()
    mock_synth.assert_not_called()


@pytest.mark.asyncio
async def test_tts_task_registered_in_both_lists():
    """create_task result is in turn.tts_tasks AND passed to _task_manager.track_task."""
    from src.models.websocket import TtsChunkMessage

    turn_id = "t4"
    proc, turn = _make_processor(turn_id)
    handler = EventHandler(proc)

    fake_chunk = TtsChunkMessage(
        sequence=0, text="test", audio_base64=None,
        motion_name="neutral_idle", blendshape_name="neutral"
    )

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(return_value=fake_chunk)
    ):
        task = asyncio.create_task(
            handler._synthesize_and_send(
                turn_id=turn_id, text="test", emotion=None,
                sequence=turn.tts_sequence, tts_enabled=turn.tts_enabled,
                reference_id=turn.reference_id,
            )
        )
        turn.tts_sequence += 1
        turn.tts_tasks.append(task)
        proc._task_manager.track_task(turn_id, task)
        await task

    assert len(turn.tts_tasks) == 1
    proc._task_manager.track_task.assert_called_once_with(turn_id, task)


@pytest.mark.asyncio
async def test_tts_sequence_increments_per_chunk():
    """turn.tts_sequence increments monotonically: after 2 calls == 2."""
    from src.models.websocket import TtsChunkMessage

    turn_id = "t5"
    proc, turn = _make_processor(turn_id)
    handler = EventHandler(proc)

    def make_chunk(seq):
        return TtsChunkMessage(
            sequence=seq, text="text", audio_base64=None,
            motion_name="neutral_idle", blendshape_name="neutral"
        )

    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(side_effect=[make_chunk(0), make_chunk(1)])
    ):
        task1 = asyncio.create_task(
            handler._synthesize_and_send(
                turn_id=turn_id, text="sentence one", emotion=None,
                sequence=turn.tts_sequence, tts_enabled=True, reference_id=None,
            )
        )
        turn.tts_sequence += 1
        turn.tts_tasks.append(task1)

        task2 = asyncio.create_task(
            handler._synthesize_and_send(
                turn_id=turn_id, text="sentence two", emotion=None,
                sequence=turn.tts_sequence, tts_enabled=True, reference_id=None,
            )
        )
        turn.tts_sequence += 1
        turn.tts_tasks.append(task2)

        await asyncio.gather(task1, task2)

    assert turn.tts_sequence == 2
    assert len(turn.tts_tasks) == 2
```

- [ ] **Step 2: Run to confirm RED**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/core/test_event_handler_tts.py -v
```

- [ ] **Step 3: Add `_synthesize_and_send()` to `event_handlers.py`**

Add import:

```python
from src.services.tts_service.tts_pipeline import synthesize_chunk
```

Add method:

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
    """TTS synthesis + event enqueue. Silent drop if connection is closing."""
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

- [ ] **Step 4: Run to confirm GREEN**

```bash
uv run pytest tests/core/test_event_handler_tts.py -v
```

---

## Chunk 4: Replace `_build_tts_event()` calls with `asyncio.create_task(_synthesize_and_send())`

**Files:**
- Modify: `backend/src/services/websocket_service/message_processor/event_handlers.py`

### Task 4: Replace call sites

- [ ] **Step 1: Update `_process_token_event()` — replace `_build_tts_event()` block**

Find this block (approximately lines 176–185):
```python
tts_event = self._build_tts_event(turn_id, token_event, text, processed.emotion_tag)
logger.info(f"Emitting tts_ready_chunk for turn {turn_id}: ...")
await self.processor._put_event(turn_id, tts_event)
```

Replace with:
```python
task = asyncio.create_task(
    self._synthesize_and_send(
        turn_id=turn_id,
        text=text,
        emotion=processed.emotion_tag,
        sequence=turn.tts_sequence,
        tts_enabled=turn.tts_enabled,
        reference_id=turn.reference_id,
    )
)
turn.tts_sequence += 1
turn.tts_tasks.append(task)
self.processor._task_manager.track_task(turn_id, task)
logger.info(
    f"Scheduled TTS task (seq={turn.tts_sequence - 1}) for turn {turn_id}: "
    f"{repr(text[:50]) if len(text) > 50 else repr(text)}"
)
```

- [ ] **Step 2: Update `_flush_tts_buffer()` — same pattern**

Find similar block and replace with:
```python
task = asyncio.create_task(
    self._synthesize_and_send(
        turn_id=turn_id,
        text=text,
        emotion=processed.emotion_tag,
        sequence=turn.tts_sequence,
        tts_enabled=turn.tts_enabled,
        reference_id=turn.reference_id,
    )
)
turn.tts_sequence += 1
turn.tts_tasks.append(task)
self.processor._task_manager.track_task(turn_id, task)
logger.info(
    f"Scheduled flush TTS task (seq={turn.tts_sequence - 1}) for turn {turn_id}: "
    f"{repr(text[:50]) if len(text) > 50 else repr(text)}"
)
```

- [ ] **Step 3: Delete `_build_tts_event()` method entirely**

Remove the entire `_build_tts_event()` method.

- [ ] **Step 4: Run T4 tests**

```bash
uv run pytest tests/core/test_event_handler_tts.py -v
```

---

## Chunk 5: Update `handlers.py` — inject services + extract fields

**Files:**
- Modify: `backend/src/services/websocket_service/manager/handlers.py`

- [ ] **Step 1: Add import for `get_emotion_motion_mapper`**

```python
from src.services.service_manager import get_emotion_motion_mapper
```

- [ ] **Step 2: Update `MessageProcessor` construction in `handle_authorize()`**

```python
connection_state.message_processor = MessageProcessor(
    connection_id=connection_id,
    user_id=user_id,
    tts_service=get_tts_service(),
    mapper=get_emotion_motion_mapper(),
)
```

- [ ] **Step 3: Extract `tts_enabled` and `reference_id` in `handle_chat_message()`**

After existing field extractions:
```python
tts_enabled = message_data.get("tts_enabled", True)
reference_id = message_data.get("reference_id", None)
```

Update `start_turn()` call:
```python
turn_id = await connection_state.message_processor.start_turn(
    session_id=session_id,
    user_input=content,
    agent_stream=agent_stream,
    metadata=metadata,
    tts_enabled=tts_enabled,
    reference_id=reference_id,
)
```

- [ ] **Step 4: Run handler tests**

```bash
uv run pytest tests/websocket/ -v
```

---

## Chunk 6: Delete legacy `tts_ready_chunk` references, update impacted tests

**Files:**
- Modify: `backend/tests/core/test_message_processor_stream_pipeline.py`
- Modify: `backend/tests/core/test_message_processor.py`
- Modify: `backend/tests/websocket/test_websocket_service.py`

- [ ] **Step 1: Update `test_message_processor_stream_pipeline.py`**

For each test asserting `"tts_ready_chunk"`:
- Mock `synthesize_chunk` to return a `TtsChunkMessage` immediately
- Change `tts_ready_chunk` → `tts_chunk` in event type assertions

Example pattern:
```python
from unittest.mock import AsyncMock, patch
from src.models.websocket import TtsChunkMessage

@pytest.mark.asyncio
async def test_stream_tokens_emit_tts_chunks(processor):
    fake_chunk = TtsChunkMessage(
        sequence=0, text="Hello", audio_base64="abc",
        motion_name="idle", blendshape_name="neutral"
    )
    with patch(
        "src.services.websocket_service.message_processor.event_handlers.synthesize_chunk",
        new=AsyncMock(return_value=fake_chunk)
    ):
        # ... run test, assert "tts_chunk" in event_types
```

- [ ] **Step 2: Update `test_websocket_service.py`**

- Line 283: `assert "tts_chunk" in event_types`
- Line 288: `event for event in sent_events if event.get("type") == "tts_chunk"`
- Line 290: `assert tts_events, "Expected at least one tts_chunk event"`
- Line 495: change `"tts_ready_chunk"` → `"tts_chunk"` in fake events
- Line 520: `assert sent_payloads[1]["type"] == "tts_chunk"`
- Line 544: change `"tts_ready_chunk"` → `"tts_chunk"`

- [ ] **Step 3: Verify no legacy references remain in source**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
grep -r "tts_ready_chunk" src/
grep -r "_build_tts_event" src/ tests/
```

Expected: 0 matches in `src/`. Tests updated to `tts_chunk`.

---

## Chunk 7: Final validation + lint + commit

- [ ] **Step 1: Full test suite**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/ -v
```

- [ ] **Step 2: Lint**

```bash
sh scripts/lint.sh
```

- [ ] **Step 3: Commit**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add \
  src/services/websocket_service/message_processor/models.py \
  src/services/websocket_service/message_processor/processor.py \
  src/services/websocket_service/message_processor/event_handlers.py \
  src/services/websocket_service/manager/handlers.py \
  tests/core/test_event_handler_tts.py \
  tests/core/test_message_processor.py \
  tests/core/test_message_processor_stream_pipeline.py \
  tests/websocket/test_websocket_service.py
git commit -m "feat: replace _build_tts_event with async _synthesize_and_send (T4)"
```

---

## Implementation Sequencing

```
Chunk 1 (models.py TTS fields)
  → Chunk 2 (processor.py constructor + is_connection_closing)
    → Chunk 3 (event_handlers.py _synthesize_and_send)
      → Chunk 4 (replace _build_tts_event calls)
        → Chunk 5 (handlers.py extract fields + inject services)
          → Chunk 6 (delete legacy references, update tests)
            → Chunk 7 (lint + final validation)
```

## Key Implementation Notes

- `track_task(turn_id, task)` — two arguments, not one
- `is_connection_closing()` → `return self._shutdown_event.is_set()`
- Patch path: `"src.services.websocket_service.message_processor.event_handlers.synthesize_chunk"`
- T4 does NOT implement T5 barrier — `stream_end` may send before all TTS tasks complete until T5 is done
