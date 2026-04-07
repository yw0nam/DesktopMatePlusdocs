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

## Task Tracking

- **`Plans.md`**: 간단한 체크리스트. `- [ ]` TODO, `- [x]` DONE.
- **`docs/TODO.md`**: 활성 스펙 목록. Priority (P0/P1/P2) + Status (TODO/DONE) 테이블 형식.

### docs/ 규칙 요약

- **본문 200줄 한도** — 초과 시 기능 단위로 분리, 인덱스 문서로 관리 ([전체 규칙](./docs/guidelines/DOCUMENT_GUIDE.md))
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
- [Desktop Homunculus MOD 유형별 구조](./docs/faq/desktop-homunculus-mod-types.md): Service-only/UI/Service+UI MOD 전체 코드 예제.
- [Upstream Fork CLAUDE.md 충돌 방지](./docs/faq/upstream-fork-claude-md.md): fork repo에서 학습 기록 시 `.claude/rules/team-local.md`를 쓰는 이유.
- **[NanoClaw Skill 작성 가이드](./docs/faq/nanoclaw-skill-writing-guide.md)**: SKILL.md 구조, 커밋/PR 규칙. Critical — NanoClaw 소스 직접 수정 금지.
- **[FE Design Agent Workflow](./docs/faq/fe-design-agent-workflow.md)**: design-agent 스폰 조건, E2E scaffold vs unit test 경계, `design/{feature}` PR 흐름.
- [TTS 청크 누락 — WebSocket max_size 제한](./docs/faq/tts-chunk-delivery-websocket-max-size.md): 서버 정상 전송인데 클라이언트 누락 시 `websockets` `max_size` 확인. 오진 포인트 정리.

## Workflow

OMC 네이티브 + Gemini cross-model review + PR Review Toolkit 기반.

### Agents

| Agent | Role | Spawn Condition |
|-------|------|-----------------|
| **Lead** (persistent, opus) | 판단 + 위임 + Plans.md 관리 | persistent |
| `design-agent` (sonnet) | DH FE design: mockup + spec + E2E scaffold | DH UI 피처 시 (Coder 시작 전) |
| `dh-qa-agent` (sonnet) | DH runtime/UX QA: 7-item 체크리스트 검증 | DH 태스크 시 (Coder와 병렬) |
| `quality-agent` (sonnet) | garden.sh + GP 검증 + report | daily cron (09:07 KST) |

OMC 네이티브 에이전트(`executor`, `analyst`, `code-reviewer` 등)는 필요 시 직접 스폰.

### Execution Flow

```
1. User request
2. Lead: 큰 피처 → /ralplan (consensus planning) → Plans.md 체크리스트
         단순 작업 → 바로 Coder 스폰
3. Coder (executor agent, worktree 격리):
   a. 구현 (TDD — 테스트 먼저)
   b. E2E 직접 실행 → PASS 필수
   c. git diff | gemini review → PASS 필수
      └─ FAIL → 수정 → 재리뷰
   d. /pr-review-toolkit:review-pr code tests errors → Critical 이슈 없음 필수
      └─ Critical 발견 → 수정 → 재실행
         (타입 추가 시 +types, 문서 변경 시 +comments 옵션 추가)
   e. PR 생성
   f. Plans.md 체크 표시
4. DH UI 태스크: design-agent 먼저 (DESIGN_READY) → Coder + dh-qa-agent 병렬 → 둘 다 PASS 필요
   DH 버그픽스 (UI 없음): Coder + dh-qa-agent 병렬 → 둘 다 PASS 필요
5. /babysit cron → PR 리뷰 대응, 머지, 브랜치 정리
```

### Coder 규칙

- **TDD 필수**: 테스트 먼저 작성, 구현은 그 다음
- **E2E 게이트**: backend는 직접 기동 + 테스트 실행 후 정리 (유저에게 요청 금지)
- **Gemini Review 게이트**: `git diff | gemini -p "review this diff"` → APPROVE 필수
- **PR Review Toolkit 게이트**: `/pr-review-toolkit:review-pr code tests errors` → Critical 이슈 없음 필수
  - 타입(Pydantic 모델, TS 타입) 추가/변경 시: `+types`
  - 문서/주석 변경 시: `+comments`
  - Gemini APPROVE 이후, PR 생성 직전에 실행
  - Critical 이슈 → 즉시 수정 후 재검증
  - 스코프 밖 이슈(pre-existing 파일 등) → [docs/KNOWN_ISSUES.md](./docs/KNOWN_ISSUES.md)에 기록
- **Worktree 격리**: feature 브랜치에서 작업, master/main/develop 직접 커밋 금지

### Automation (cron)

| Command | 용도 | 주기 |
|---------|------|------|
| `/babysit` | 오픈 PR 전수 점검 — 리뷰 대응, 리베이스, 머지 | 5분 |
| `/post-merge-sweeper` | 머지 후 24h 내 미처리 코멘트 → fix PR | daily / manual |
| `/pr-pruner` | 14일+ stale PR close, 7일+ warning | daily / manual |

### Worktree Rules

- Sub-repo: `git -C <repo>/ worktree add worktrees/feat-<slug> feat/<slug>`
- Workspace root: `git worktree add ../DesktopMatePlus-feat-<slug> feat/<slug>`
- Do NOT use `isolation: "worktree"` from workspace root.
- Do NOT commit directly to `master`/`main`/`develop`.

## Appendix

- [Feature TODO](./docs/TODO.md): Active feature specs and priority list.
- [Known Issues](./docs/KNOWN_ISSUES.md): PR review에서 발견된 스코프 밖 기술 부채 추적.
- [Data Flows](./docs/data_flow/): Mermaid diagrams — chat, channel, agent (LTM, DelegateTask), desktopmate-bridge.
- [FAQ](./docs/faq/): Architectural decisions Q&A.
- [Plans.md](./Plans.md): Cross-repo task checklist.
- [Scripts Reference](./docs/scripts-reference.md): garden.sh / e2e.sh / check_docs.sh / run-quality-agent.sh 등.
- [/babysit](./.claude/commands/babysit.md) · [/post-merge-sweeper](./.claude/commands/post-merge-sweeper.md) · [/pr-pruner](./.claude/commands/pr-pruner.md): Workflow command references.
