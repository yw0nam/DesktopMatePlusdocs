# TODO 02: Delegation 경계 정책

**Status**: 보류
**Priority**: P1
**Depends on**: fastapi_backend/task-01

---

## 문제

PersonaAgent가 어떤 요청을 직접 처리하고, 어떤 요청을 NanoClaw로 위임할지 경계가 정의되지 않았다.

## 방향

- PersonaAgent System Prompt에 위임 기준 규칙 삽입
- 별도 classifier는 TTFT 이중 비용 문제로 도입하지 않음
- 경계가 애매한 경우 유저에게 재질문 (Human-in-the-Loop)

## 후보 규칙 예시

- 코드 작성/수정/리뷰 → 위임
- 파일 분석, 브랜치 탐색 → 위임
- 일반 대화, 감정 교류, 간단한 질문 → 직접 처리
- 기억 관련 (기억해줘, 뭐 기억해?) → 직접 처리 (memory tool)

## 트리거 시점

E2E delegation flow 동작 후, 실사용 데이터 기반으로 규칙 정제.
