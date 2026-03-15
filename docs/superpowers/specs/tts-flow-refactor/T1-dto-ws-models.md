# T1: DTO & WebSocket 모델

**선행 조건**: 없음 (T2와 병렬 가능)
**차단 대상**: T3

---

## 목표

WebSocket 메시지 모델을 새 TTS 플로우에 맞게 업데이트하고 레거시 모델을 삭제한다.

---

## 변경 파일

### `src/models/websocket.py`

#### 1. `ChatMessage` — 필드 추가

```python
class ChatMessage(BaseMessage):
    # 기존 필드 유지
    content: str
    agent_id: str
    user_id: str
    session_id: Optional[UUID] = None
    persona: Optional[str] = None
    images: Optional[List[ImageContent]] = None
    limit: Optional[int] = 10
    metadata: Optional[Dict[str, Any]] = None
    # 신규 추가
    tts_enabled: bool = True          # 기본값 True — 기존 클라이언트 하위 호환
    reference_id: Optional[str] = None  # TTS voice reference. null이면 엔진 기본값
```

#### 2. `TtsChunkMessage` — 신규 추가

```python
class TtsChunkMessage(BaseMessage):
    """Backend → Unity. TTS 합성 결과 + motion 메타데이터."""
    type: MessageType = MessageType.TTS_CHUNK
    sequence: int                      # turn 내 순서 보장용 (0부터 증가)
    text: str                          # TTS에 사용된 텍스트
    audio_base64: Optional[str] = None # MP3 base64. null이면 오디오 재생 스킵
    emotion: Optional[str] = None
    motion_name: str
    blendshape_name: str
```

#### 3. `MessageType` enum — 업데이트

```python
class MessageType(str, Enum):
    # 추가
    TTS_CHUNK = "tts_chunk"
    # 삭제
    # TTS_READY_CHUNK = "tts_ready_chunk"  ← 삭제
```

#### 5. `TTSReadyChunkMessage` — **삭제**

`TTSReadyChunkMessage` 클래스 전체 삭제. 참조하는 곳 모두 제거.

---

## Unity (FE) 계약

`tts_chunk` 수신 시 FE 처리 로직 (참고용):

```text
on tts_chunk:
  enqueue(sequence, chunk)
  play_in_order():
    motion_name → AnimationPlayer 재생
    blendshape_name → blendshape 적용
    if audio_base64 != null:
      decode + play audio with lip sync
    else:
      skip audio (motion/blendshape는 정상 처리)
```

---

## 테스트

### 단위 테스트

- `ChatMessage`: `tts_enabled` 미전송 → `True`, `reference_id` 미전송 → `None`
- `TtsChunkMessage`: `audio_base64=null` 허용 확인, `sequence` 필수 확인

### 검증 기준

- 기존 `ChatMessage` 테스트 중 `tts_enabled`, `reference_id` 없이 전송하는 케이스 모두 통과 (하위 호환)
- `tts_ready_chunk` 관련 테스트 전부 삭제
