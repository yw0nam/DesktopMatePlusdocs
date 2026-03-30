# Task 01: Dumb UI 역할 유지 및 검증

**Parent**: §5 The Dumb UI
**Priority**: P1
**Depends on**: FastAPI WebSocket Gateway (기존 구현)

---

## Goal

FE는 NanoClaw의 존재를 모른다. FastAPI가 주는 데이터를 렌더링하고 재생하는 역할만 수행한다.

## Scope (기존 구현 검증 + 신규)

### 기존 동작 유지

- 텍스트 렌더링 (WebSocket `stream_token` 이벤트)
- 오디오 청크 재생 (WebSocket `tts_ready_chunk` 이벤트)
- Emotion 기반 VRM 모델 제어
- 사용자 입력 수집 및 WebSocket 전송

### 신규: 위임 결과 표시

- PersonaAgent가 위임 결과를 보고할 때 (다음 턴에서 자연스럽게 텍스트/음성으로 전달) 별도 UI 처리 불필요
- 향후 Push 알림 UI가 추가될 때를 위한 알림 이벤트 핸들러 stub (선택)

## Acceptance Criteria

- [ ] FE가 FastAPI 외의 서비스와 직접 통신하지 않는다
- [ ] 기존 텍스트/오디오/이모션 렌더링이 정상 동작한다
- [ ] 위임 결과가 일반 대화와 동일하게 렌더링된다
