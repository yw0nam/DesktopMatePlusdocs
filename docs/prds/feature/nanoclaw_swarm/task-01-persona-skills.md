# Task 01: Persona Skill 파일 작성

**Parent**: §3 The Artisan Team (NanoClaw Swarm)
**Priority**: P0
**Depends on**: NanoClaw Skill 패턴 이해 (기존 agent-browser.md 참조)

---

## Goal

단일 Claude 인스턴스가 순차적으로 수행할 Persona별 행동 지침을 Skill 파일로 캡슐화한다.

## Scope

### 디렉토리 구조

```
container/skills/
├── agent-browser/      (기존)
├── dev-agent/          (신규)
│   ├── manifest.yaml
│   ├── SKILL.md
│   ├── add/
│   ├── modify/
│   └── tests/
├── reviewer-agent/     (신규)
│   └── (동일 구조)
└── pm-agent/           (신규)
    └── (동일 구조)
```

각 Skill 디렉토리는 `nanoclaw/.claude/skills/add-discord`와 동일한 패턴을 따른다.

### 각 Skill 구성

- **SKILL.md**: Persona의 역할, 사용 도구, 책임 범위, 출력 형식 정의
- **manifest.yaml**: 의존성, 환경변수, 추가/수정 파일 선언
- **add/**: 신규 추가 파일
- **modify/**: 기존 파일 수정 intent
- **tests/**: Skill 동작 검증 테스트

### Persona 목록

| Persona | 역할 | 핵심 도구 |
|---|---|---|
| DevAgent | 코드 작성/수정 | file read/write, shell |
| ReviewerAgent | 코드 리뷰, 품질 검증 | file read, search |
| PMAgent | 작업 요약, 결과 정리 | 없음 (LLM 자체 능력) |

## Acceptance Criteria

- [ ] 각 Skill 디렉토리가 기존 `agent-browser/` 패턴을 따른다 (manifest.yaml, SKILL.md, add/, modify/, tests/)
- [ ] Claude가 Task 실행 시 Skill 파일을 참조해 Persona를 전환할 수 있다
- [ ] Persona 추가/수정이 다른 Skill 파일에 영향을 주지 않는다
