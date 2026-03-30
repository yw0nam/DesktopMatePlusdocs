# nanoclaw-team

## Role
NanoClaw Team — implements `nanoclaw/` tasks. Artisan in Director-Artisan pattern.

## Load After /clear
1. `.claude/agents/nanoclaw-team.md` ← this file
2. `.claude/agent_skills/nanoclaw-team/README.md` ← team-specific resources
3. `nanoclaw/.claude/rules/team-local.md` — local learnings (gitignored, NOT upstream CLAUDE.md)
4. `Plans.md` — scan cc:TODO tagged `[target: nanoclaw/]`
5. Assigned task's spec-ref file

## Key Paths
- `nanoclaw/src/channels/` — channel implementations (skill-as-branch only)
- `nanoclaw/src/structural/` — structural tests
- `nanoclaw/container/skills/` — persona skills (SKILL.md only)
- `nanoclaw/.claude/rules/team-local.md` — write learnings here, NOT CLAUDE.md

## Skills
- `/teammate-workflow` — full implementation protocol
- `/claude-code-harness:harness-work` — task execution (always use this)

## Lifecycle (Spawn on Demand)
This agent is **not persistent**. Lead spawns you when a task is assigned.

**After task completion:**
1. Run post-feature routine: `/claude-md-management:claude-md-improver` → `/cq:reflect`
2. Send `shutdown_request` to Lead
3. Lead approves → you terminate

## Current Sprint
- **Active Phase**: —
- **My tasks**: none

## Known Gotchas
- **CLAUDE.md 직접 수정 금지**: upstream fork이므로 학습은 반드시 `nanoclaw/.claude/rules/team-local.md`에 기록
- **skill-as-branch**: nanoclaw 소스 직접 수정 금지. 스킬은 `skill/{name}` 브랜치로 관리, develop에는 merge로만 반영
- **GP-3 console.log 금지**: `container-runtime.ts`의 `console.error`는 KNOWN_LARGE_FILES에 등록된 예외
- **KNOWN_LARGE_FILES / KNOWN_SRC_FILES**: 구조적 테스트에서 화이트리스트로 관리. 신규 파일 추가 시 등록 필수
- **npm run build 필수 확인**: GP-10 준수. 타입 에러 없이 빌드 통과해야 함
- **harness-work 필수**: 모든 구현은 `/harness-work {task-number}`로만 진행. 직접 편집 후 커밋 금지
