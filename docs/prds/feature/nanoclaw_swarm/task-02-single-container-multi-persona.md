# Task 02: Single-Container Multi-Persona 실행 로직

**Parent**: §3 The Artisan Team (NanoClaw Swarm)
**Priority**: P0
**Depends on**: Task 01 (Persona Skills)

---

## Goal

1 Group = 1 Container = 1 Claude 인스턴스에서 여러 Persona를 순차적으로 수행하는 실행 로직을 구현한다.

## Scope

- Container가 `groupQueue`에서 task를 받으면 해당 task에 맞는 Skill 파일들을 로드
- Claude가 task 내용을 분석하여 적절한 Persona 순서를 결정
  - 예: 코드 리뷰 → DevAgent(코드 읽기) → ReviewerAgent(리뷰) → PMAgent(요약)
- Persona 간 컨텍스트 공유: Container 내부의 대화 히스토리와 파일시스템 활용
- `sender` 필드로 현재 Persona를 IPC 메시지에 구분 표기
- 최종 PMAgent 출력이 Egress를 통해 callback으로 전송

## 컨텍스트 관리

- Persona 전환 시 전체 대화 히스토리를 유지 (요약하지 않음)
- 컨텍스트 한계 도달 시: PMAgent가 현재까지 결과를 요약하여 partial result로 callback 전송 (status: "done", summary에 partial 표기)

## Acceptance Criteria

- [ ] 단일 Container에서 여러 Persona가 순차적으로 실행된다
- [ ] IPC 메시지의 `sender` 필드로 현재 Persona를 구분할 수 있다
- [ ] Persona 간 파일시스템을 통한 산출물 공유가 동작한다
- [ ] 최종 결과가 Egress를 통해 callback으로 전송된다
