# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Note: Use only english or korean for code and interaction, documentation. Avoid mixing languages in the same file or code block.

## Architecture

**Director-Artisan pattern** — 3 deployment components:

- **FastAPI** (`backend/`): Director — real-time WebSocket chat, STM/LTM, TTS, delegates heavy tasks to NanoClaw
- **NanoClaw** (`nanoclaw/`): Artisan — Node.js Claude agent runner; executes delegated tasks via container-based persona agents
- **desktop-homunculus** (`desktop-homunculus/`): Frontend (Dumb UI) — Bevy desktop mascot engine + MOD system. Renders output only, unaware of NanoClaw. MOD code lives here (e.g. `mods/desktopmate-bridge`). Has its own git.
- **DesktopMatePlus**: Documentation and workspace-level instructions only; no code.

**Cross-repo rule**: NanoClaw, Backend, desktop-homunculus each have their own git repo — do NOT commit code to DesktopMatePlus root.

**Delegation flow**: `DelegateTaskTool` → `POST /api/webhooks/fastapi` (NanoClaw) → async execution → `POST /v1/callback/nanoclaw/{session_id}` (FastAPI) → result injected into LangGraph state

See sub-repo CLAUDE.md files for per-repo conventions: [`backend/CLAUDE.md`](backend/CLAUDE.md), [`nanoclaw/CLAUDE.md`](nanoclaw/CLAUDE.md), [`desktop-homunculus/CLAUDE.md`](desktop-homunculus/CLAUDE.md).

## PRD Tracking

Flow: PM(`/office-hours`) → `docs/TODO.md` (spec + priority table) → Lead → `Plans.md` (cc:TODO / cc:DONE) → Worker

### docs/ 규칙 요약

- **본문 200줄 한도** — 초과 시 기능 단위로 분리, 인덱스 문서로 관리 ([전체 규칙](./docs/guidelines/DOCUMENT_GUIDE.md))
- **`docs/TODO.md`**: PM agent가 작성하는 활성 스펙 목록. Priority (P0/P1/P2) + Status (TODO/DONE) 테이블 형식
- **`docs/feedback/`**: 읽기 전용, 수정 금지 (외부 피드백 원본 보존)

### FAQ 작성 규칙

작업 중 아래 상황이 발생하면 `docs/faq/`에 문서를 추가하고 이 파일의 FAQ 섹션에 링크를 추가한다:

- 설계의 의도를 잘못 이해했다가 바로잡은 경우
- "왜 X 대신 Y를 쓰는가"에 대한 답을 찾은 경우
- 비슷해 보이는 두 개념의 차이를 명확히 한 경우
- 반복적으로 헷갈릴 수 있는 아키텍처 결정이 드러난 경우

## FAQ

- [NanoClaw Task Dispatch — IPC vs HTTP Channel](./docs/faq/nanoclaw-task-dispatch.md): `ipc/{group}/tasks/`(내부 자기 디스패치)와 `add-http` 스킬(FastAPI → NanoClaw 위임 브리지)의 차이.
- [Desktop Homunculus MOD 시스템](./docs/faq/desktop-homunculus-mod-system.md): MOD 철학, Service/UI/Bin 진입점, Glassmorphism UI, signals 통신, preferences 저장.
- [Upstream Fork CLAUDE.md 충돌 방지](./docs/faq/upstream-fork-claude-md.md): fork repo에서 학습 기록 시 `.claude/rules/team-local.md`를 쓰는 이유.
- **[NanoClaw Skill 작성 가이드](./docs/faq/nanoclaw-skill-writing-guide.md)**: SKILL.md 구조, 커밋/PR 규칙. Critical — NanoClaw 소스 직접 수정 금지.
- **[FE Design Agent Workflow](./docs/faq/fe-design-agent-workflow.md)**: design-agent 스폰 조건, E2E scaffold vs unit test 경계, `design/{feature}` PR 흐름.

## Agent Teams

Agent definitions: `.claude/agents/`. gstack skills drive all workflow logic.

### Main Level Agents

| Agent | Model | Role | Skills | Spawn Condition |
|-------|-------|------|--------|-----------------|
| **Lead** | opus | Phase 위임 + Plans.md + delegation only | — | persistent |
| `pm-agent` | sonnet | Feature spec → TODO.md | `/office-hours`, `/learn` | user 피처 요청 시 |
| `reviewer` | sonnet | **Spec review only** | `/autoplan`, `/browse` | planning 단계 |
| `design-agent` | sonnet | FE mockup + spec + E2E scaffold | `/design-*`, `/browse` | PM spec에 `[target: desktop-homunculus/]` + UI 변경 |
| `pr-merge-agent` | sonnet | PR 코멘트 분류 → 답변 → 머지 | Bash, Read, Grep, Glob | 긴급/수동 시만 (정상은 `/babysit` cron) |
| `quality-agent` | sonnet | 품질 모니터링 → report 작성 | Read, Bash, Grep, Glob, Write | daily cron (09:07 KST) |

### Worker Sub-Team (per repo, Main Lead가 3명 동시 스폰)

> Teammate는 다른 teammate를 스폰할 수 없음 (flat roster). Main Lead가 3명 모두 스폰.

| Agent | Model | Role | Skills |
|-------|-------|------|--------|
| `worker-lead` | sonnet | Sub-team coordinator | `/simplify`, `/ship`, `/learn` |
| `worker-coder` | sonnet | TDD 구현 | `/harness-work`, `/investigate`, `/learn` |
| `worker-reviewer` | sonnet | Code review | `/review`, `/cso`, `/qa`, `/browse` |

### Lead 제약

- **직접 실행 금지**: `/office-hours`, `/ship`, `/simplify`, `/document-release`, 코드 분석, 구현 판단
- **research는 sub-agent 위임**: 조사/탐색 작업은 Explore agent 등으로 위임
- **에이전트 스폰 = 팀 워크플로우**: TeamCreate → TaskCreate → TaskUpdate(owner) → Agent(team_name) 순서 필수
- **Worker 내부 iteration 불개입**: FAIL→수정→재리뷰 사이클은 Worker Sub-Team 자율 운영

### Worker Sub-Team Rules

- **Worker Lead**: 코드 직접 편집 금지. Coder 완료 + Reviewer PASS 후에만 `/simplify` → `/ship`
- **Worker-Coder**: `/harness-work` 필수, 직접 코드 구현 금지. Worker Lead에게만 보고
- **Worker-Reviewer**: Correctness / Security / Maintainability / Test Coverage (0–3, 2 미만 시 자동 FAIL). FAIL 시 Coder에게 직접 이슈 전달
- **재활용**: 같은 레포 연속 태스크 → Worker Lead에 `SendMessage` 재사용. 재스폰 기준: `total_tokens` ≥ 80k / `tool_uses` ≥ 60 / 레포 변경
- **E2E Backend**: Worker-Coder가 직접 backend 기동 + 테스트 후 정리 (유저에게 요청 금지)

### Workflow Commands

| Command | 용도 | 실행 주체 |
|---------|------|-----------|
| `/phase-dispatch` | 새 Phase 시작 — Plans.md → TeamCreate → Worker Lead 스폰 | Lead |
| `/babysit` | 오픈 PR 전수 점검 — 리뷰 대응, 리베이스, 머지, `/document-release` | cron (5분) |
| `/cleanup` | Phase 완료 후 팀 종료 + 워크트리 정리 | Lead |
| `/post-merge-sweeper` | 머지 후 24h 내 미처리 코멘트 탐색 → fix PR 생성 | cron / Lead |
| `/pr-pruner` | 14일+ stale PR close, 7일+ warning 코멘트 | cron / Lead |

### End-to-End Flow

```
1. User request
2. Lead → PM agent (`/office-hours` → spec + docs/TODO.md)
3. Lead → Plans.md 태스크 작성 (cc:TODO)
4. Lead → Reviewer (`/autoplan` → spec review)
5. Lead → `/phase-dispatch` (TeamCreate → Worker Lead + Coder + Reviewer 동시 스폰)
   - UI 피처면 Design Agent 먼저 (mockup → spec → E2E scaffold)
6. Worker Sub-Team 자율 운영:
   a. Worker Lead가 Coder + Reviewer에게 SendMessage로 조율
   b. Coder: /investigate → /harness-work → 완료 보고
   c. Reviewer: /review + /cso → PASS/FAIL
   d. FAIL → Coder 수정 → Reviewer 재리뷰 (서브팀 내 자율 순환)
   e. PASS → Worker Lead: /simplify → /ship → PR 생성
7. Worker Lead → Main Lead에게 최종 보고 (PR URL, test results)
8. `/babysit` cron (PR 머지 → `/document-release`)
9. Lead → `/cleanup` (팀 종료 + 워크트리 정리)
```

### Skill 책임 분리

| Skill | 실행 주체 | Lead 직접 실행 |
|-------|-----------|---------------|
| `/office-hours` | pm-agent | ❌ |
| `/harness-work`, `/investigate` | worker-coder | ❌ |
| `/review`, `/cso`, `/qa` | worker-reviewer | ❌ |
| `/simplify`, `/ship`, `/document-release` | worker-lead | ❌ |
| `/autoplan` | reviewer (Main Level) | ❌ |
| `/phase-dispatch`, `/cleanup` | Lead | ✅ |
| `/babysit`, `/post-merge-sweeper`, `/pr-pruner` | cron / Lead | ✅ |

### Worktree Rules

**모든 구현 작업은 feature 브랜치 + worktree에서 진행한다. workspace root 포함.**

- Sub-repo: `git -C <repo>/ worktree add worktrees/feat-<slug> feat/<slug>`
- Workspace root: `git worktree add ../DesktopMatePlus-feat-<slug> feat/<slug>`
- Do NOT use `isolation: "worktree"` from workspace root.
- Do NOT commit directly to `master`/`main`/`develop`.

**Branch prefix**: `{feat|fix|docs|refactor|chore|test}/p{N}-t{id}` (e.g. `feat/p21-t1`)

## gstack

Use `/browse` for all web browsing. **Never use `mcp__claude-in-chrome__*` tools.**

If gstack skills aren't working: `cd ~/.claude/skills/gstack && ./setup`

## Appendix

- [Feature TODO](./docs/TODO.md): Active feature specs and priority list.
- [Data Flows](./docs/data_flow/): Mermaid diagrams — chat, channel, agent (LTM, DelegateTask), desktopmate-bridge.
- [FAQ](./docs/faq/): Architectural decisions Q&A.
- [Plans.md](./Plans.md): Cross-repo task tracking (cc:TODO / cc:DONE).
- [Scripts Reference](./docs/scripts-reference.md): garden.sh / e2e.sh / check_docs.sh / run-quality-agent.sh 등.
- [/babysit](./.claude/commands/babysit.md) · [/cleanup](./.claude/commands/cleanup.md) · [/phase-dispatch](./.claude/commands/phase-dispatch.md) · [/post-merge-sweeper](./.claude/commands/post-merge-sweeper.md) · [/pr-pruner](./.claude/commands/pr-pruner.md): Workflow command references.
