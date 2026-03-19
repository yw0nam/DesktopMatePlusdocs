# Architecture Overview

FastAPI를 중앙 허브로 삼아 Slack과 Discord의 연결을 관리하고, NanoClaw를 순수 작업 실행기로 격하하려는 의도의 아키텍처입니다. 의도는 좋으나, HTTP API 서버인 FastAPI에 상태 기반의 데몬 프로세스(Socket Mode)를 억지로 끼워 넣으려는 아키텍처적 불일치(Impedance Mismatch)가 발생하고 있습니다.

**Overall Health:** 🔴 (Significant issues)

---

## Step 1 Findings — Questionable Requirements

* **[CRITICAL] FastAPI 내부의 Socket Mode / WebSocket 데몬 구동**
  * **문제:** FastAPI `lifespan` 안에서 `while True`로 Slack Socket Mode와 Discord WS를 띄우는 것은 프레임워크의 설계 사상을 정면으로 위반합니다. FastAPI는 요청-응답(Request-Response) 주기를 처리하는 stateless HTTP 서버입니다.
  * **이유:** Gunicorn/Uvicorn이 워커(worker)를 4개 띄우면 봇 연결도 4개가 생성됩니다. 이는 즉각적인 충돌과 Rate Limit 초과를 유발합니다.
  * **해결:** 데몬 방식의 연결(Socket Mode)을 버리십시오. 대신 **HTTP Webhook 기반(Slack Events API, Discord HTTP Interactions)**으로 전환해야 합니다. Webhook을 사용하면 `lifespan` 백그라운드 태스크가 완전히 삭제되며, 순수 REST API 라우트로 깔끔하게 처리할 수 있습니다.
* **[IMPORTANT] NanoClaw 채널 스킬 생태계와의 충돌**
  * **문제:** NanoClaw에는 이미 `add-slack`, `add-discord` 등 검증된 채널 스킬 메커니즘이 존재합니다. 이를 무시하고 FastAPI에 동일한 책임을 재구현하는 것은 중복 투자입니다.
  * **이유:** "NanoClaw는 순수 태스크 실행기로 둔다"는 원칙 하나를 지키기 위해, FastAPI가 무거운 외부 I/O와 메시징 프로토콜을 모두 떠안게 됩니다.
User Feedback -> 이 문제는 이미 토의했어. 스킵해도 되지않을까?

## Step 2 Findings — Candidates for Deletion

* **[CRITICAL] `UserRegistryService` 및 MongoDB `user_registry` 컬렉션**
  * **문제:** 외부 ID를 굳이 내부 UUID로 매핑하기 위해 별도의 DB 컬렉션과 서비스를 만드는 것은 오버엔지니어링입니다.
  * **이유:** `provider`와 `provider_user_id`의 조합 자체가 이미 전역적으로 고유(Unique)합니다.
  * **삭제 권장:** 해당 컬렉션을 삭제하고, `registered_user_id` 대신 `slack:T123:U789` 형태의 URN 문자열을 LTM의 파티션 키로 직접 사용하십시오. 시스템이 훨씬 단순해집니다.
* **[IMPORTANT] `ChannelSenderRegistry` 클래스**
  * **문제:** 문자열로 객체를 런타임에 조회하는 레지스트리 패턴은 코드 추적을 어렵게 만듭니다.
  * **삭제 권장:** 파이썬의 표준 의존성 주입(Dependency Injection)이나, 단순한 팩토리 함수로 교체하십시오.

## Step 3 Findings — Simplification Opportunities

* **[IMPORTANT] `process_message()`의 추상화 누수 (Leaky Abstraction)**
  * **문제:** 코어 비즈니스 로직인 `process_message`가 `on_token`, `on_tts_chunk` 같은 콜백 함수를 인자로 받는 것은, 코어 로직이 출력 방식(Streaming vs Batch)을 알아야 한다는 뜻입니다.
  * **개선:** `process_message`는 Python의 `AsyncGenerator`를 반환하도록 리팩터링하십시오. WebSocket 라우터는 이 제너레이터를 순회하며 청크를 전송하고, Slack/Discord 어댑터는 제너레이터를 끝까지 소비(Consume)한 뒤 완성된 텍스트만 한 번에 전송하면 됩니다.
* **[MINOR] 상태 메시지 (Thinking / Status) 발송 로직**
  * **문제:** 비즈니스 로직 앞뒤로 `send_message("⏳ 생각 중...")`을 하드코딩하는 것은 우아하지 않습니다.
  * **개선:** 어댑터 레이어에서 메시지 수신 즉시 해당 플랫폼의 네이티브 '타이핑 인디케이터(Typing Indicator)' API를 호출하는 방식으로 단순화하십시오.

User Feedback -> 이거 굳이 process_message를 쓰지말고 invoke 메소드를 하나 추가한다음에 사용하는게 어떄? 굳이 streaming chunk로 받을 필요없이 Full text만 받으면되는 상황이잖아. backend/langchain_create_agent_docs 도큐먼트 참고해봐

## Step 4 Findings — Cycle Time Blockers

* **[CRITICAL] 핫 리로드(Hot Reload) 지옥**
  * **문제:** 현재 `lifespan` 설계대로라면, 코드를 수정하고 저장하여 `uvicorn --reload`가 트리거될 때마다 Slack과 Discord 봇이 연결을 강제로 끊고 재시작합니다.
  * **이유:** 개발 사이클 내내 Rate Limit 에러와 봇 오프라인 현상에 시달리게 될 것입니다. Step 1에서 제안한 **Webhook 방식**으로 전환하면 이 문제가 완벽히 소멸합니다.

## Step 5 Findings — Automation Assessment

* **[IMPORTANT] 외부 API 의존성으로 인한 테스트 난이도 증가**
  * 소켓 기반 연결을 유지하면 CI/CD 파이프라인에서 통합 테스트(E2E)를 자동화할 때 실제 WebSocket 서버를 모킹해야 하는 엄청난 수고가 발생합니다. HTTP Webhook 방식이라면 단순한 JSON `POST` 요청만으로 채널 이벤트를 100% 자동화 테스트할 수 있습니다.

---

## Priority Actions (토키의 최종 권고)

선생님, 다음 세 가지를 최우선으로 수정하여 스펙을 다시 작성하시는 것을 권장합니다.

1. **[구조 전환] Socket Mode 폐기 및 Webhook 도입:**
   FastAPI의 특성에 맞춰 Slack과 Discord 연동을 WebSocket 데몬 방식에서 **HTTP Webhook 기반 라우트**로 전면 수정하십시오. `lifespan`의 복잡한 재연결 로직을 모두 지울 수 있습니다.
2. **[복잡성 제거] `UserRegistry` 제거:**
   별도의 DB 매핑 테이블을 만들지 마시고, `slack:{user_id}` 형태의 합성 문자열을 LTM의 식별자로 바로 사용하십시오.
3. **[인터페이스 정제] `process_message` 제너레이터화:**
   콜백 함수(`on_token`)를 넘기는 방식을 버리고, `AsyncGenerator`를 반환하도록 하여 코어 로직과 채널 어댑터의 결합도를 낮추십시오.

이부분은 내가 아까언급한 invoke method를 고려해봐.
