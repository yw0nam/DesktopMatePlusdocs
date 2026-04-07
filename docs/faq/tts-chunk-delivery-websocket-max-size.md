# TTS 청크 누락 — WebSocket max_size 제한

## 증상

- TTS 청크 중 일부(특히 긴 텍스트의 오디오)가 클라이언트에 도달하지 않음
- 클라이언트에서 `stream_end` 없이 `ConnectionClosed` 발생
- 서버 로그에는 모든 청크가 정상 전송됨 (`Sent tts_chunk event`)

## 오진하기 쉬운 포인트

| 의심 대상 | 실제 여부 |
|-----------|-----------|
| `TextChunkProcessor`의 `min_chunk_length` 게이트가 문장을 삼킴 | ❌ 서버 로그에서 seq=0, seq=1 모두 스케줄됨 |
| TTS 합성 시간 차이로 인한 순서 역전 + 연결 조기 종료 | ❌ 서버는 두 청크 모두 `send_text()` 성공 |
| `is_connection_closing()` 가드가 청크를 silent drop | ❌ 서버 로그에 드롭 흔적 없음 |
| **`websockets` 라이브러리의 `max_size` 기본값(1MB) 초과** | **✅ 실제 원인** |

## 원인

`websockets.connect()`의 기본 `max_size = 2**20 = 1,048,576 bytes (1MB)`.

TTS 청크 JSON 메시지 = 텍스트 + emotion + keyframes + **base64 오디오(WAV)**. IrodoriTTS가 `seconds: 30.0`까지 생성 가능하므로, 긴 텍스트(~80자+)의 오디오는 WAV ~700KB → base64 ~930KB → JSON 전체 **~1MB 전후**로, 기본 제한을 초과할 수 있다.

초과 시 `websockets` 라이브러리가 즉시 연결을 종료하고 `ConnectionClosed`를 raise한다. 서버의 `send_text()`는 OS 버퍼에 넘기는 것까지만 보장하므로, 서버 로그에는 "Sent" 성공으로 찍힌다.

## 수정

```python
# examples/realtime_tts_streaming_demo.py
async with websockets.connect(
    self.websocket_url,
    max_size=None,  # TTS 청크에 대용량 base64 오디오 포함
    ...
) as websocket:
```

## 디버깅 교훈

1. **서버 로그 먼저 확인**: 서버가 "Sent" 로그를 찍었다면 서버 코드 버그가 아닐 가능성이 높다.
2. **`send_text()` 성공 ≠ 클라이언트 수신 보장**: OS 버퍼까지만 보장하므로, 전송 직후 연결 종료 시 데이터 유실 가능.
3. **`websockets` max_size**: base64 오디오를 WebSocket으로 보내는 경우 반드시 `max_size` 설정을 확인할 것. 기본 1MB는 TTS 오디오에 부족하다.
