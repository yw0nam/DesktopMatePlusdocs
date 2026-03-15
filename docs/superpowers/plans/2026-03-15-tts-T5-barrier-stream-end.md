# T5: Barrier & stream_end 동기화 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee all `tts_chunk` messages arrive before `stream_end` using `asyncio.wait_for` barrier with 10s timeout.

**Architecture:** `_wait_for_tts_tasks()` awaits all `ConversationTurn.tts_tasks` (populated by T4) before `stream_end` is put onto the event queue. On timeout, pending tasks are cancelled and a `logger.warning` is written backend-only. The timeout value is configurable via YAML.

**Prerequisites:** T4 완료 (`turn.tts_tasks` 존재, `_wait_for_tts_tasks()`가 barrier 역할)

**Tech Stack:** Python 3.13, asyncio, pytest-asyncio, uv

---

## Codebase Context

### stream_end 발송 위치

`stream_end` 이벤트는 `event_handlers.py`의 `produce_agent_events()` 내부에서 발송된다:

```python
# event_handlers.py
if event_type == "stream_end":
    await self._signal_token_stream_closed(turn_id)
    await self._wait_for_token_queue(turn_id)
    logger.info(...)
    await self.processor._put_event(turn_id, event)   # ← barrier 삽입 대상
    await self.processor.complete_turn(turn_id)
```

`_wait_for_tts_tasks()`는 `processor.py`에 구현되고, `event_handlers.py`에서 `self.processor._wait_for_tts_tasks(turn_id)` 형태로 호출.

### 중요: `_turns` vs `turns`

스펙 코드 예시의 `self._turns.get(turn_id)`는 오타. 실제 `processor.py`의 attribute는 `self.turns`. 구현 시 `self.turns.get(turn_id)` 사용.

### 중요: `_config` 속성 없음

현재 `MessageProcessor`에 `_config` 속성이 없다. 기존 패턴(`get_settings().websocket`)을 따라 함수 본문에서 lazy import하여 `get_settings().websocket.tts_barrier_timeout_seconds`로 접근.

---

## Chunk 1: WebSocketConfig + YAML 설정 추가

**Files:**
- Modify: `backend/src/configs/settings.py`
- Modify: `backend/yaml_files/main.yml`
- Modify: `backend/tests/conftest.py` (test fixture 업데이트)

- [ ] **Step 1: `WebSocketConfig`에 필드 추가**

`src/configs/settings.py`의 `WebSocketConfig` 클래스에서 `disconnect_timeout_seconds` 필드 아래에:

```python
tts_barrier_timeout_seconds: float = Field(
    default=10.0,
    ge=0,
    description="Timeout in seconds for TTS barrier before stream_end",
)
```

- [ ] **Step 2: `yaml_files/main.yml`의 `websocket:` 섹션에 추가**

`disconnect_timeout_seconds: 5.0` 아래에:

```yaml
tts_barrier_timeout_seconds: 10.0
```

- [ ] **Step 3: `tests/conftest.py`의 `test_settings_yaml` fixture 업데이트**

`websocket:` dict에 `"tts_barrier_timeout_seconds": 10.0` 추가 (기존 패턴 따라)

- [ ] **Step 4: YAML 파싱 확인**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run python -c "
import yaml, pathlib
data = yaml.safe_load(pathlib.Path('yaml_files/main.yml').read_text())
ws = data.get('settings', {}).get('websocket', {})
assert 'tts_barrier_timeout_seconds' in ws
print('OK:', ws['tts_barrier_timeout_seconds'])
"
```

---

## Chunk 2: 설정 단위 테스트 (RED → GREEN)

**Files:**
- Modify: `backend/tests/config/test_settings.py`

- [ ] **Step 1: 테스트 추가**

```python
def test_websocket_config_tts_barrier_timeout_default():
    """tts_barrier_timeout_seconds defaults to 10.0."""
    config = WebSocketConfig()
    assert config.tts_barrier_timeout_seconds == 10.0


def test_websocket_config_tts_barrier_timeout_from_yaml():
    """tts_barrier_timeout_seconds is loaded from YAML."""
    import tempfile, yaml
    from pathlib import Path
    config = {
        "settings": {
            "websocket": {"tts_barrier_timeout_seconds": 5.0}
        }
    }
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yml", delete=False) as f:
        yaml.dump(config, f)
        tmp = Path(f.name)
    try:
        settings = load_settings_from_yaml(tmp)
        assert settings.websocket.tts_barrier_timeout_seconds == 5.0
    finally:
        tmp.unlink()
```

- [ ] **Step 2: Run to confirm RED**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/config/test_settings.py -v
```

- [ ] **Step 3: Chunk 1 적용 후 GREEN 확인**

```bash
uv run pytest tests/config/test_settings.py -v
```

---

## Chunk 3: `_wait_for_tts_tasks()` 단위 테스트 (RED → GREEN)

**Files:**
- Create: `backend/tests/core/test_tts_barrier.py`

- [ ] **Step 1: 테스트 파일 작성**

`backend/tests/core/test_tts_barrier.py`:

```python
"""Unit tests for _wait_for_tts_tasks() TTS barrier logic."""

from __future__ import annotations

import asyncio
from unittest.mock import patch
from uuid import uuid4

import pytest

from src.services.websocket_service.message_processor import MessageProcessor


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


@pytest.mark.asyncio
async def test_wait_for_tts_tasks_no_turn(processor: MessageProcessor):
    """Unknown turn_id: returns immediately without error."""
    await processor._wait_for_tts_tasks("nonexistent-turn-id")  # must not raise


@pytest.mark.asyncio
async def test_wait_for_tts_tasks_empty_list(processor: MessageProcessor):
    """turn.tts_tasks is empty: returns immediately."""
    turn_id = await processor.start_turn("sess-1", "hi")
    turn = processor.turns.get(turn_id)
    assert turn is not None
    turn.tts_tasks = []
    await processor._wait_for_tts_tasks(turn_id)  # must not raise


@pytest.mark.asyncio
async def test_barrier_waits_for_all_tts_tasks(processor: MessageProcessor):
    """All tts_tasks complete before _wait_for_tts_tasks returns."""
    turn_id = await processor.start_turn("sess-2", "hi")
    turn = processor.turns.get(turn_id)
    assert turn is not None

    task1_done = asyncio.Event()
    task2_done = asyncio.Event()

    async def slow_task(event: asyncio.Event) -> None:
        await asyncio.sleep(0.05)
        event.set()

    turn.tts_tasks = [
        asyncio.create_task(slow_task(task1_done)),
        asyncio.create_task(slow_task(task2_done)),
    ]

    await processor._wait_for_tts_tasks(turn_id)

    assert task1_done.is_set()
    assert task2_done.is_set()


@pytest.mark.asyncio
async def test_barrier_timeout_logs_and_continues(processor: MessageProcessor):
    """Timeout: logger.warning called, no deadlock, no warning event queued."""
    turn_id = await processor.start_turn("sess-3", "hi")
    turn = processor.turns.get(turn_id)
    assert turn is not None

    async def hanging_task() -> None:
        await asyncio.sleep(9999)

    hanging = asyncio.create_task(hanging_task())
    turn.tts_tasks = [hanging]

    # Override timeout to a tiny value
    from src.configs.settings import get_settings
    original_timeout = get_settings().websocket.tts_barrier_timeout_seconds
    get_settings().websocket.__dict__["tts_barrier_timeout_seconds"] = 0.05

    try:
        with patch(
            "src.services.websocket_service.message_processor.processor.logger"
        ) as mock_logger:
            await processor._wait_for_tts_tasks(turn_id)
            mock_logger.warning.assert_called_once()
    finally:
        get_settings().websocket.__dict__["tts_barrier_timeout_seconds"] = original_timeout
        hanging.cancel()
        try:
            await hanging
        except (asyncio.CancelledError, Exception):
            pass
```

- [ ] **Step 2: Run to confirm RED**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/core/test_tts_barrier.py -v
```

Expected: `AttributeError: 'MessageProcessor' object has no attribute '_wait_for_tts_tasks'`

---

## Chunk 4: `_wait_for_tts_tasks()` 구현 (GREEN)

**Files:**
- Modify: `backend/src/services/websocket_service/message_processor/processor.py`

- [ ] **Step 1: `_wait_for_tts_tasks()` 메서드 추가**

`processor.py`의 `_put_event()` 메서드 아래에 추가:

```python
async def _wait_for_tts_tasks(self, turn_id: str) -> None:
    """Await all pending TTS tasks before stream_end, with timeout.

    On timeout, cancels remaining tasks and logs a backend-only warning.
    Never sends warning events to the client.

    Args:
        turn_id: The conversation turn identifier.
    """
    turn = self.turns.get(turn_id)
    if not turn or not turn.tts_tasks:
        return

    from src.configs.settings import get_settings

    timeout = get_settings().websocket.tts_barrier_timeout_seconds

    try:
        await asyncio.wait_for(
            asyncio.gather(*turn.tts_tasks, return_exceptions=True),
            timeout=timeout,
        )
    except asyncio.TimeoutError:
        for task in turn.tts_tasks:
            if not task.done():
                task.cancel()
        logger.warning(
            f"TTS barrier timeout after {timeout}s for turn {turn_id}, "
            "proceeding to stream_end"
        )
```

- [ ] **Step 2: Run to confirm GREEN**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/core/test_tts_barrier.py -v
```

---

## Chunk 5: stream_end 발송 전 barrier 삽입

**Files:**
- Modify: `backend/src/services/websocket_service/message_processor/event_handlers.py`

- [ ] **Step 1: `stream_end` 분기에 barrier 삽입**

`produce_agent_events()`의 `stream_end` 분기에서 `_wait_for_token_queue()` 직후, `_put_event()` 직전에 삽입:

**AS-IS:**
```python
if event_type == "stream_end":
    await self._signal_token_stream_closed(turn_id)
    await self._wait_for_token_queue(turn_id)
    logger.info(
        f"Emitting stream_end for turn {turn_id} (all TTS chunks processed)"
    )
    await self.processor._put_event(turn_id, event)
    await self.processor.complete_turn(turn_id)
    continue
```

**TO-BE:**
```python
if event_type == "stream_end":
    await self._signal_token_stream_closed(turn_id)
    await self._wait_for_token_queue(turn_id)
    await self.processor._wait_for_tts_tasks(turn_id)
    logger.info(
        f"Emitting stream_end for turn {turn_id} (all TTS chunks processed)"
    )
    await self.processor._put_event(turn_id, event)
    await self.processor.complete_turn(turn_id)
    continue
```

- [ ] **Step 2: 통합 순서 테스트 추가** (`tests/core/test_tts_barrier.py`에 추가)

```python
@pytest.mark.asyncio
async def test_stream_end_arrives_after_last_tts_chunk(processor: MessageProcessor):
    """stream_end is always after the last tts_chunk in collected events."""
    async def fake_tts_task(p: MessageProcessor, tid: str, seq: int) -> None:
        await asyncio.sleep(0.02)
        await p._put_event(tid, {
            "type": "tts_chunk", "sequence": seq,
            "audio_base64": "abc", "text": f"s{seq}",
            "motion_name": "idle", "blendshape_name": "neutral"
        })

    async def agent_stream():
        yield {"type": "stream_start"}
        yield {"type": "stream_token", "chunk": "Hello world! "}
        yield {"type": "stream_end"}

    turn_id = await processor.start_turn(
        "sess-order", "hi", agent_stream=agent_stream(),
    )
    turn = processor.turns.get(turn_id)
    assert turn is not None
    turn.tts_tasks = [
        asyncio.create_task(fake_tts_task(processor, turn_id, 0)),
        asyncio.create_task(fake_tts_task(processor, turn_id, 1)),
    ]

    events = [e async for e in processor.stream_events(turn_id)]
    types = [e["type"] for e in events]

    assert "stream_end" in types
    tts_chunk_indices = [i for i, t in enumerate(types) if t == "tts_chunk"]
    stream_end_index = types.index("stream_end")

    if tts_chunk_indices:
        assert stream_end_index > max(tts_chunk_indices), (
            f"stream_end at {stream_end_index} must be after "
            f"last tts_chunk at {max(tts_chunk_indices)}"
        )
```

- [ ] **Step 3: Run all barrier tests**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/core/test_tts_barrier.py -v
```

---

## Chunk 6: 통합 테스트 — T1~T5 전체 시나리오

**Files:**
- Create: `backend/tests/api/test_tts_flow_integration.py`

모든 TTS 플로우 시나리오를 mock 기반으로 검증. CI에서 실제 TTS 엔진 없이 실행 가능.

`backend/tests/api/test_tts_flow_integration.py`:

```python
"""Integration tests for TTS flow refactor (T1~T5).

All scenarios run with mocked TTS engine — no real TTS server required.
"""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from src.services.websocket_service.message_processor import MessageProcessor


@pytest.fixture
async def processor():
    from unittest.mock import MagicMock
    mp = MessageProcessor(
        connection_id=uuid4(), user_id="integration_user",
        tts_service=MagicMock(), mapper=MagicMock()
    )
    try:
        yield mp
    finally:
        await mp.shutdown(cleanup_delay=0)


async def _fake_synthesize_and_send(
    processor: MessageProcessor,
    turn_id: str,
    sequence: int,
    audio_base64: str | None = "fakeaudio==",
    delay: float = 0.01,
) -> None:
    await asyncio.sleep(delay)
    await processor._put_event(turn_id, {
        "type": "tts_chunk", "sequence": sequence,
        "text": f"sentence {sequence}", "audio_base64": audio_base64,
        "motion_name": "idle", "blendshape_name": "neutral",
    })


# ─── Scenario 1: tts_enabled=true, normal TTS ────────────────────────────────

@pytest.mark.asyncio
async def test_tts_enabled_normal_flow(processor: MessageProcessor):
    """tts_chunk received, audio_base64 non-null, sequence order, stream_end last."""
    async def agent_stream() -> AsyncIterator[dict[str, Any]]:
        yield {"type": "stream_start"}
        yield {"type": "stream_token", "chunk": "Hello world!"}
        yield {"type": "stream_end"}

    turn_id = await processor.start_turn("sess-normal", "hi", agent_stream=agent_stream())
    turn = processor.turns.get(turn_id)
    assert turn is not None
    turn.tts_tasks = [
        asyncio.create_task(
            _fake_synthesize_and_send(processor, turn_id, 0, "audiobase64==")
        )
    ]

    events = [e async for e in processor.stream_events(turn_id)]
    types = [e["type"] for e in events]
    tts_chunks = [e for e in events if e["type"] == "tts_chunk"]

    assert len(tts_chunks) >= 1
    assert all(c["audio_base64"] is not None for c in tts_chunks)
    sequences = [c["sequence"] for c in tts_chunks]
    assert sequences == sorted(sequences)
    assert types[-1] == "stream_end"


# ─── Scenario 2: tts_enabled=false ───────────────────────────────────────────

@pytest.mark.asyncio
async def test_tts_disabled_sends_null_audio(processor: MessageProcessor):
    """tts_chunk received with audio_base64=null, motion/blendshape present."""
    async def agent_stream() -> AsyncIterator[dict[str, Any]]:
        yield {"type": "stream_start"}
        yield {"type": "stream_token", "chunk": "Hello!"}
        yield {"type": "stream_end"}

    turn_id = await processor.start_turn("sess-disabled", "hi", agent_stream=agent_stream())
    turn = processor.turns.get(turn_id)
    assert turn is not None
    turn.tts_tasks = [
        asyncio.create_task(
            _fake_synthesize_and_send(processor, turn_id, 0, audio_base64=None)
        )
    ]

    events = [e async for e in processor.stream_events(turn_id)]
    tts_chunks = [e for e in events if e["type"] == "tts_chunk"]
    types = [e["type"] for e in events]

    assert len(tts_chunks) >= 1
    assert all(c["audio_base64"] is None for c in tts_chunks)
    assert all(c.get("motion_name") is not None for c in tts_chunks)
    assert all(c.get("blendshape_name") is not None for c in tts_chunks)
    assert types[-1] == "stream_end"


# ─── Scenario 3: TTS failure simulation ──────────────────────────────────────

@pytest.mark.asyncio
async def test_tts_failure_sends_null_audio_no_warning(processor: MessageProcessor):
    """TTS failure: tts_chunk(null audio), no warning event to client."""
    async def agent_stream() -> AsyncIterator[dict[str, Any]]:
        yield {"type": "stream_start"}
        yield {"type": "stream_end"}

    turn_id = await processor.start_turn("sess-fail", "hi", agent_stream=agent_stream())
    turn = processor.turns.get(turn_id)
    assert turn is not None
    turn.tts_tasks = [
        asyncio.create_task(
            _fake_synthesize_and_send(processor, turn_id, 0, audio_base64=None)
        )
    ]

    events = [e async for e in processor.stream_events(turn_id)]
    types = [e["type"] for e in events]

    assert "warning" not in types
    tts_chunks = [e for e in events if e["type"] == "tts_chunk"]
    assert all(c["audio_base64"] is None for c in tts_chunks)
    assert types[-1] == "stream_end"


# ─── Scenario 4: barrier timeout ─────────────────────────────────────────────

@pytest.mark.asyncio
async def test_barrier_timeout_no_deadlock_no_warning_event(processor: MessageProcessor):
    """barrier timeout: stream_end arrives normally, no warning event to client."""
    async def agent_stream() -> AsyncIterator[dict[str, Any]]:
        yield {"type": "stream_start"}
        yield {"type": "stream_end"}

    turn_id = await processor.start_turn("sess-timeout", "hi", agent_stream=agent_stream())
    turn = processor.turns.get(turn_id)
    assert turn is not None

    async def hanging_task() -> None:
        await asyncio.sleep(9999)

    hanging = asyncio.create_task(hanging_task())
    turn.tts_tasks = [hanging]

    from src.configs.settings import get_settings
    original = get_settings().websocket.tts_barrier_timeout_seconds
    get_settings().websocket.__dict__["tts_barrier_timeout_seconds"] = 0.05

    try:
        with patch(
            "src.services.websocket_service.message_processor.processor.logger"
        ) as mock_logger:
            events = [e async for e in processor.stream_events(turn_id)]
            mock_logger.warning.assert_called()
    finally:
        get_settings().websocket.__dict__["tts_barrier_timeout_seconds"] = original
        hanging.cancel()
        try:
            await hanging
        except (asyncio.CancelledError, Exception):
            pass

    types = [e["type"] for e in events]
    assert "stream_end" in types
    assert "warning" not in types


# ─── Scenario 5: stream_token + tts_chunk coexist ────────────────────────────

@pytest.mark.asyncio
async def test_stream_token_and_tts_chunk_coexist(processor: MessageProcessor):
    """Both stream_token and tts_chunk event types are received."""
    async def agent_stream() -> AsyncIterator[dict[str, Any]]:
        yield {"type": "stream_start"}
        yield {"type": "stream_token", "chunk": "Hello! "}
        yield {"type": "stream_token", "chunk": "World."}
        yield {"type": "stream_end"}

    turn_id = await processor.start_turn("sess-coexist", "hi", agent_stream=agent_stream())
    turn = processor.turns.get(turn_id)
    assert turn is not None
    turn.tts_tasks = [
        asyncio.create_task(_fake_synthesize_and_send(processor, turn_id, 0))
    ]

    events = [e async for e in processor.stream_events(turn_id)]
    types = [e["type"] for e in events]

    assert "tts_chunk" in types
    assert "stream_end" in types
    assert types[-1] == "stream_end"


# ─── Scenario 6: GET /v1/tts/voices ──────────────────────────────────────────

class TestTTSVoicesEndpoint:
    """Tests for GET /v1/tts/voices endpoint."""

    def test_get_tts_voices_returns_200_and_voices_list(self, client):
        """GET /v1/tts/voices: 200 + voices list."""
        with patch("src.api.routes.tts.get_tts_service") as mock_get_svc:
            mock_svc = MagicMock()
            mock_svc.list_voices.return_value = ["aria", "alice"]
            mock_get_svc.return_value = mock_svc

            response = client.get("/v1/tts/voices")

        assert response.status_code == 200
        data = response.json()
        assert "voices" in data
        assert len(data["voices"]) >= 1

    def test_get_tts_voices_service_unavailable(self, client):
        """GET /v1/tts/voices: 503 when service not initialized."""
        with patch("src.api.routes.tts.get_tts_service") as mock_get_svc:
            mock_get_svc.return_value = None
            response = client.get("/v1/tts/voices")

        assert response.status_code == 503
```

- [ ] **Step 1: Run integration tests**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest tests/api/test_tts_flow_integration.py -v
```

---

## Chunk 7: 전체 테스트 스위트 + lint + 커밋

- [ ] **Step 1: 전체 테스트 실행**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uv run pytest -v
```

- [ ] **Step 2: 기존 pipeline 테스트 회귀 없음 확인**

```bash
uv run pytest tests/core/test_message_processor_stream_pipeline.py -v
```

- [ ] **Step 3: lint 확인**

```bash
sh scripts/lint.sh
```

- [ ] **Step 4: 커밋**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
git add \
  src/configs/settings.py \
  yaml_files/main.yml \
  src/services/websocket_service/message_processor/processor.py \
  src/services/websocket_service/message_processor/event_handlers.py \
  tests/core/test_tts_barrier.py \
  tests/config/test_settings.py \
  tests/api/test_tts_flow_integration.py
git commit -m "feat: add TTS barrier before stream_end with asyncio.wait_for (T5)"
```

---

## 구현 주의사항

1. **`_turns` vs `turns`**: 스펙 예시의 `self._turns`는 오타. 실제 코드에서는 `self.turns.get(turn_id)` 사용.

2. **`_config` 주입 없음**: `get_settings().websocket.tts_barrier_timeout_seconds`로 lazy import 후 직접 참조.

3. **barrier 삽입 순서**: `_wait_for_token_queue()` 직후, `_put_event()` 직전. "토큰 소비 완료 → TTS task 완료 → stream_end 발송" 순서 보장.

4. **timeout 시 cancel 명시**: `asyncio.wait_for()`가 TimeoutError를 던질 때 내부 gather 코루틴은 자동 cancel되지 않음. 각 `task.cancel()` 명시 필요.

5. **통합 테스트의 tts_tasks 주입**: T4 완성 전 테스트 시 `turn.tts_tasks`에 직접 fake task 주입으로 barrier 동작 검증.

6. **WARNING 이벤트 없음**: timeout 시 `logger.warning()`만 사용 — 클라이언트에 warning 이벤트 전송 절대 금지.
