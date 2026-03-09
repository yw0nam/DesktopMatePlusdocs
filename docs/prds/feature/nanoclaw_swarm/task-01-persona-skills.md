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
├── agent-browser/      (기존, SKILL.md only)
├── dev-agent/          (신규)
│   └── SKILL.md
├── reviewer-agent/     (신규)
│   └── SKILL.md
└── pm-agent/           (신규)
    └── SKILL.md
```

> **Note**: Persona Skills는 런타임 에이전트 지침이므로 코드 변경이 없다.
> 따라서 `manifest.yaml`, `add/`, `modify/`, `tests/` 구조는 불필요하다.
> 기존 `agent-browser/SKILL.md` 패턴과 동일하게 SKILL.md만 사용한다.
> 코드를 추가/수정하는 Skill(e.g., HTTP Channel)만 full 패턴을 따른다.

### 각 Skill 구성

- **SKILL.md**: Persona의 역할, 사용 도구, 책임 범위, 출력 형식 정의 (YAML frontmatter 포함)

### Persona 목록

| Persona | 역할 | 핵심 도구 |
|---|---|---|
| DevAgent | 코드 작성/수정 | file read/write, shell |
| ReviewerAgent | 코드 리뷰, 품질 검증 | file read, search |
| PMAgent | 작업 요약, 결과 정리 | 없음 (LLM 자체 능력) |

## Acceptance Criteria

- [x] 각 Skill 디렉토리에 SKILL.md가 존재한다 (런타임 지침 패턴)
- [ ] Claude가 Task 실행 시 Skill 파일을 참조해 Persona를 전환할 수 있다
- [x] Persona 추가/수정이 다른 Skill 파일에 영향을 주지 않는다
