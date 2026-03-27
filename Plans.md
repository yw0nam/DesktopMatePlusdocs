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

<!-- cc:TODO format: [ ] task description [target: repo] -->

### Phase 1: 아키텍처 강제 (Architecture Enforcement)

- [x] **Backend 커스텀 린터 / 구조적 테스트** — `tests/structural/test_architecture.py` (9 tests: import layering, file size, conventions), ruff 규칙 추가 (UP/SIM/RUF/A/TID), `scripts/lint.sh` 통합 (2026-03-27)

<!-- cc:TODO -->
- [ ] **NanoClaw 구조적 테스트 설계** — Channel self-registration 패턴, skill-as-branch 규칙 위반 감지. [target: nanoclaw/]

### Phase 2: 관측 가능성 레이어 (Observability)

<!-- cc:TODO -->
- [ ] **Developer/Reviewer Agent용 worktree별 앱 실행 환경** — harness.txt 원칙: 에이전트가 앱을 직접 실행하고 로그/메트릭으로 검증. Backend worktree별 독립 실행 스크립트 + 로그 쿼리 인터페이스 설계. [target: backend/, scripts/]

### Phase 3: 엔트로피 제어 (Drift GC)

<!-- cc:TODO -->
- [ ] **Background gardening agent 설계** — harness.txt 원칙: 드리프트를 주기적으로 청소하는 백그라운드 에이전트. "황금 원칙" 위반 감지 → 자동 리팩터링 PR. Reviewer와 별도 역할. [target: workspace scripts/harness/]

## Completed

## Delegation Log
