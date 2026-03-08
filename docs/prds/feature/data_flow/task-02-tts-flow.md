# Task 02: Real-time TTS Flow

**Parent**: §6 Interaction Flow
**Priority**: P1
**Depends on**: 기존 TTS Service, 기존 WebSocket Service

---

## Goal

PersonaAgent의 스트리밍 응답을 문장 단위로 감지하여 비동기 TTS를 트리거하고, Unity로 오디오 청크를 push하는 흐름을 검증/보완한다.

## Context

TTS Service와 WebSocket Service는 이미 구현되어 있다. 기존 `MessageProcessor`의 토큰 큐잉 → 문장 경계 감지 → TTS 트리거 흐름이 새 아키텍처에서도 정상 동작하는지 검증한다.

## Scope

- 기존 Sentence Boundary 감지 로직 (`text_processor.py`) 검증
- PersonaAgent 스트리밍 출력 → 문장 완성 → 비동기 TTS 합성 → WebSocket push 흐름 확인
- 위임 확인 응답("팀에 지시했습니다")도 TTS를 거쳐 Unity로 전달되는지 확인

## Acceptance Criteria

- [ ] 스트리밍 토큰이 문장 단위로 TTS 합성된다
- [ ] TTS 합성이 토큰 스트리밍을 블로킹하지 않는다
- [ ] 오디오 청크 + 텍스트 + Emotion 메타데이터가 WebSocket으로 push된다
