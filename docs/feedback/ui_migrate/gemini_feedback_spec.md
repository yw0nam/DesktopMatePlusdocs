제공해주신 docs/superpowers/specs/2026-03-20-desktopmate-bridge-completion-design.md 스펙 문서와 현재 프로젝트의 실제 코드를 비교/리뷰한 결과, 다음과 같은 몇 가지
  피드백 및 보완할 점을 발견했습니다.

  1. package.json의 menus 구조 명확화
  스펙 문서의 2번 항목에서 menus 형식을 수정하는 예시가 menus 배열을 최상위(top-level) 프로퍼티처럼 보여주고 있습니다. 하지만 desktop-homunculus 모드들의 구조상,
  그리고 현재 package.json의 구조상 menus는 homunculus 객체 내부에 위치해야 합니다.
  구현 시 오해를 방지하기 위해 다음과 같이 감싸서 명시해 주는 것이 좋습니다.

   1 "homunculus": {
   2   "menus": [
   3     {
   4       "id": "open-desktopmate-chat",
   5       "text": "Chat",
   6       "command": "open-chat"
   7     }
   8   ]
   9 }

  2. service.ts 내 vrm 파라미터 전달 체인 누락
  스펙에서는 vrm 인스턴스를 동적으로 생성(spawnCharacter())하고, 이를 handleTtsChunk와 handleMessage에 전달하도록 변경한다고 명시되어 있습니다. 
  하지만 handleMessage를 호출하는 이벤트 리스너는 connectWithRetry 함수 내부에 등록되며, 재연결 로직은 handleClose 함수에 있습니다. 따라서 vrm 인스턴스는 아래 함수들로
  모두 Propagate(전달) 되어야 합니다. 이 부분이 스펙에 누락되어 있습니다.

   * connectAndServe(config, vrm) -> connectWithRetry(config, vrm, { attempts: 0 })
   * connectWithRetry 내부의 ws.addEventListener("message", ...) 에서 handleMessage(event, config, vrm) 호출
   * handleClose(event, config, vrm, retryState) -> 재연결 시 다시 connectWithRetry(config, vrm, ...) 호출

  3. service.ts Import 목록에서 기존 타입 누락
  스펙 문서의 4번 항목에서 전체 import 목록을 다음과 같이 안내하고 있습니다:
  > All service.ts imports: @hmcs/sdk — Vrm, TransformArgs, signals, sleep, repeat, preferences

  그러나 현재 service.ts의 handleTtsChunk 함수 시그니처에서 @hmcs/sdk의 TimelineKeyframe 타입을 사용하고 있습니다. 따라서 기존에 사용하던 type TimelineKeyframe이
  import 목록에 유지되도록 스펙에 포함되어야 타입 에러가 발생하지 않습니다.

  4. E2E 테스트(test:e2e) 실행 격리 방안 누락
  스펙의 7번 Test Strategy 항목을 보면 pnpm test 명령 시 E2E 테스트가 제외된다고 명시되어 있습니다.
  > E2E tests are excluded from default pnpm test run.

  현재 desktopmate-bridge/package.json의 test 스크립트는 단순히 "vitest run"으로 되어있고 별도의 vitest.config.ts 파일이 없습니다. 이 상태라면 tests/e2e 경로에 있는
  파일들도 vitest run 명령어에 의해 기본적으로 함께 실행되어 버립니다.
  E2E 테스트를 제외하기 위해 vitest.config.ts를 생성하여 `exclude: ['tests/e2e/']를 추가하거나, package.json의 test 스크립트를 명시적인 대상(예: "test": "vitest run
  ui/src"`)으로 수정하는 방법**이 스펙 문서에 추가되어야 합니다.

  ---
  위 4가지 사항을 스펙 문서에 반영하시면, 실제 코드로 구현할 때 발생할 수 있는 시행착오나 오류를 방지할 수 있을 것으로 보입니다. 스펙을 제가 직접 수정할까요?

  ---

  ## 2차 리뷰 (2026-03-20)
  
  수정된 스펙(`docs/superpowers/specs/2026-03-20-desktopmate-bridge-completion-design.md`)을 확인했습니다. 제가 제안해드린 4가지 피드백(1. menus 구조, 2. vrm 파라미터 체인, 3. TimelineKeyframe 임포트, 4. vitest.config.ts를 통한 E2E 테스트 격리)이 모두 정확하게 잘 반영되었습니다. 전반적으로 아주 훌륭한 스펙 문서가 되었습니다! (LGTM)

  **추가 코멘트 (사소한 팁):**
  * `vitest.config.ts`의 `exclude`에 `tests/e2e/**`를 추가하는 방법은 훌륭합니다. 다만 Vitest의 동작 특성상, `exclude`에 등록된 경로는 터미널에서 대상을 명시하더라도(`vitest run tests/e2e`) 실행이 무시되며 "No test files found" 오류가 날 수 있습니다.
  * 따라서 실제 구현 시점에 `pnpm test:e2e` 스크립트를 작성하실 때, 이 격리 설정을 우회하기 위해 `vitest.e2e.config.ts`처럼 E2E 전용 설정 파일을 하나 더 만들어서 지정(`vitest run -c vitest.e2e.config.ts`)하는 방식이 필요할 수도 있습니다. 이 부분은 실제 코드를 작성하시면서 유연하게 대처하시면 될 것 같습니다.

  현재 스펙 문서는 구현을 시작하기에 충분히 명확하고 완벽합니다. 바로 구현에 들어가셔도 좋습니다!