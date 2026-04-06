### Phase 21: 워크플로우 문서 모순 해소 — spec-ref: docs/TODO.md#spec-6

<!-- source: docs/TODO.md Spec 6 (2026-04-03). 7개 모순 항목 수정. -->

- [x] **WF-1: Agent definition 파일 수정** cc:DONE — `.claude/agents/` 내 4개 파일 일관성 수정. ① `quality-agent.md` Constraints에 "PR 생성은 run-quality-agent.sh 담당" 명시 ② `create-pr` 스킬 디렉토리 삭제 ③ `pr-merge-agent.md` quality PR 블록 로직 → AUTO_FIX/ACKNOWLEDGE/NEEDS_LEAD 분류로 교체, `run-quality-agent.sh` PR body 직접 체크 안내 제거 ④ `pm-agent.md` Lifecycle Step 4 "PM writes Plans.md" → "PM writes docs/TODO.md, Plans.md는 Lead 책임" ⑤ `pr-merge-agent.md` 용어 "봇/사람 리뷰어" → "GitHub Bot Reviewer / GitHub Human Reviewer". DoD: 5개 항목 반영 완료. [target: DesktopMatePlus/]
- [x] **WF-2: CLAUDE.md·FAQ·PR 템플릿 수정** cc:DONE — ① `CLAUDE.md` Agent Teams Flow에 "APPROVE 후 worker가 /ship" 타이밍 명시 ② `CLAUDE.md` Worktree Rules + `docs/faq/fe-design-agent-workflow.md`에 브랜치 prefix 규칙 (`{prefix}/p{N}-t{id}`, prefix ∈ `{feat,fix,docs,refactor,chore,test,ci,build}`) 및 design-agent → worker 브랜치 인계 흐름 추가 ③ `.github/pull_request_template.md` 첫 번째 체크박스를 "i already confirm E2E test is passed"로 변경 ④ `safety-guardrails.md` quality-agent 행에 "(AI agent 기준)" 주석 추가. DoD: 4개 항목 반영 완료. Depends: none. [target: DesktopMatePlus/]
