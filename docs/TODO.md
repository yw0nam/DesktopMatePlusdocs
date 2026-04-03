# DesktopMatePlus — Feature TODO

PM agent가 office-hours 상담 후 작성. Lead가 Plans.md로 가져가 태스크화한다.

---

## Active TODO

| # | Feature | Priority | Status | Spec |
|---|---------|----------|--------|------|
| 1 | reviewer.md B+ Evaluator 패턴 | P1 | TODO | [spec](#spec-1-reviewermd-b-evaluator-패턴) |
| 2 | docs/TODO.md 전환 + CLAUDE.md 업데이트 | P1 | TODO | [spec](#spec-2-docstodomd-전환) |
| 3 | Background Quality Agent + garden.sh 개선 | P2 | TODO | [spec](#spec-3-background-quality-agent--gardensh-개선) |
| 4 | GOLDEN_PRINCIPLES.md 일관성 수정 | P2 | TODO | [spec](#spec-4-golden_principlesmd-일관성-수정) |
| 5 | cq 제거 → docs/faq 문서화 규칙 대체 | P1 | TODO | [spec](#spec-5-cq-제거--docsfaq-문서화-규칙-대체) |

---

## Specs

### Spec 1: reviewer.md B+ Evaluator 패턴

**출처**: Phase 20 office-hours (2026-04-03). Anthropic harness review 문서 기반.

**문제**: 현재 reviewer.md는 `/review` → `/cso` → pass/fail 단순 구조. 평가 기준 없음 → 관대한 평가 경향.

**결정 (B+)**:
- 4가지 채점 기준 추가: correctness, security, maintainability, test coverage
- 기준별 0-3 점수 + 임계값(2/3) 미달 시 자동 FAIL
- "관대하게 평가하지 말 것" 명시적 지시 추가
- Playwright QA (`/qa`): browser-testable 변경 시 조건부 자동 실행
- Sprint contract 협상은 Phase 21로 별도 트래킹

**DoD**:
- `.claude/agents/reviewer.md`에 4기준 체크리스트 + 임계값 FAIL 로직 반영
- `/qa` 조건부 실행 조건 명시 (browser-testable 변경 감지 기준 포함)

---

### Spec 2: docs/TODO.md 전환

**출처**: Phase 20 office-hours (2026-04-03).

**문제**: `docs/superpowers/INDEX.md`는 PRD 추적 목적이었으나 모든 항목 DONE 상태. 새 스펙 추가 흐름 부재.

**결정**:
- `docs/superpowers/` — 방치 (legacy, CLAUDE.md 링크만 제거)
- `docs/TODO.md` 신설 — PM agent가 office-hours 완료 후 Priority 테이블 형식으로 스펙 작성
- Lead가 `docs/TODO.md`에서 읽어 `Plans.md`에 태스크화하는 흐름
- `CLAUDE.md` PRD Tracking 섹션: superpowers 언급 제거 → docs/TODO.md로 교체

**TODO.md 형식**:
```
| # | Feature | Priority | Status | Spec |
|---|---------|----------|--------|------|
| 1 | feature name | P0/P1/P2 | TODO/DONE | [spec](#anchor) |
```
각 spec은 같은 파일 내 H3 섹션으로 작성.

**DoD**:
- `docs/TODO.md` 파일 존재 (이 파일 자체가 DoD 증거)
- `CLAUDE.md` PRD Tracking 섹션이 docs/TODO.md를 가리킴
- `docs/CLAUDE.md`의 superpowers 링크 → TODO.md로 교체

---

### Spec 3: Background Quality Agent + garden.sh 개선

**출처**: Phase 20 office-hours (2026-04-03, 2026-04-03 보강). OpenAI/Anthropic harness review 문서 기반.

**문제**:
- `scripts/garden.sh`와 `scripts/check_docs.sh`가 있지만 수동 실행. 주기적 품질 모니터링 없음.
- QUALITY_SCORE.md가 추상적: nanoclaw/DH가 A등급이지만 garden.sh는 DH를 체크하지 않음. 위반 내역 없음.
- garden.sh 출력이 [PASS]/[FAIL]만 찍고 위반 위치(파일:라인) 없음. DH repo 미체크.
- 리포트 경로 불일치: `docs/garden-reports/` vs 스펙 기준 `docs/reports/`.

**결정**:
- `.claude/agents/quality-agent.md` 신설
- `/schedule` cron으로 주기 실행 (기본: 일 1회)
- 위반 발견 시 리포트만 생성 (`docs/reports/quality-YYYY-MM-DD.md`) → Lead/유저가 수동 판단
- auto-fix PR 생성은 하지 않음 (리스크 제어)

**garden.sh 개선 사항**:
- 위반 위치 출력: garden.sh가 직접 수행하는 체크(GP-3 console.log, GP-7 wc -l 등)에 한해 `[파일:라인]` 형식 추가
- DH MOD(TS) 체크 추가: `desktop-homunculus/mods/` 하위 console.log 감지 + 파일크기 ≤ 400줄 체크
  - DH Rust 코드는 UNCHECKED (cargo 의존성 추가 불필요 원칙)
  - DH-PROBE-1(standalone 실행 가능성)과 무관하게 파일 스캔만 수행
- 리포트 경로 통일: `docs/garden-reports/` → `docs/reports/`

**QUALITY_SCORE.md 형식 개선**:
- 미검증 repo는 "UNCHECKED" 표시 (DH Rust=UNCHECKED, DH MOD=실제 garden.sh 결과)
- `## Violations Summary` 섹션 추가. 최소 형식:
  ```
  ## Violations Summary
  - GP-3 (backend): 0 violations
  - GP-3 (nanoclaw): 2 violations (nanoclaw/src/foo.ts:10, src/bar.ts:42)
  - DH MOD console.log: 0 violations
  - DH MOD file size: UNCHECKED (Rust)
  ```
- 자동 갱신 시 UNCHECKED 마커가 있는 셀은 갱신 대상에서 제외 (덮어쓰기 금지)

**체크 항목**:
1. `scripts/garden.sh` 실행 → GP-1~12 drift 감지 + DH MOD 체크
2. `scripts/check_docs.sh` 실행 → dead link, 200줄 초과 문서 감지
3. `Plans.md` cc:TODO 진체 감지 → 2주 이상 TODO 상태인 태스크 목록
4. `scripts/garden.sh --metrics` → `docs/QUALITY_SCORE.md` grade matrix 갱신

**리포트 형식** (`docs/reports/quality-YYYY-MM-DD.md`):
```markdown
# Quality Report — YYYY-MM-DD
## GP Drift
## Dead Links / Oversized Docs
## Stale TODO (2w+)
## Quality Score Update
## Violations Summary
```

**DoD**:
- `.claude/agents/quality-agent.md` 파일 존재 + lifecycle/checklist/report 형식 명시
- `docs/reports/` 디렉토리 존재 (`.gitkeep` 포함)
- `/schedule` cron 등록 예시 포함 (agent 정의 내 주석)
- `scripts/garden.sh`에 DH MOD 체크 추가 + 위반 위치 출력 + 리포트 경로 `docs/reports/`로 통일
- `docs/QUALITY_SCORE.md`에 UNCHECKED 표시 + `## Violations Summary` 섹션 존재

---

### Spec 4: GOLDEN_PRINCIPLES.md 일관성 수정

**출처**: Phase 20 office-hours 보강 (2026-04-03). docs/TODO.md 전환 후 GP 불일치 발견.

**문제**:
- GP-11, GP-12: `docs/superpowers/` 기반 아카이브 규칙 → TODO.md 전환 후 무의미
- GP-9: `feat/claude_harness` outdated 브랜치 참조
- DH에 대한 GP 없음 (MOD TS 코드 품질 기준 부재)

**결정**:
- GP-11 수정: superpowers/specs/ → docs/TODO.md 기반 아카이브 규칙으로 업데이트
- GP-12 수정: superpowers/completed/plans/ → docs/ 기반으로 업데이트
- GP-9 수정: `feat/claude_harness` → `develop` 브랜치 참조로 교체
- DH GP 추가 (GP-13 신설 또는 GP-2 확장): `desktop-homunculus/mods/` TS 코드 console.log 금지 + 파일크기 ≤ 400줄
- **주의**: GOLDEN_PRINCIPLES.md CONTRIBUTING 규칙상 PR 생성 + human approval 필수 — 직접 커밋 금지
- garden.sh archive freshness 감지 로직 업데이트는 WS-GP-1 완료 후 Phase 21+에서 판단

**DoD**:
- GP-9/11/12 텍스트가 현행 워크플로우와 일치
- DH MOD GP 항목 존재 (console.log 금지 + 파일크기 ≤ 400줄 명시)
- 변경 내용이 PR로 제출되어 human approval 후 머지됨

---

### Spec 5: cq 제거 → docs/faq 문서화 규칙 대체

**출처**: Phase 20 office-hours (2026-04-03). cq 실효성 검토 결과.

**문제**:
- cq MCP 도구(propose/query/confirm)를 에이전트에 강제했으나 local DB 0건, team API 0건
- 환경변수 설정 오류(CQ_TEAM_ADDR → CQ_ADDR)도 있었지만, 근본적으로 1인 유저 + AI 에이전트 구조에서 cq는 오버헤드만 추가
- `.claude/rules/`, `docs/faq/`, memory 시스템이 이미 더 효과적인 지식 공유 수단

**결정**:
- safety-guardrails.md R00-CQ 규칙 제거
- worker.md, reviewer.md, quality-agent.md에서 cq.query()/cq.propose() 스텝 제거
- CLAUDE.md "cq Knowledge Sharing" 섹션 제거
- 대체 규칙: "비자명한 학습은 docs/faq/에 문서화" (기존 CLAUDE.md FAQ 작성 규칙 활용)
- settings.json에서 cq 관련 env/allowedTools는 남겨둠 (플러그인 자체는 제거 안 함, 필요 시 수동 사용 가능)

**DoD**:
- R00-CQ 규칙 삭제
- agent .md 파일에서 cq 스텝 제거
- CLAUDE.md cq 섹션 제거
- docs/faq/ 문서화 규칙이 유일한 지식 공유 채널로 명시

---

## Completed

(완료된 스펙은 아래로 이동)
