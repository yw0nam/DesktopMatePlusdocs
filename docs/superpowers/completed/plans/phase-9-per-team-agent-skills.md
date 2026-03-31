### Phase 9: Per-Team Agent Skills

<!-- cc:TODO -->
- [x] **AS-1: 디렉토리 구조 + README.md 생성** — `.claude/agent_skills/` 루트 README.md(컨벤션 + 스킬 작성 가이드) + 5개 팀 디렉토리(`backend-team/`, `nanoclaw-team/`, `dh-team/`, `quality-team/`, `pm-agent/`) 각각 README.md 인덱스 생성. 기존 `dh_team/` → `dh-team/`으로 rename, browser-use SKILL.md 이동. DoD: 5개 팀 README.md 존재, 루트 README.md에 컨벤션 + `superpowers:writing-skills` 참조 명시, `dh_team/` 삭제됨. spec-ref: docs/superpowers/specs/2026-03-30-agent-skills-design.md. [target: workspace/]
- [x] **AS-2: agents/*.md "Load After /clear" 업데이트** — 5개 에이전트 컨텍스트 파일(`backend-team.md`, `nanoclaw-team.md`, `dh-team.md`, `quality-team.md`, `pm-agent.md`)의 "Load After /clear" 2번 위치에 `.claude/agent_skills/{team}/README.md` 항목 추가. DoD: 5개 agents/*.md에 agent_skills 로드 항목 존재, 기존 항목 순번 조정 완료. Depends: AS-1. spec-ref: docs/superpowers/specs/2026-03-30-agent-skills-design.md. [target: workspace/]
