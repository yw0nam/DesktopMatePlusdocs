# DesktopMatePlus — Feature TODO

PM agent가 office-hours 상담 후 작성. Lead가 Plans.md로 가져가 태스크화한다.

---

## Active TODO

| # | Feature | Priority | Status | Spec |
|---|---------|----------|--------|------|
| 6 | 워크플로우 문서 모순 해소 | P1 | DONE | [spec](#spec-6-워크플로우-문서-모순-해소) |
| 7 | Mascot Reaction System | P1 | DONE | [spec](#spec-7-mascot-reaction-system) |
| 8 | VRM Position Adjustment UI | P2 | DONE | [spec](#spec-8-vrm-position-adjustment-ui) |
| 9 | E2E 테스트 확장 (TTS + LTM) | P2 | TODO | [spec](#spec-9-e2e-테스트-확장) |
| 10 | VRM 런타임 교체 UI | P2 | TODO | [spec](#spec-10-vrm-런타임-교체-ui) |

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

### Spec 7: Mascot Reaction System

**출처**: 2026-04-04 PM office-hours. 마스코트가 채팅 외 인터렉션에 반응하지 않는 문제.

**대상 레포**: `desktop-homunculus` (desktopmate-bridge MOD) + `backend` (TTS endpoint)

**구현 목표**:

마스코트(오나)가 세 가지 트리거에 반응하도록 Reaction System 추가:

1. **Click Reaction** — Primary 클릭 시 표정 + 대사 반응 (Secondary = 메뉴, 변경 없음)
2. **Idle Detection** — VRM pointer 이벤트 없음 5분 후 자동 대사
3. **Screen Context** — `active-win`으로 포커스 창 타이틀 감지 → 상황 코멘트

**기술 변경**:

- `backend/src/api/routes/tts.py`: `POST /v1/tts/speak` 추가 (`text` → `{ audio_base64 }`)
- `desktopmate-bridge/src/reaction-controller.ts`: 신규. `ReactionController` 클래스
- `desktopmate-bridge/src/tts-chunk-queue.ts`: `isBusy()` 메서드 추가 (채팅 TTS 충돌 방지)
- `desktopmate-bridge/config.yaml`: `reactions` 섹션 추가 (대사 YAML 테이블)
- `desktopmate-bridge/package.json`: `pnpm add active-win` + vite externalize 설정

**진화 경로**: YAML config(이번) → `POST /v1/reactions/{type}` backend API(다음)

**DoD**:

- Backend: `POST /v1/tts/speak` Pytest TDD 통과
- MOD: `reaction-controller.test.ts` Vitest unit test 통과 (click/idle/window 각 트리거)
- E2E: `mock-homunculus.ts` mock + E2E 테스트 통과
- Primary 클릭 → 2초 이내 표정 + 대사
- 5분 비활성 → idle 발화
- YouTube 포커스 창 → 자동 코멘트 (동일 창 중복 없음)
- 기존 채팅 TTS 발화 중 reaction skip (isChatSpeaking 충돌 방지)

**Design Doc**: `~/.gstack/projects/yw0nam-DesktopMatePlusdocs/spow12-master-design-20260404-151343.md`

### Spec 8: VRM Position Adjustment UI

**출처**: 2026-04-04 Lead 위임. 드래그 외 수치 기반 VRM 위치 지정 필요.

**대상 레포**: `desktop-homunculus` (`character-settings` MOD)

**귀속 MOD**: `character-settings` — `entities.transform()` + `BasicTab` 기존 패턴 재사용. 신규 MOD 불필요.

**구현 목표**:

`character-settings` UI의 Basic 탭에 Position X / Position Y 슬라이더 + 숫자 입력 추가.
Save 클릭 시 `entities.setTransform()`으로 반영. 실시간 미리보기 없음(MVP).

**기술 변경**:

| 파일 | 변경 |
|------|------|
| `character-settings/ui/src/hooks/useCharacterSettings.ts` | posX/posY state + load/save 로직 |
| `character-settings/ui/src/components/BasicTab.tsx` | x/y 슬라이더 + 숫자 입력 UI |
| `character-settings/ui/src/App.tsx` | posX/posY prop 전달 |

신규 파일 없음. 의존성 추가 없음.

**DoD**:

- BasicTab에 Position X / Y 슬라이더 + 숫자 입력 렌더링
- Save 클릭 → `entities.setTransform()` 호출 → VRM 위치 반영
- 슬라이더/숫자 변경 시 즉각 이동 없음 (Save 전 변경 없음)
- `translation[2]` (z) 값 보존 확인
- 기존 Scale/Persona/OCEAN 저장 동작 유지
- Visual verification (`/agent-browser`) + 슬라이더 range 실측 확인

**Design Doc**: `~/.gstack/projects/yw0nam-DesktopMatePlusdocs/spow12-master-design-20260404-spec8.md`

### Spec 9: E2E 테스트 확장 (TTS + LTM)

**출처**: 2026-04-05 Lead-User 논의. Phase 23 신규 기능 e2e 커버리지 보강.

**대상 레포**: `backend/`

**구현 목표**:

1. **`test_tts_speak.py` 신규** — `POST /v1/tts/speak` 엔드포인트 E2E 검증
   - `text` 파라미터로 호출 → `audio_base64` 키 존재 + 값 비어있지 않음 확인
   - TTS 서버 미실행 시 SKIP (Phase 1.5 결과 활용)
   - Reaction 트리거가 결국 이 엔드포인트를 호출하므로 Reaction E2E 커버 간주

2. **`test_ltm.py` 확장** — LTM 통합 시나리오 추가
   - 기존: store → search
   - 추가: store 후 WebSocket 1턴 대화 → 응답에 LTM 메모리 반영 여부 확인

**DoD**:
- `test_tts_speak.py` e2e.sh Phase 4에 추가, TTS 서버 있을 때 PASSED
- `test_ltm.py` WebSocket 통합 시나리오 PASSED (Qdrant 있을 때)
- `bash backend/scripts/e2e.sh` 전체 PASSED

---

### Spec 10: VRM 런타임 교체 UI

**출처**: 2026-04-05 PM office-hours. **대상**: `desktop-homunculus` (`character-settings` MOD)

**Design Doc**: `~/.gstack/projects/yw0nam-nanoclaw/spow12-develop-design-20260405-092715.md`

**구현 목표**: `character-settings` Basic 탭에 VRM 모델 드롭다운 추가. `assets.list({ type: "vrm" })` 목록 표시, Save 시 despawn → spawn → `setLinkedVrm` 시퀀스로 교체. Persona/scale/posX/posY 보존. `isSwapping` 가드로 이중 클릭 방지.

**변경 파일**: `useCharacterSettings.ts` (swap 로직) · `BasicTab.tsx` (`<select>`) · `App.tsx` (props)

**[BLOCKER]**: `setLinkedVrm` 호출 시 webview re-mount 여부 worker가 먼저 확인. Re-mount 시 persona/transform을 `preferences`에 먼저 쓰는 방식으로 변경.

**DoD**: 드롭다운 렌더링 · VRM 교체 · Persona/transform 보존 · Vitest unit test · `/agent-browser` visual verification. [target: desktop-homunculus/]

---

## Completed

Spec 1~5 (Phase 20 완료) → [docs/archive/todo-2026-04.md](./archive/todo-2026-04.md)

Spec 6 (Phase 21 완료, 2026-04-03) — 워크플로우 문서 모순 해소. PR #5 (docs/p21-twf → master) 머지 완료.

Spec 7 (Phase 23 완료, 2026-04-04) — Mascot Reaction System. BE PR #11 (TTS speak endpoint) + DH PR #9 (ReactionController) 머지 완료.

Spec 8 (Phase 23 완료, 2026-04-04) — VRM Position Adjustment UI. DH PR #8 (Position X/Y sliders) 머지 완료.
