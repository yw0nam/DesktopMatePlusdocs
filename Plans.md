# DesktopMatePlus — Lead Agent Coordination

> **Lead Agent Rule**: This agent delegates and coordinates ONLY. Never writes code directly.
> All implementation is delegated to `worker` agent via Agent Teams.

## Repos

| Short | Repo | Stack | Constraint |
|-------|------|-------|------------|
| BE | `backend/` | Python / FastAPI / uv | — |
| NC | `nanoclaw/` | Node.js / TypeScript | skill-as-branch only (no direct source edit) |
| FE | `desktop-homunculus/` | Rust / Bevy + TypeScript MOD | separate git repo |

## Task ID Conventions

| Prefix | Meaning | Agent | Notes |
|--------|---------|-------|-------|
| `BE-*` | Backend task | worker (BE) | FastAPI / Python |
| `NC-*` | NanoClaw task | worker (NC) | skill-as-branch only |
| `DH-F*` | desktop-homunculus feature | worker (FE) | FE visible UI |
| `DA-S*` | Design Agent setup/docs | worker (docs) | DesktopMatePlus root |
| `DA-*` | Design Agent FE feature | design-agent → worker (FE) | Use when PM spec targets `desktop-homunculus/` + UI change |

### DA-xxx 태스크 작성 규칙

`DA-` prefix는 design-agent가 개입하는 FE feature 태스크에 사용한다.

형식:

```
- [ ] **DA-{N}: {feature name}** — {summary}. DoD: {criteria}. Depends: {id or none}. [target: desktop-homunculus/]
```

DA 태스크 Phase에는 다음 2개 태스크 유형을 함께 작성한다:

1. **DA-{N}-design**: design-agent 산출물 태스크 (mockup + spec + E2E scaffold)
   - DoD: `design/{feature}/` 브랜치에 3개 artifacts 존재 + DESIGN_READY 신호
2. **DA-{N}-impl**: worker 구현 태스크 (design-agent PR base로 구현)
   - DoD: E2E scaffold assertion 구현 + unit test 통과 + /review APPROVE
   - Depends: DA-{N}-design

## Active Cross-Repo Tasks

<!-- cc:TODO format: [ ] **TASK-ID: description** — summary. DoD: criteria. Depends: id or none. spec-ref: docs/superpowers/specs/{file}.md. [ref: INDEX#{section}/{id}] (feature tasks only). [target: repo/] -->

<!-- BE 태스크 DoD 표준: 신규 BE-* 태스크는 `bash backend/scripts/e2e.sh` PASSED를 DoD 체크리스트에 포함해야 함. 기존 cc:DONE 태스크에는 소급 적용하지 않음. -->

<!-- Phases 12–17, 19–20: archived to docs/archive/plans-2026-04.md on 2026-04-03 -->

### Phase 18: OpenSpace 시범 도입 (backend) — 유저 지시 시 진행

<!-- triggered by: user request only. Do NOT start autonomously. -->
<!-- OpenSpace: 로컬 실행. Dashboard backend: http://localhost:7788, Frontend: http://localhost:3789 -->
<!-- Cloud 미사용 (OPENSPACE_API_KEY 불필요). 모든 스킬은 로컬 저장. -->
<!-- LLM: 로컬 vLLM (http://192.168.0.41:5535, OpenAI-compatible API). OPENSPACE_LLM_API_BASE=http://192.168.0.41:5535/v1, OPENSPACE_LLM_API_KEY=token-abc123, OPENSPACE_MODEL=openai/chat_model -->

- [ ] **INFRA-1: OpenSpace MCP 설정 (backend)** cc:TODO — `OpenSpace/` repo를 backend worker용 MCP 서버로 등록 (로컬 전용, cloud 미사용). `.claude/settings.json`에 openspace MCP 추가, `OPENSPACE_HOST_SKILL_DIRS`를 backend skills 경로로 지정. Dashboard: backend `http://localhost:7788`, frontend `http://localhost:3789`. DoD: worker가 openspace MCP 도구 호출 가능. Depends: none. [target: DesktopMatePlus/]
- [ ] **INFRA-2: OpenSpace host_skills 배치** cc:TODO — `delegate-task/SKILL.md` + `skill-discovery/SKILL.md`를 backend worker가 참조할 수 있는 위치에 복사. DoD: worker가 skill-discovery로 기존 스킬 검색 가능. Depends: INFRA-1. [target: backend/]
- [ ] **INFRA-3: 효과 측정 기준 정의** cc:TODO — 토큰 사용량 비교(Phase 17 대비), 자동 캡처된 스킬 수, 스킬 재사용률 지표 정의. DoD: 측정 기준 문서 작성. Depends: INFRA-1. [target: DesktopMatePlus/]
- [ ] **INFRA-4: 파일럿 태스크 실행 + 평가** cc:TODO — backend 태스크 2~3개를 OpenSpace 적용 worker로 실행, Phase 17 동일 유형 태스크와 비교. DoD: 효과 측정 보고서 작성. Depends: INFRA-2, INFRA-3. [target: backend/]

### Phase 21: 워크플로우 문서 모순 해소 — spec-ref: docs/TODO.md#spec-6

<!-- source: docs/TODO.md Spec 6 (2026-04-03). 7개 모순 항목 수정. -->

- [x] **WF-1: Agent definition 파일 수정** cc:DONE — `.claude/agents/` 내 4개 파일 일관성 수정. ① `quality-agent.md` Constraints에 "PR 생성은 run-quality-agent.sh 담당" 명시 ② `create-pr` 스킬 디렉토리 삭제 ③ `pr-merge-agent.md` quality PR 블록 로직 → AUTO_FIX/ACKNOWLEDGE/NEEDS_LEAD 분류로 교체, `run-quality-agent.sh` PR body 직접 체크 안내 제거 ④ `pm-agent.md` Lifecycle Step 4 "PM writes Plans.md" → "PM writes docs/TODO.md, Plans.md는 Lead 책임" ⑤ `pr-merge-agent.md` 용어 "봇/사람 리뷰어" → "GitHub Bot Reviewer / GitHub Human Reviewer". DoD: 5개 항목 반영 완료. [target: DesktopMatePlus/]
- [x] **WF-2: CLAUDE.md·FAQ·PR 템플릿 수정** cc:DONE — ① `CLAUDE.md` Agent Teams Flow에 "APPROVE 후 worker가 /ship" 타이밍 명시 ② `CLAUDE.md` Worktree Rules + `docs/faq/fe-design-agent-workflow.md`에 브랜치 prefix 규칙 (`{prefix}/p{N}-t{id}`, prefix ∈ `{feat,fix,docs,refactor,chore,test,ci,build}`) 및 design-agent → worker 브랜치 인계 흐름 추가 ③ `.github/pull_request_template.md` 첫 번째 체크박스를 "i already confirm E2E test is passed"로 변경 ④ `safety-guardrails.md` quality-agent 행에 "(AI agent 기준)" 주석 추가. DoD: 4개 항목 반영 완료. Depends: none. [target: DesktopMatePlus/]

### Phase 22: Quality Debt 해소 — source: quality-2026-04-03.md

<!-- source: docs/reports/quality-2026-04-03.md (2026-04-03). GP-3/4/13 위반 + garden.sh 버그 + 아카이브 정리. -->

- [x] **QA-1: BE GP-4 하드코딩 URL 해소** cc:DONE — `backend/` 내 하드코딩 URL 5개를 `yaml_files/` YAML 설정 또는 환경변수로 이전. 대상: `vllm_omni.py:20` (base_url), `tts_factory.py:38` (IRODORI_URL), `disconnect_handler.py:11` (BACKEND_URL), `agent_factory.py:46` (openai_api_base), `delegate_task.py:15` (NANOCLAW_URL). DoD: GP-4 PASS + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **QA-2: BE GP-3 bare print 제거** cc:DONE — `ltm_factory.py:40,50,52`, `vllm_omni.py:264,272` bare print → loguru. DoD: GP-3 PASS + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **QA-3: DH-MOD GP-13 console.log + 파일 크기** cc:DONE — ① `tts-chunk-queue.ts:85,104` console.log 제거 (프로덕션 코드) ② `ControlBar.test.tsx` (445줄) → 400줄 이하로 분리. DoD: GP-13-console PASS + GP-13-size PASS. Depends: none. [target: desktop-homunculus/]
- [x] **QA-4: garden.sh 버그 수정 + scripts/ 예외 처리** cc:DONE — ① GP-13 console.log 체크에서 `mods/*/scripts/` 디렉토리 제외 ② `update_quality_score()` 함수가 `QUALITY_SCORE.md` Violations Summary 섹션을 실제 위반 수로 갱신하도록 수정. DoD: GP-13-console이 scripts/ 파일을 스캔하지 않음 + QUALITY_SCORE.md Violations Summary가 정확히 갱신됨. Depends: none. [target: DesktopMatePlus/]
- [x] **QA-5: Plans.md 아카이브 + docs/superpowers check_docs 제외** cc:DONE — ① Plans.md Phase 12~20 완료 Phase → `docs/archive/plans-2026-04.md`로 이전 ② `scripts/check_docs.sh`에서 `docs/superpowers/` 디렉토리를 dead link 및 oversized 체크 제외 목록에 추가. DoD: Plans.md cc:DONE Phase 5개 미만 잔존 + GP-12 PASS + check_docs.sh superpowers 스캔 안 함. Depends: none. [target: DesktopMatePlus/]

### Phase 23: Mascot Reaction System + VRM Position UI — spec-ref: docs/TODO.md#spec-7, #spec-8

<!-- source: docs/TODO.md Spec 7 (2026-04-04), Spec 8 (2026-04-04). -->

- [x] **BE-23-1: TTS speak endpoint 추가** cc:DONE [1fb7a27] — `backend/src/api/routes/tts.py`에 `POST /v1/tts/speak` 추가 (`text` → `{ audio_base64 }`). DoD: Pytest TDD 통과 + `bash backend/scripts/e2e.sh` PASSED. Depends: none. [target: backend/]
- [x] **DH-23-1: ReactionController 구현** cc:DONE [419386d] — `desktopmate-bridge/src/reaction-controller.ts` 신규. Click/Idle(5분)/ScreenContext(`active-win`) 3가지 트리거. `tts-chunk-queue.ts`에 `isBusy()` 추가(채팅 TTS 충돌 방지). `config.yaml`에 `reactions` 섹션 추가. `pnpm add active-win`. DoD: Vitest unit test 통과(click/idle/window 각 트리거) + E2E mock 테스트 통과 + 채팅 TTS 중 reaction skip. Depends: BE-23-1. [target: desktop-homunculus/]
- [x] **BE-23-fix: e2e 버그 수정** cc:DONE [8610cc1] — `invoke()` persona SystemMessage 중복 삽입 방지 (`and not session_id`). `ltm_middleware.py` SystemMessage 중복 주입 방지. `stm.py` session_registry upsert + checkpointer.delete_thread() 추가. DoD: e2e.sh Phase 4/5 PASSED. [target: backend/]
- [x] **DH-23-2: VRM Position Adjustment UI** cc:DONE [491d2be] — `character-settings` MOD `BasicTab.tsx`에 Position X/Y 슬라이더 + 숫자 입력 추가. `useCharacterSettings.ts` posX/posY state 추가. Save 클릭 시만 반영(실시간 미리보기 없음). `translation[2]` 보존 필수. DoD: Vitest unit test 통과 + `/agent-browser` visual verification + 슬라이더 range 실측 확인. Depends: none. [target: desktop-homunculus/]

## Completed

<!-- Phases 12–17, 19–20: archived to docs/archive/plans-2026-04.md on 2026-04-03 -->
