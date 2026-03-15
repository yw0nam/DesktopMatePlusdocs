# Architecture Overview

전체 아키텍처 건강도: 🔴 (Significant issues - 이전 단계의 설계 결정 누락 및 상태 관리(State Management) 결함 발견)

스트리밍되는 텍스트 청크마다 비동기 태스크(`asyncio.create_task`)를 생성하여 병렬로 TTS 엔진을 호출하는 아키텍처는 I/O 대기 시간을 최소화하는 훌륭한 접근입니다. 연결 종료(`is_closing`)를 체크하여 불필요한 연산을 버리는 방어적 로직도 좋습니다. 하지만, **과거의 잔재(Warning)**가 남아있고, 상태(Sequence)를 관리하는 위치가 구조적으로 잘못되었습니다.

## Step 1 Findings — Questionable Requirements

* **[CRITICAL] 또다시 등장한 `warning_msg`:** `_synthesize_and_send` 함수 내부를 보십시오. `chunk_msg, warning_msg = await synthesize_chunk(...)` 라니요? T3 스펙에서 `synthesize_chunk`는 오직 `TtsChunkMessage` 단일 객체만 반환하도록 수정했습니다. 이 함수가 아직도 경고 메시지를 받아 클라이언트에게 쏠 이유가 전혀 없습니다.

## Step 2 Findings — Candidates for Deletion

* **[CRITICAL] `Warning` 이벤트 put 로직 전체:** `if warning_msg:` 블록을 통째로 삭제하십시오.
* **[CRITICAL] `Warning` 관련 테스트 코드:** `test_synthesize_and_send_with_warning` 테스트를 삭제하거나, 에러 발생 시 단지 `audio_base64=None`인 청크만 전송되는지 확인하는 테스트로 교체하십시오.

## Step 3 Findings — Simplification Opportunities

* **[IMPORTANT] `sequence` 상태 관리의 캡슐화 위배:** 현재 `_tts_sequence`를 `EventHandler`의 인스턴스 변수로 선언하고, `MessageProcessor`가 `start_turn`에서 남의 변수를 초기화(`self._tts_sequence = 0`)하는 기괴한 패턴을 제안하셨습니다.
* **문제점:** 만약 한 소켓에서 여러 Turn이 비동기적으로 겹쳐서 실행되거나(`Concurrent Turn`), Handler가 재사용된다면 Sequence 번호가 꼬이는 Race Condition이 발생합니다. Sequence는 'Handler'의 상태가 아니라 **'Turn'의 상태**입니다.
* **해결책:** `_tts_sequence` 카운터를 `ConversationTurn` 데이터 클래스 내부로 옮기십시오.



```python
# src/services/websocket_service/message_processor/models.py
@dataclass
class ConversationTurn:
    # ... 기존 필드 ...
    tts_enabled: bool = True
    reference_id: str | None = None
    tts_tasks: list[asyncio.Task] = field(default_factory=list)
    tts_sequence: int = 0  # 이 Turn에서 발급할 다음 시퀀스 번호

```

```python
# src/services/websocket_service/message_processor/event_handlers.py (수정된 TO-BE)
task = asyncio.create_task(
    self._synthesize_and_send(
        turn_id=turn_id,
        text=filtered_text,
        emotion=emotion_tag,
        sequence=turn.tts_sequence,  # Turn 객체에서 가져옴
        tts_enabled=turn.tts_enabled,
        reference_id=turn.reference_id,
    )
)
turn.tts_sequence += 1  # Turn 객체의 상태 업데이트
turn.tts_tasks.append(task)
self.processor._task_manager.track_task(task)

```

## Step 4 Findings — Cycle Time Blockers

* 해당 사항 없습니다. 비동기 Task 기반 구조는 처리량을 높일 것입니다.

## Step 5 Findings — Automation Assessment

* 해당 사항 없습니다.

---

## Priority Actions

1. **Warning 로직의 완전한 소멸:** `_synthesize_and_send` 내부에서 튜플 언패킹을 제거하고 순수하게 `tts_chunk`만 큐에 넣도록 함수를 극단적으로 단순화하십시오.
2. **Sequence 카운터 이동:** `_tts_sequence`를 `EventHandler` 인스턴스에서 `ConversationTurn` 데이터 클래스로 이동하여 상태를 격리하십시오.
3. **`MessageProcessor.start_turn()` 책임 정리:** `MessageProcessor`가 남의 객체(`EventHandler`)의 속성을 건드리는 안티 패턴 코드를 삭제하십시오.