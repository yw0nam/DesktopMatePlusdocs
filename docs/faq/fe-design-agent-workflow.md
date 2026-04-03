# FE Design Agent Workflow

## 언제 design-agent를 스폰하는가?

Lead는 아래 조건을 모두 충족할 때만 design-agent를 스폰한다:

1. PM spec에 `[target: desktop-homunculus/]` 태스크가 하나 이상 존재
2. 해당 태스크에 가시적 UI 변경이 포함됨 (새 컴포넌트, 레이아웃 변경, 인터랙션 설계)
3. spec에 기존 mockup 참조가 없음

**스폰하지 않는 경우:**

- `desktop-homunculus/` 변경이 백엔드 로직만 포함 (signal 배선만 변경, 시각적 출력 없음)
- Bevy side (`src/`) 변경 전용 (Rust 코드, ECS 시스템)
- 기존 mockup이 이미 spec에 첨부된 경우

## E2E Scaffold vs Unit Test 경계

| 항목 | E2E Scaffold | Unit Test |
|------|-------------|-----------|
| 담당 | design-agent | worker |
| 위치 | `design/{feature}/{feature}.test.ts` | `mods/*/src/__tests__/` |
| 내용 | signal setup + describe/it 구조 + 시나리오 주석 | 실제 assertion 구현 |
| 런타임 | CEF + Bevy 필요 (로컬 전용) | jsdom / vitest 단독 실행 |
| CI 포함 | 금지 | 포함 가능 |

**E2E scaffold에는 assertion 코드가 없다.** `it` 블록 안에 `// TODO: implement assertion` 주석만 존재한다. Worker가 실제 assertion을 채운다.

### E2E scaffold 예시

```typescript
// E2E: requires CEF + Bevy runtime — local execution only, excluded from CI
import { signal } from '@preact/signals';
import { describe, it } from 'vitest';

describe('ScreenCapture', () => {
  describe('toggle behavior', () => {
    it('should enable capture mode when toggled on', () => {
      // Scenario: user clicks capture toggle
      // Given: capture mode is OFF
      // When: toggle is clicked
      // Then: capture mode signal becomes true, UI shows active state
      // TODO: implement assertion
    });

    it('should disable capture mode when toggled off', () => {
      // Scenario: user disables capture
      // Given: capture mode is ON
      // When: toggle is clicked again
      // Then: capture mode signal becomes false
      // TODO: implement assertion
    });
  });
});
```

## design/{feature} PR 흐름

### 1. design-agent 작업

```
design-agent 스폰
  → /design-consultation  (제품 컨텍스트 파악)
  → /design-shotgun       (여러 variant 생성 + 비교 보드)
  → 사용자 variant 선택
  → /design-html          (선택 variant → 프로덕션 HTML mockup)
  → component spec 작성   (props, signals, 상태 머신, 인수 조건)
  → E2E scaffold 작성     (signal setup + describe/it + 시나리오 주석)
  → /design-review        (HTML mockup 시각적 감사)
  → PR 생성: design/{feature} → develop
```

### 2. PR 브랜치 구조

```
develop
  └── design/{feature}     ← design-agent PR (mockup + spec + scaffold)
        └── feat/{feature} ← worker가 여기서 구현 (design/{feature} base)
```

Worker는 `design/{feature}`를 base branch로 삼아 구현한다. design-agent PR이 merge되기 전이라도 동일 브랜치에서 작업 가능하다.

**브랜치 인계 흐름**: design-agent가 `design/{feature}` 브랜치를 생성하면, worker는 `DESIGN_READY` 신호를 받아 동일 브랜치를 base로 `feat/p{N}-t{id}` 브랜치를 분기한다. 두 PR이 순차 merge된 후 `develop`에 반영된다.

브랜치 prefix 컨벤션 전체: [Worktree Rules](../../CLAUDE.md#worktree-rules)

### 3. 3개 artifacts 체크리스트

design-agent PR에 반드시 포함되어야 하는 파일:

- [ ] `design/{feature}/mockup.html` — 독립 실행 HTML, Glassmorphism 스타일
- [ ] `design/{feature}/spec.md` — props, signals, 상태 머신, 인수 조건
- [ ] `design/{feature}/{feature}.test.ts` — E2E scaffold (assertion 없음)

3개 중 하나라도 빠지면 design-agent는 `DESIGN_READY`를 보낼 수 없다.

## 왜 design-agent를 별도 에이전트로 분리했는가?

Worker는 TDD 구현 전문이다. HTML mockup 생성 + 디자인 심사는 gstack의 `/design-*` 스킬 체인이 필요하고, 이 컨텍스트가 구현 작업과 섞이면 두 작업 모두 품질이 저하된다.

분리함으로써:
- Lead 컨텍스트 오염 방지 (pm-agent 분리 이유와 동일)
- Worker는 mockup과 spec을 참조만 하고 구현에 집중
- `/design-review` 피드백 루프가 구현 작업과 독립적으로 반복 가능

## 관련 문서

- [Desktop Homunculus MOD 시스템](./desktop-homunculus-mod-system.md): Glassmorphism UI 가이드라인, signals 통신 패턴
- [design-agent.md](../../.claude/agents/design-agent.md): 에이전트 전체 정의 (lifecycle, guardrails, output spec)
