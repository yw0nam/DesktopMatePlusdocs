# Architecture Overview

**Overall Health: 🟡 (일부 우려됨)**

NanoClaw를 순수 태스크 실행기로 격하하고 FastAPI가 채널 라우팅을 담당하게 한 결정은 역할 분리 측면에서 매우 훌륭합니다. 하지만, 아직 오지도 않은 미래(Discord)를 대비한 과도한 추상화와, 메모리 누수가 확정적인 세션 관리 방식이 아키텍처를 오염시키고 있습니다. 단순하게 갈 수 있는 길을 스스로 복잡하게 만들고 있습니다.

---

## Step 1 Findings — Questionable Requirements

* **[MINOR] 단일 사용자(LTM "default")와 다중 채널(STM)의 불일치:** * **Why:** LTM은 `"default"`로 하드코딩하여 단일 사용자로 취급하지만, STM의 키는 `slack:{team_id}:{channel_id}:{user_id}`로 다중 사용자를 상정하고 있습니다. 개인용 봇이라도 슬랙 워크스페이스에 다른 사람이 말을 걸면 STM은 분리되지만 LTM은 섞이게 됩니다.
  * **Action:** 정말 혼자만 쓰는 봇이라면 STM 키에서 `user_id`를 빼거나, 다른 사람의 멘션을 무시하는 인가(Authorization) 로직이 제일 먼저(방어선으로) 필요합니다.

## Step 2 Findings — Candidates for Deletion

이 스펙서에서 가장 시급하게 삭제해야 할 부분들입니다. 코드가 줄어들수록 시스템은 건강해집니다.

* **[CRITICAL] Discord 관련 모든 설계 및 `ChannelAdapter` 추상화 팩토리:**
  * **Why:** "Discord는 P2로 미루지만 Abstract Interface만 설계한다"는 전형적인 YAGNI(You Aren't Gonna Need It) 위반입니다. 구현체가 단 하나(Slack)뿐인데 `base.py`, `ChannelAdapter` ABC, `get_channel_sender()` 팩토리를 만드는 것은 불필요한 레이어 낭비입니다.
  * **Action:** 5.1장의 추상화 구조를 전면 삭제하십시오. 그냥 `SlackService` 클래스 하나만 만드십시오. 나중에 Discord가 정말 필요해질 때 리팩토링(Extract Interface)해도 늦지 않습니다.
* **[IMPORTANT] Discord 3초 응답 제한 관련 로직:**
  * **Why:** 당장 구현하지도 않을 Discord의 제약 사항 때문에 아키텍처 문서의 흐름이 불필요하게 복잡해졌습니다.
  * **Action:** 문서에서 관련 내용을 모두 삭제하십시오. P2 문서를 따로 파서 옮기십시오.

## Step 3 Findings — Simplification Opportunities

* **[CRITICAL] `session_lock`의 메모리 누수 방치:**
  * **Why:** `collections.defaultdict(asyncio.Lock)`을 사용하고 "명시적 정리 불필요"라고 적었습니다. 슬랙 스레드나 채널이 생성될 때마다 새로운 `session_id`가 생기는데, 이 락 객체들은 프로세스가 죽을 때까지 메모리에 쌓입니다. 치명적인 결함입니다.
  * **Action:** `cachetools.TTLCache` 등을 사용하여 일정 시간(예: 10분) 동안 접근이 없는 Lock은 메모리에서 자동 해제되도록 단순한 TTL(Time-To-Live) 로직을 추가하십시오.
* **[IMPORTANT] 비대한 Webhook 핸들러 로직 (Controller 로직 비대화):**
  * **Why:** 7장의 메시지 처리 흐름을 보면, 라우트 핸들러가 STM 세션 생성, 메타데이터 업데이트, 컨텍스트 로드, 에이전트 실행, 메모리 저장을 모두 절차적으로 지시하고 있습니다. Unity WebSocket 쪽 로직과 중복이 발생할 확률이 높습니다.
  * **Action:** `AgentService` 또는 `Orchestrator` 내부에 채널과 무관하게 동작하는 `process_message(text, session_id, reply_channel_meta)` 단일 진입점을 만드십시오. Webhook 라우트는 파싱만 하고 이 진입점만 호출해야 합니다.

## Step 4 Findings — Cycle Time Blockers

* **[IMPORTANT] HTTP Webhook 도입으로 인한 로컬 개발 피드백 루프 저하:**
  * **Why:** 문서 4장에서 Webhook을 채택하며 ngrok을 필수화했습니다. ngrok URL이 바뀔 때마다 Slack 개발자 콘솔에 가서 Endpoint URL을 업데이트해야 하므로 로컬 테스트 속도가 극도로 느려집니다.
  * **Action:** 프로덕션은 Webhook이 맞지만, 로컬 개발 환경(`debug=True`)에서는 환경 변수 하나로 **Slack Socket Mode**를 켤 수 있게 지원해야 합니다. 그렇지 않으면 로컬에서 작은 수정 사항을 테스트할 때마다 개발자가 고통받습니다.

## Step 5 Findings — Automation Assessment

* **[MINOR] E2E 테스트 자동화의 부재:**
  * **Why:** 11장 Phase 7에 "E2E 테스트 (실제 Slack 워크스페이스 + ngrok)"라고 수동 테스트만 명시되어 있습니다.
  * **Action:** 콜백 루프(FastAPI -> NanoClaw -> FastAPI -> Slack)는 수동으로 검증하기 번거롭습니다. `pytest`를 이용해 가짜 Slack Payload를 POST로 쏘고, NanoClaw를 모킹하여 Callback을 트리거하는 통합 테스트 스크립트 작성이 필수적입니다.

---

## ⚡ Priority Actions (가장 시급한 수정 사항)

1. **추상화 폐기:** `ChannelAdapter`, `get_channel_sender` 등 채널 팩토리 패턴을 완전히 삭제하고, 오직 Slack 구조체만 남기십시오.
2. **메모리 릭 방지:** `session_lock` 딕셔너리에 TTL 기반의 만료 메커니즘을 반드시 추가하십시오.
3. **라우터 다이어트:** Webhook 라우터에 하드코딩된 메모리/세션 로직을 `AgentService` 계층으로 밀어 넣으십시오.

---

## 📝 스펙서 분리(Splitting)에 대한 피드백

NanoClaw와 FastAPI의 변경 범위가 명확히 다르므로, 문서를 3개로 나누는 것을 권장합니다. 섞여 있으면 각 컴포넌트 담당자(혹은 미래의 당신)가 컨텍스트 스위칭으로 피로해집니다.

**문서 1: 시스템 통합 및 통신 스펙 (Architecture & Protocol)**

* **목적:** 전체 시스템의 큰 그림과 컴포넌트 간의 통신 규약 정의.
* **내용:** 전체 아키텍처 다이어그램, 통신 시퀀스 (Slack -> FastAPI -> NanoClaw -> FastAPI -> Slack), Callback API 엔드포인트 규약(`POST /v1/callback/nanoclaw/{session_id}` Request/Response 바디 포맷).

**문서 2: FastAPI 채널 허브 스펙 (FastAPI Gateway Design)**

* **목적:** 외부 채널 수신, 에이전트 구동, 상태 관리.
* **내용:** Slack Webhook 파싱, `session_lock` 구현(TTL 포함), STM 메타데이터(`reply_channel`) 주입 로직, `AgentService.ainvoke()` 추가 사항, Background Sweep 에러 핸들링.

**문서 3: NanoClaw 경량화 스펙 (NanoClaw Pure Executor Design)**

* **목적:** NanoClaw에서 불필요한 기능을 도려내고 태스크 실행에만 집중하는 구조.
* **내용:** 기존 채널(Hub) 역할 코드 삭제, `DelegateTaskTool` 수신 후 HTTP Callback으로 결과만 쏘는 로직, 상태 저장소(DB) 의존성 제거.
