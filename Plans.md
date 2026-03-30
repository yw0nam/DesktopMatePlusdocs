# DesktopMatePlus — Lead Agent Coordination

> **Lead Agent Rule**: This agent delegates and coordinates ONLY. Never writes code directly.
> All implementation is delegated to repo teams via Subagent dispatch.

## Repo Teams

| Repo | Team | Stack | Constraint |
|------|------|-------|------------|
| `backend/` | Backend Team | Python / FastAPI / uv | — |
| `nanoclaw/` | NanoClaw Team | Node.js / TypeScript | skill-as-branch only (no direct source edit) |
| `desktop-homunculus/` | DH Team | Rust / Bevy + TypeScript MOD | separate git repo |

## Active Cross-Repo Tasks

<!-- cc:TODO format: [ ] **TASK-ID: description** — summary. DoD: criteria. Depends: id or none. spec-ref: docs/superpowers/specs/{file}.md. [ref: INDEX#{section}/{id}] (feature tasks only). [target: repo/] -->

### Phase 1: 아키텍처 강제 (Architecture Enforcement) — [archived](docs/superpowers/completed/plans/phase-1-architecture-enforcement.md)

### Phase 2: 관측 가능성 레이어 (Observability) — [archived](docs/superpowers/completed/plans/phase-2-observability.md)

### Phase 3: 엔트로피 제어 (Drift GC) — [archived](docs/superpowers/completed/plans/phase-3-drift-gc.md)

### Phase 4: 문서 신선도 (Doc Freshness) — [archived](docs/superpowers/completed/plans/phase-4-doc-freshness.md)

### Phase 5: 메트릭 관측 가능성 (Metrics Observability) — [archived](docs/superpowers/completed/plans/phase-5-metrics-observability.md)

### Phase 6: 품질 등급 추적 (Quality Scoring) — [archived](docs/superpowers/completed/plans/phase-6-quality-scoring.md)

### Phase 7: Docs Consolidation — [archived](docs/superpowers/completed/plans/phase-7-docs-consolidation.md)

### Phase 8: Plans.md 경량화 + 워크플로우 개선

<!-- cc:TODO -->
- [x] **PM-1: Plans.md 완료 Phase 아카이빙** — 완료된 Phase(1~7)를 `docs/superpowers/completed/plans/` 아래 개별 markdown 파일로 분리하고, Plans.md에는 Phase 제목 + 링크만 남긴다. DoD: Plans.md에 완료 태스크 본문 0개, 각 Phase별 아카이브 파일 존재, 링크 정상. [target: workspace/]
- [x] **PM-2: harness-release 워크플로우 통합** — teammate-workflow Post-feature routine 마지막 단계에 `harness-release` 스킬 호출 추가. DoD: teammate-workflow 스킬 파일에 harness-release 단계 명시, CLAUDE.md Planning Workflow 섹션에 반영. Depends: PM-1. [target: workspace scripts/harness/]

### Phase 9: Per-Team Agent Skills

<!-- cc:TODO -->
- [x] **AS-1: 디렉토리 구조 + README.md 생성** — `.claude/agent_skills/` 루트 README.md(컨벤션 + 스킬 작성 가이드) + 5개 팀 디렉토리(`backend-team/`, `nanoclaw-team/`, `dh-team/`, `quality-team/`, `pm-agent/`) 각각 README.md 인덱스 생성. 기존 `dh_team/` → `dh-team/`으로 rename, browser-use SKILL.md 이동. DoD: 5개 팀 README.md 존재, 루트 README.md에 컨벤션 + `superpowers:writing-skills` 참조 명시, `dh_team/` 삭제됨. spec-ref: docs/superpowers/specs/2026-03-30-agent-skills-design.md. [target: workspace/]
- [x] **AS-2: agents/*.md "Load After /clear" 업데이트** — 5개 에이전트 컨텍스트 파일(`backend-team.md`, `nanoclaw-team.md`, `dh-team.md`, `quality-team.md`, `pm-agent.md`)의 "Load After /clear" 2번 위치에 `.claude/agent_skills/{team}/README.md` 항목 추가. DoD: 5개 agents/*.md에 agent_skills 로드 항목 존재, 기존 항목 순번 조정 완료. Depends: AS-1. spec-ref: docs/superpowers/specs/2026-03-30-agent-skills-design.md. [target: workspace/]

## Completed

### Phase 2: 관측 가능성 레이어 (2026-03-28) — [details](docs/superpowers/completed/plans/phase-2-observability.md)

- [x] **OBS-1~4: Backend Agent Run Environment** — completed 2026-03-28

### Phase 1: 아키텍처 강제 (2026-03-28) — [details](docs/superpowers/completed/plans/phase-1-architecture-enforcement.md)

- [x] **NanoClaw 구조적 테스트 NC-S1~NC-S4** — completed 2026-03-28
