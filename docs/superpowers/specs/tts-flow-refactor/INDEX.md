# TTS Flow Refactor — Task Index

**Date**: 2026-03-14

## 목표

Backend가 TTS 생성까지 내부에서 처리한 뒤 `tts_chunk`를 Unity에 전송.
Unity는 받아서 재생만 함 ("Dumb UI" 원칙).

## 태스크 목록

| Task | 파일 | 선행 조건 | 병렬 가능 | 주요 변경 (피드백 반영) |
| --- | --- | --- | --- | --- |
| [T1: DTO & WS 모델](./T1-dto-ws-models.md) | `src/models/websocket.py` | 없음 | T2와 병렬 가능 | `WarningMessage` · `MessageType.WARNING` 삭제 |
| [T2: 참조 API & Mapper](./T2-voices-api-mapper.md) | `routes/tts.py`, `tts_service/` | 없음 | T1과 병렬 가능 | `update()` 삭제(YAGNI), `list_voices()` `__init__` 캐싱, `map()` 가독성 개선 |
| [T3: TTS 파이프라인](./T3-tts-pipeline.md) | `tts_pipeline.py` (신규) | T1 완료 | — | 반환 타입 `TtsChunkMessage` 단일, 에러 → `logger.error()` |
| [T4: EventHandler 통합](./T4-eventhandler-integration.md) | `event_handlers.py`, `models.py` | T3 완료 | — | warning 로직 완전 삭제, `tts_sequence` → `ConversationTurn` 소유 |
| [T5: Barrier & stream_end](./T5-barrier-stream-end.md) | `processor.py` | T4 완료 | — | timeout warning 이벤트 삭제 → `logger.warning()` |

## 핵심 설계 원칙

- `tts_ready_chunk`, `POST /v1/tts/synthesize` — 레거시 즉시 삭제 (deprecated 없음)
- `audio_base64: Optional[str]` — 실패/비활성 시 `null`, FE가 null이면 오디오만 스킵
- **FE(Unity)에 Warning 이벤트 없음** — TTS 실패·timeout 등 모든 에러는 `logger.error/warning`으로 백엔드에만 기록
- `tts_sequence` — `ConversationTurn` 소유. Concurrent Turn Race Condition 방지
- `list_voices()` — 서버 기동 시 1회 스캔 캐싱. 런타임 동적 추가/삭제 요구사항 없음
- Barrier timeout — `asyncio.wait_for(..., timeout=10s)` deadlock 방지
- `generate_speech()` — 단위 테스트에서 반드시 mock (CI에서 TTS 엔진 불필요)

## 삭제 대상 (구현 전 확인)

- `src/models/websocket.py` — `TTSReadyChunkMessage` 클래스, `WarningMessage` 클래스, `MessageType.WARNING`
- `src/api/routes/tts.py` — `POST /v1/tts/synthesize` 핸들러
- `src/models/tts.py` — `TTSRequest`, `TTSResponse`
- `event_handlers.py` — `_build_tts_event()`
- `docs/api/TTS_Synthesize.md`
