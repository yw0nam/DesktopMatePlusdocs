# TODO 03: Explicit Interrupt (Barge-in)

**Status**: 보류
**Priority**: P2
**Depends on**: data_flow/task-02 (TTS Flow)

---

## 문제

사용자가 대화 중 끼어들기(barge-in)를 할 때 전체 파이프라인을 즉시 중단하는 메커니즘이 필요하다.

## 방향

1. FastAPI: TTS 오디오 큐 클리어
2. FastAPI: PersonaAgent 대화 강제 중단
3. (필요 시) NanoClaw에 `CancelTaskTool` 명령 전송

## 참고

기존 `backend/docs/prds/features/task_fastapi/F5_interrupt.md`에 상세 설계가 있음. 새 아키텍처에 맞게 업데이트 필요.

## 트리거 시점

기본 대화 + TTS 흐름 안정화 후 구현.
