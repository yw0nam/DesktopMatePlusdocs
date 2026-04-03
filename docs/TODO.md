# DesktopMatePlus — Feature TODO

PM agent가 office-hours 상담 후 작성. Lead가 Plans.md로 가져가 태스크화한다.

---

## Active TODO

| # | Feature | Priority | Status | Spec |
|---|---------|----------|--------|------|
| 6 | 워크플로우 문서 모순 해소 | P1 | DONE | [spec](#spec-6-워크플로우-문서-모순-해소) |

---

## Specs

### Spec 6: 워크플로우 문서 모순 해소

**출처**: 2026-04-03 Lead-PM 워크플로우 감사. `.claude/agents/` ↔ CLAUDE.md 간 7개 모순 발견.

**변경 대상**:

1. `quality-agent.md` Constraints — "PR 생성은 run-quality-agent.sh(cron orchestrator) 담당, AI agent 자신은 docs/reports/ 보고서 작성까지" 명시
2. `create-pr` 스킬 삭제 — `/ship`으로 통일. CLAUDE.md available skills 목록에서 제거
3. `pr-merge-agent.md` quality PR 체크박스 처리 — 블록 로직을 AUTO_FIX/ACKNOWLEDGE/NEEDS_LEAD 분류 처리로 교체. `run-quality-agent.sh` PR body "직접 체크" 안내 제거
4. `pm-agent.md` Lifecycle Step 4 — "PM writes Plans.md" → "PM writes docs/TODO.md, Plans.md는 Lead 책임"으로 수정
5. `pr-merge-agent.md` 용어 — "봇 리뷰어/사람 리뷰어" → "GitHub Bot Reviewer / GitHub Human Reviewer" (CLAUDE.md `reviewer` agent와 구분)
6. `CLAUDE.md` Agent Teams Flow — worker 흐름에 "APPROVE 후 worker가 /ship" 타이밍 명시
7. `CLAUDE.md` + `docs/faq/fe-design-agent-workflow.md` — worktree 브랜치 규칙: `{prefix}/p{N}-t{id}`, prefix ∈ `{feat,fix,docs,refactor,chore,test,ci,build}`. design-agent worktree → worker 동일 브랜치 인계 흐름 명시
8. `.github/pull_request_template.md` — "i already confirm E2E test is passed" 로 첫번째 체크박스 변경.

**DoD**:

- 위 파일 변경 완료 (create-pr/ 삭제 포함)
- `safety-guardrails.md` quality-agent 행 "(AI agent 기준)" 주석 추가
- `CLAUDE.md` Worktree Rules에 브랜치 prefix 규칙 명시

---

## Completed

Spec 1~5 (Phase 20 완료) → [docs/archive/todo-2026-04.md](./archive/todo-2026-04.md)

Spec 6 (Phase 21 완료, 2026-04-03) — 워크플로우 문서 모순 해소. PR #5 (docs/p21-twf → master) 머지 완료.
