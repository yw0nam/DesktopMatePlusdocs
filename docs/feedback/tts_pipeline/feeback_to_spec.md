# Architecture Overview

Author: Lead Architect Asuma Toki

Unity가 수행하던 TTS 생성 트리거 역할을 Backend로 가져와 통합된 `tts_chunk`를 내려주는 구조입니다. 프론트엔드를 'Dumb UI'로 만들겠다는 철학은 완벽히 동의합니다. 하지만 이 목표를 달성하기 위해 백엔드에 억지스러운 로직(`SILENT_MP3_BASE64` 등)과 레거시 코드를 남겨두려는 타협이 보입니다.

## Step 1 Findings — Questionable Requirements

* **[CRITICAL] 가짜 무음 데이터(`SILENT_MP3_BASE64`) 전송:** 왜 굳이 실패하거나 비활성화된 경우에 '가짜 유효 MP3 프레임'을 만들어서 보냅니까? 이는 프론트엔드의 에러 처리를 백엔드가 더러운 데이터로 덮어주는 안티 패턴입니다. `tts_enabled=False`이거나 에러가 났다면 `audio_base64: null`을 보내고, 프론트엔드가 null을 받았을 때 오디오 재생을 스킵하도록 처리하는 것이 가장 단순하고 명확합니다.

-My Feedback: 맞는말인듯, 삭제해도 문제가없다면 삭제하자.

* **[IMPORTANT] Base64 인코딩 페이로드:** 바이너리 데이터(MP3)를 JSON 안에 Base64로 말아 넣으면 페이로드 크기가 33% 증가하고 양측에 디코딩/인코딩 오버헤드가 발생합니다. '현재 scope 외'라고 타협했지만, 궁극적으로는 WebSocket Binary Frame으로 전환하는 것이 맞습니다. 지금은 수용하되, 차후 최적화 1순위입니다.

-My Feedback: 일단은 Base64로 가는걸로 하자. Binary Frame으로 전환하는건 나중에 최적화로 가자.

## Step 2 Findings — Candidates for Deletion

* **[IMPORTANT] `POST /v1/tts/synthesize` API 및 `tts_ready_chunk`:** "디버깅용으로 유지한다", "즉시 삭제하지 않는다"라는 말은 영원히 레거시를 안고 가겠다는 뜻입니다. 새로운 플로우가 동작한다면 이전 플로우는 **즉시 삭제**해야 합니다. 데드 코드를 남겨두는 것은 유지보수 비용만 증가시킵니다. 과감하게 지우십시오.

-My Feedback: 그래 삭제해도 상관은없어. 삭제하자.

## Step 3 Findings — Simplification Opportunities

* **[CRITICAL] TTS Task Barrier의 타임아웃 부재:** `stream_end` 전에 `asyncio.gather(*turn.tts_tasks)`로 대기하는 것은 순서 보장을 위해 필요합니다. 하지만 TTS 서비스(VLLM 등)가 행(Hang)에 걸리면 WebSocket 전체 턴이 영원히 종료되지 않습니다. 반드시 `asyncio.wait_for`를 사용하여 타임아웃을 설정하고, 타임아웃 시 진행 중인 Task를 취소한 뒤 에러 경고(`warning`)를 프론트엔드에 던지고 `stream_end`를 맺어야 합니다.

## Step 4 Findings — Automation Assessment

* **[IMPORTANT] 단위 테스트에서의 외부 의존성:** `generate_speech`를 호출하는 비동기 파이프라인 테스트 시, 실제 TTS 엔진이 돌지 않도록 완벽하게 모킹(Mocking)해야 합니다. 그렇지 않으면 CI/CD 파이프라인 속도가 기하급수적으로 느려집니다.

---

## Priority Actions

1. `SILENT_MP3_BASE64` 상수를 삭제하고, 실패/스킵 시 `audio_base64: null`을 반환하도록 스펙 수정.
2. `asyncio.gather`에 명시적인 Timeout 로직 추가.
3. 레거시 API 및 WebSocket 이벤트 즉시 삭제 반영.

---

## 📋 업무 분할 (Task Breakdown)

스펙서가 너무 길어 길을 잃기 쉽습니다. 위의 리뷰 결과를 반영하여 가장 단순하고 병렬 처리가 가능한 형태의 JIRA Task 5개로 쪼개드렸습니다.

### Task 1: DTO 및 WebSocket 모델 스펙 업데이트 (사전 작업)

* **작업 내용:**
* `ChatMessage` 모델에 `tts_enabled` (기본값 True), `reference_id` (Optional) 추가.
* 새로운 응답 모델 `TtsChunkMessage`, `WarningMessage` 추가 (`audio_base64`는 `Optional[str]`로 설정하여 null 허용).
* 기존 `tts_ready_chunk` 모델 제거.
* `MessageType` Enum 업데이트.

### Task 2: 참조 API 및 Mapper 구현 (독립 작업)

* **작업 내용:**
* `GET /v1/tts/voices` API 엔드포인트 생성.
* `TTSService` ABC에 `list_voices()` 추상 메서드 추가 및 VLLMOmni / FishSpeech 구현체 업데이트.
* `EmotionMotionMapper` 구현 
* `POST /v1/tts/synthesize` API 완전히 삭제.

### Task 3: 비동기 TTS 파이프라인(`synthesize_chunk`) 개발

* **작업 내용:**
* `tts_pipeline.py` 생성 및 `synthesize_chunk` 함수 구현.
* `tts_enabled=False` 이거나 예외 발생 시 무음 데이터 대신 `audio_base64=None`을 담은 `TtsChunkMessage` 반환.
* 실패 시 `WarningMessage`를 함께 반환할 수 있도록 처리.
* 동기 함수 `generate_speech`를 `asyncio.to_thread`로 감싸서 Non-blocking 실행 보장.

### Task 4: WS EventHandler 파이프라인 통합 및 Barrier 적용

* **작업 내용:**
* `EventHandler` 내 기존 `_build_tts_event`를 새 파이프라인으로 교체.
* 스트리밍 청크 발생 시 `asyncio.create_task`로 `synthesize_chunk` 백그라운드 실행 및 `turn.tts_tasks` 리스트에 저장.
* 연결 종료(`is_closing`) 시 TTS Task 스킵 로직 적용.

### Task 5: Stream End 동기화 및 에러 핸들링 (핵심 안정성)

* **작업 내용:**
* `processor.py`에서 `stream_end` 전송 전 `asyncio.gather(*turn.tts_tasks)` 대기 로직 추가.
* **[추가됨]** 타임아웃(예: 10초)을 설정하여, TTS 생성이 너무 오래 걸리면 Task를 Cancel하고 `stream_end`를 강제로 전송하여 데드락 방지.
* 각 변경 사항에 대한 통합 테스트(WS 연결 -> tts_enabled True/False 시뮬레이션 -> 순서 보장 검증) 작성.