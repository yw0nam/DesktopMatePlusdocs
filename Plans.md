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

## Completed

<!-- Phases 19–20: archived to docs/archive/plans-2026-04.md on 2026-04-03 -->
