# T5: Barrier & stream_end 동기화

**선행 조건**: T4 완료 (`turn.tts_tasks` 리스트 사용)
**차단 대상**: 없음 (최종 태스크)

---

## 목표

`stream_end` 전송 전 모든 `tts_chunk`가 FE에 도착하도록 보장.
`asyncio.wait_for` + timeout으로 TTS 서버 hang 시 deadlock 방지.

---

## 문제 배경

```text
[현재 문제 — 없으면 발생하는 race condition]
토큰 스트리밍 완료 → stream_end 전송
                    ↗
TTS task (느린 합성) → tts_chunk 전송  ← stream_end 이후 도착 → FE가 drop
```

```text
[해결: barrier]
토큰 스트리밍 완료 → await all tts_tasks (with timeout) → stream_end 전송
                                    ↗
TTS task → tts_chunk 전송  ← 보장됨
```

---

## 변경 파일

### `src/services/websocket_service/message_processor/processor.py`

#### `stream_end` 전송 로직 변경

현재 `stream_end` 전송 위치를 찾아 barrier 삽입:

```python
# AS-IS (현재 코드 — stream_end 직전)
await self._put_event(turn_id, {"type": "stream_end", "session_id": session_id})

# TO-BE
await self._wait_for_tts_tasks(turn_id)
await self._put_event(turn_id, {"type": "stream_end", "session_id": session_id})
```

#### `_wait_for_tts_tasks()` — 신규

```python
from loguru import logger

async def _wait_for_tts_tasks(self, turn_id: str) -> None:
    """
    모든 pending TTS task가 완료될 때까지 대기 (with timeout).
    timeout 초과 시: 진행 중인 task cancel + 백엔드 로그 기록 + 진행 계속.
    """
    turn = self._turns.get(turn_id)
    if not turn or not turn.tts_tasks:
        return

    timeout = self._config.tts_barrier_timeout_seconds  # 기본 10.0초

    try:
        await asyncio.wait_for(
            asyncio.gather(*turn.tts_tasks, return_exceptions=True),
            timeout=timeout,
        )
    except asyncio.TimeoutError:
        # 초과된 task cancel
        for task in turn.tts_tasks:
            if not task.done():
                task.cancel()

        # 클라이언트에게 보내지 않고 백엔드에만 기록
        logger.warning(f"TTS barrier timeout after {timeout}s for turn {turn_id}, proceeding to stream_end")
```

---

### `yaml_files/main.yml` — 설정 추가

```yaml
websocket:
  # ... 기존 필드 ...
  tts_barrier_timeout_seconds: 10.0  # TTS task barrier 타임아웃 (초)
```

### `src/configs/` — WebSocket 설정 모델

기존 `WebSocketConfig` 또는 관련 Pydantic 설정 모델에 필드 추가:

```python
tts_barrier_timeout_seconds: float = 10.0
```

---

## 타임아웃 값 선택 근거

| 시나리오 | 예상 시간 |
| --- | --- |
| 정상 TTS 합성 (VLLM, 1-2 문장) | 1~3초 |
| 느린 TTS (긴 문장, 부하 시) | 5~8초 |
| TTS 서버 hang | 무한 |

10초는 정상 범위를 충분히 커버하면서 hang 감지에 합리적인 값.
운영 환경에 따라 `yaml_files/main.yml`에서 조정 가능.

---

## 이벤트 순서 보장

```text
stream_token(0) → stream_token(1) → ... → stream_token(N)
tts_chunk(seq=0) → tts_chunk(seq=1) → ... → tts_chunk(seq=M)  ← barrier로 전부 보장
stream_end
```

- `stream_token`과 `tts_chunk`는 독립적으로 전송되며 순서가 섞일 수 있음
- `stream_end`는 항상 마지막

---

## 테스트

### 단위 테스트

```python
@pytest.mark.asyncio
async def test_barrier_waits_for_all_tts_tasks():
    """stream_end 전에 모든 tts_task가 완료되어야 함."""
    # tts_tasks에 느린 task 2개 추가
    task1_done = asyncio.Event()
    task2_done = asyncio.Event()

    async def slow_task(event):
        await asyncio.sleep(0.1)
        event.set()

    turn.tts_tasks = [
        asyncio.create_task(slow_task(task1_done)),
        asyncio.create_task(slow_task(task2_done)),
    ]

    await processor._wait_for_tts_tasks(turn_id)

    assert task1_done.is_set()
    assert task2_done.is_set()

@pytest.mark.asyncio
async def test_barrier_timeout_logs_and_continues():
    """timeout 초과: logger.warning 호출 + deadlock 없이 정상 반환."""
    async def hanging_task():
        await asyncio.sleep(9999)  # hang 시뮬레이션

    turn.tts_tasks = [asyncio.create_task(hanging_task())]

    # timeout=0.1초로 설정
    processor._config.tts_barrier_timeout_seconds = 0.1

    with patch("src.services.websocket_service.message_processor.processor.logger") as mock_logger:
        await processor._wait_for_tts_tasks(turn_id)
        mock_logger.warning.assert_called_once()

    # warning 이벤트 미전송 확인
    events = get_queued_events(turn_id)
    assert all(e["type"] != "warning" for e in events)

@pytest.mark.asyncio
async def test_stream_end_arrives_after_last_tts_chunk():
    """통합: stream_end가 마지막 tts_chunk 이후에 도착."""
    # 실제 WS 연결 시뮬레이션
    received = []
    # ... WS 메시지 수집 후
    types = [m["type"] for m in received]
    last_tts = max(i for i, t in enumerate(types) if t == "tts_chunk")
    stream_end = types.index("stream_end")
    assert stream_end > last_tts
```

### 검증 기준

- `_wait_for_tts_tasks()` 없이는 race condition이 재현됨 (테스트로 증명)
- timeout 이후에도 WebSocket 연결이 정상 종료됨 (deadlock 없음)
- `tts_barrier_timeout_seconds`가 YAML에서 로드됨 확인

---

## 통합 테스트 (T1~T5 전체)

T5 완료 후 아래 통합 시나리오를 `tests/api/test_tts_flow_integration.py`에 작성:

| 시나리오 | 검증 항목 |
| --- | --- |
| `tts_enabled: true`, 정상 TTS | `tts_chunk` 수신, audio_base64 비null, sequence 순서, `stream_end` 마지막 |
| `tts_enabled: false` | `tts_chunk` 수신, audio_base64 null, motion/blendshape 정상 |
| TTS 실패 시뮬레이션 | `tts_chunk(null audio)` 수신, motion/blendshape 정상 |
| barrier timeout | `stream_end` 정상 도착, warning 이벤트 미수신 |
| `stream_token` + `tts_chunk` 공존 | 두 이벤트 모두 수신 |
| `GET /v1/tts/voices` | 200 + voices 목록 |
