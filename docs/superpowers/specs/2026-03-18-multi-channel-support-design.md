# Multi-Channel Support Design

**Date**: 2026-03-18 (rev.5)
**Status**: Draft
**Scope**: FastAPI에 Slack 외부 채널 어댑터 추가, NanoClaw는 순수 태스크 실행기로 유지

---

## 1. 목표

Unity(WebSocket) 외에 Slack 등 외부 채널에서도 Yuri 에이전트를 호출할 수 있도록 한다.

- 외부 채널에서 Yuri에게 멘션/메시지 → Yuri가 페르소나 기반으로 응답
- 태스크는 기존과 동일하게 NanoClaw 컨테이너에서 실행
- 외부 채널에서는 TTS 비활성화
- LTM은 모든 채널 공유 (단일 사용자 개인 프로그램)
- STM은 채널별 독립 세션

---

## 2. 아키텍처

```
FastAPI
├── WebSocket (Unity)                      ← 기존 변경 없음
└── POST /v1/channels/slack/events         ← 신규 (Slack Events API webhook)
         ↓
      process_message(text, session_id, provider, channel_id)
         ↓ (태스크 위임 시만)
      NanoClaw (순수 태스크 실행기)
         ↓ (완료 콜백)
      FastAPI callback.py → process_message 재실행 → SlackService 응답
```

**NanoClaw 역할 변화**: 채널 허브 역할 없음. 오직 `DelegateTaskTool`로 위임된 태스크만 실행.

---

## 3. 메모리 전략

```python
# 단일 사용자 개인 프로그램 — user_id 하드코딩
LTM_USER_ID = "default"  # TODO: multi-user support requires auth system
STM_USER_ID = "default"  # TODO: multi-user support requires auth system
```

| 구분 | 키 | 설명 |
|------|----|------|
| STM | `slack:{team_id}:{channel_id}:{STM_USER_ID}` | 대화별 독립 컨텍스트 |
| LTM | `LTM_USER_ID` | 전 채널 공유 |

LTM과 STM 모두 user_id를 상수로 고정한다. 함수 시그니처의 `user_id` 인자는 그대로 유지하여 나중에 multi-user 전환 시 상수만 교체하면 된다.

모든 채널(Unity, Slack)이 동일한 LTM을 공유하여 Yuri가 채널 무관하게 같은 장기 기억을 유지한다.

**STM 세션 메타데이터에 추가 저장**:

```json
{
  "user_id": "default",
  "agent_id": "yuri",
  "reply_channel": {
    "provider": "slack",
    "channel_id": "C456CHANNEL"
  }
}
```

콜백 수신 시 `reply_channel`을 조회해 SlackService로 응답을 라우팅한다.

---

## 4. 채널 수신 방식: HTTP Webhook

Socket Mode / WebSocket 데몬 방식을 사용하지 않는다. FastAPI는 stateless HTTP 서버이며, `lifespan` 안에서 `while True` 데몬을 구동하면 멀티 워커 환경에서 봇 연결이 중복 생성된다. 개발 시 `--reload`마다 재연결 문제도 발생한다.

**프로덕션: HTTP Webhook 기반**

| 채널 | 수신 방식 | FastAPI 라우트 |
|------|-----------|----------------|
| Slack | Slack Events API | `POST /v1/channels/slack/events` |

**로컬 개발: Slack Socket Mode 지원**

ngrok URL이 바뀔 때마다 Slack 콘솔에서 Endpoint URL을 수동 업데이트하는 번거로움을 피하기 위해, 로컬 개발 환경에서는 Slack Socket Mode를 사용할 수 있다.

```yaml
# backend/yaml_files/channel.yaml
slack:
  use_socket_mode: ${SLACK_USE_SOCKET_MODE:false}  # 로컬 개발 시 true
```

`SLACK_USE_SOCKET_MODE=true`이면 `lifespan`에서 `SocketModeHandler`를 별도로 구동한다. Webhook 라우트는 비활성화 또는 무시된다.

**Slack URL Verification**: Slack Events API 최초 등록 시 `{"type": "url_verification", "challenge": "..."}` 요청이 온다. 라우트에서 `challenge` 값을 그대로 반환해야 한다.

---

## 5. 새 컴포넌트

### 5.1 SlackService (FastAPI)

추상화 없이 Slack 전용 서비스 클래스 하나만 만든다. Discord 등 추가 채널이 실제로 필요해질 때 Extract Interface한다.

```
backend/src/services/
└── channel_service/
    ├── __init__.py       # SlackService 싱글톤 초기화 + process_message()
    ├── slack_service.py  # Slack Events API 검증 + 이벤트 파싱 + 메시지 전송
    └── session_lock.py   # TTL 기반 세션 락
```

**SlackService**:

```python
class SlackService:
    def __init__(self, settings: SlackSettings) -> None: ...

    async def parse_event(self, payload: dict) -> SlackMessage | None:
        """webhook payload에서 메시지를 추출. 무시할 이벤트(봇 메시지 등)는 None 반환."""
        ...

    async def send_message(self, channel_id: str, text: str) -> None:
        """Slack Web API로 메시지 전송."""
        ...
```

**SlackMessage**:

```python
@dataclass
class SlackMessage:
    session_id: str    # "slack:{team_id}:{channel_id}:{STM_USER_ID}"
    channel_id: str    # 응답을 보낼 채널 ID
    provider: str      # "slack"
    text: str
```

**싱글톤 초기화**:

```python
# channel_service/__init__.py
_slack_service: SlackService | None = None

def init_channel_service(settings: ChannelSettings) -> None:
    """main.py lifespan에서 호출."""
    global _slack_service
    if settings.slack_enabled:
        _slack_service = SlackService(settings.slack)

def get_slack_service() -> SlackService | None:
    return _slack_service
```

`callback.py`와 `BackgroundSweepService`는 `reply_channel["provider"] == "slack"` 분기로 SlackService를 직접 호출한다.

**`main.py` lifespan 등록**:

```python
from src.services.channel_service import init_channel_service
init_channel_service(settings.channel)
```

`channel_service`는 백그라운드 태스크 없이 설정만 초기화한다 — lifespan에 비동기 태스크를 추가하지 않는다 (Socket Mode 제외).

### 5.2 AgentService에 `ainvoke()` 추가

현재 `AgentService` ABC는 `stream()`만 선언한다. 외부 채널 경로를 위해 `ainvoke()`를 추가한다.

```python
# src/services/agent_service/service.py (AgentService ABC)
@abstractmethod
async def ainvoke(
    self,
    messages: list,
    session_id: str,
    persona_id: str = "yuri",
) -> str:
    """전체 응답을 한 번에 반환. 스트리밍 불필요한 채널(Slack)에서 사용."""
    ...
```

```python
# src/services/agent_service/openai_chat_agent.py (구현)
async def ainvoke(self, messages, session_id, persona_id="yuri") -> str:
    result = await self.agent.ainvoke(
        {"messages": messages},
        config={"configurable": {"session_id": session_id}},
    )
    return result["messages"][-1].content
```

**STM/LTM 저장 책임**: `AgentService`는 순수 추론 엔진이며 메모리를 직접 건드리지 않는다. 메모리 I/O는 `memory_orchestrator`가 전담한다:

- **컨텍스트 로드**: `await memory_orchestrator.load_context(stm, ltm, user_id, agent_id, session_id, query)`
- **저장**: `asyncio.create_task(memory_orchestrator.save_turn(new_chats, stm, ltm, user_id, agent_id, session_id))`

### 5.3 `process_message()` — 채널 공통 진입점

Webhook 라우터와 Callback 핸들러가 공유하는 단일 메시지 처리 진입점. Unity WebSocket 경로와의 중복을 방지하고 채널 무관 로직을 한곳에 집중한다.

```python
# channel_service/__init__.py
async def process_message(
    *,
    text: str,
    session_id: str,
    provider: str,
    channel_id: str,
    user_id: str = STM_USER_ID,   # 현재 하드코딩, 시그니처는 유지
    agent_id: str = "yuri",
    agent_service: AgentService,
    stm: STMService,
    ltm: LTMService,
    memory_orchestrator: MemoryOrchestrator,
) -> None:
    """
    외부 채널 메시지를 처리하고 응답을 전송한다.
    Webhook 라우트와 Callback 핸들러 양쪽에서 호출.
    """
    async with session_lock(session_id):
        # 1. STM 세션 upsert
        await stm.upsert_session(session_id, user_id=user_id, agent_id=agent_id)
        # 2. reply_channel 메타데이터 저장
        await stm.update_session_metadata(session_id, {
            "user_id": user_id, "agent_id": agent_id,
            "reply_channel": {"provider": provider, "channel_id": channel_id},
        })
        # 3. 컨텍스트 로드
        context = await memory_orchestrator.load_context(
            stm, ltm, user_id=user_id, agent_id=agent_id,
            session_id=session_id, query=text,
        )
        # 4. 에이전트 실행
        # text가 비어있으면 콜백 경로 — STM에 TaskResult가 이미 주입된 상태이므로
        # HumanMessage를 추가하지 않고 context만으로 ainvoke 호출.
        messages = context + [HumanMessage(text)] if text else context
        final_text = await agent_service.ainvoke(messages, session_id, persona_id=agent_id)
        # 5. STM/LTM 저장 (fire-and-forget)
        new_chats = ([HumanMessage(text)] if text else []) + [AIMessage(final_text)]
        asyncio.create_task(memory_orchestrator.save_turn(
            new_chats=new_chats,
            stm_service=stm, ltm_service=ltm,
            user_id=user_id, agent_id=agent_id, session_id=session_id,
        ))
        # 6. 응답 전송
        if provider == "slack":
            slack = get_slack_service()
            if slack:
                await slack.send_message(channel_id, final_text)
```

Webhook 라우트는 파싱 + `asyncio.create_task(process_message(...))` 호출만 한다.

### 5.4 `session_lock` 유틸리티 (TTL 기반)

```python
# src/services/channel_service/session_lock.py
import asyncio
from cachetools import TTLCache

_SESSION_TTL = 600  # 10분
_locks: TTLCache[str, asyncio.Lock] = TTLCache(maxsize=1024, ttl=_SESSION_TTL)

def session_lock(session_id: str) -> asyncio.Lock:
    if session_id not in _locks:
        _locks[session_id] = asyncio.Lock()
    return _locks[session_id]
```

10분 동안 접근이 없는 세션의 Lock은 자동 해제된다. `maxsize=1024`는 메모리 상한선.

---

## 6. 에이전트 실행 방식

### Unity (기존, 변경 없음)

`agent.stream()` → 토큰 스트리밍 → WebSocket → TTS

### 외부 채널 (신규)

`agent.ainvoke()` → full text 반환 → SlackService.send_message()

스트리밍이 불필요한 채널에서는 `ainvoke()`를 직접 호출한다.

---

## 7. 메시지 처리 흐름

### Case A: 단순 대화 (Slack)

```
Slack Events API → POST /v1/channels/slack/events
  ↓
서명 검증 (SLACK_SIGNING_SECRET)
  ↓
url_verification 요청이면 → challenge 반환 후 종료
  ↓
slack_service.parse_event(payload) → SlackMessage | None
None이면 → 200 OK 반환 후 종료 (봇 메시지, 무관한 이벤트 등)
  ↓
asyncio.create_task(process_message(
    text=msg.text, session_id=msg.session_id,
    provider="slack", channel_id=msg.channel_id,
    ...deps,
))
  ↓
200 OK 즉시 반환 (Slack은 응답을 기다리지 않음)
```

실제 처리(STM, ainvoke, 응답 전송)는 `process_message()` 내부에서 백그라운드 실행된다.

### Case B: 태스크 위임 포함

```
(Case A와 동일하게 process_message 진입까지)
  ↓
DelegateTaskTool 발동 → ainvoke 즉시 반환 ("팀에 작업을 지시했습니다.")
  ↓
await slack_service.send_message(channel_id, "알았어! 팀한테 맡겨볼게 👀")

--- (NanoClaw 작업 중...) ---

POST /v1/callback/nanoclaw/{session_id} 수신 (callback.py)
  ↓
STM에 synthetic TaskResult 메시지 주입 (기존 동작)
  ↓
STM 세션 메타데이터에서 reply_channel + user_id + agent_id 조회:
  metadata.get("reply_channel") → { provider: "slack", channel_id: "C456" }
  ↓
reply_channel이 None이면 → Unity WebSocket 세션, 기존 로직 유지 (skip)
  ↓
process_message(
    text="",  # synthetic message 포함된 history 반영
    session_id=session_id,
    provider=metadata["reply_channel"]["provider"],
    channel_id=metadata["reply_channel"]["channel_id"],
    ...deps,
)
```

**중간 상태 메시지**:

| 타이밍 | 예시 |
|--------|------|
| DelegateTaskTool 발동 후 | "알았어! 팀한테 맡겨볼게 👀" |
| 최종 응답 | Yuri 페르소나 기반 응답 |

---

## 8. 동시성 처리

동일 session_id로 메시지가 연속 수신될 경우 STM 오염 방지:

`process_message()` 내부에서 `async with session_lock(session_id)`로 전체 처리 흐름을 직렬화한다.

`BackgroundSweepService`의 `reply_channel` 읽기는 락 없이 수행한다 — 태스크 만료 시점에는 락이 이미 해제된 상태이므로 안전하다.

---

## 9. 에러 핸들링

| 상황 | 처리 |
|------|------|
| Webhook 서명 검증 실패 | `403` 즉시 반환 |
| Slack URL verification | `challenge` 값 그대로 반환 |
| `agent.ainvoke()` 실패 | `slack_service.send_message("처리 중 오류가 발생했어 😥 다시 시도해줘")` |
| DelegateTaskTool 타임아웃 | BackgroundSweepService → STM `reply_channel` 조회 → `slack_service.send_message(channel_id, "태스크가 시간 초과됐어 😥")` |
| `get_slack_service()` → None | 채널 비활성화. 로그 후 skip |
| STM 세션 없음 | `upsert_session()`으로 upsert 보장 (Phase 2 신규 메서드) |
| Slack API 전송 실패 | 로그만 기록, 재전송 없음 |

---

## 10. 환경 변수 (Pydantic Settings + YAML)

```yaml
# backend/yaml_files/channel.yaml
slack:
  enabled: true
  bot_token: ${SLACK_BOT_TOKEN}
  signing_secret: ${SLACK_SIGNING_SECRET}  # webhook 서명 검증용
  app_token: ${SLACK_APP_TOKEN}            # Socket Mode 전용 (로컬 개발)
  use_socket_mode: ${SLACK_USE_SOCKET_MODE:false}
```

```python
class SlackSettings(BaseSettings):
    enabled: bool = False
    bot_token: str = ""
    signing_secret: str = ""
    app_token: str = ""          # Socket Mode 전용
    use_socket_mode: bool = False

class ChannelSettings(BaseSettings):
    slack: SlackSettings = SlackSettings()
```

`enabled: false` 또는 필수 값 미설정 시 SlackService 초기화 skip.

---

## 11. 구현 순서 (Phase)

| Phase | 내용 |
|-------|------|
| 1 | `SlackService` (서명 검증 + URL verification + 이벤트 파싱 + 전송) + `init_channel_service()` + `main.py` 등록 |
| 2 | `session_lock` (TTLCache) + `STMService` ABC에 `upsert_session(session_id, user_id, agent_id)` 추가 + `MongoDBSTM` 구현 |
| 3 | `AgentService` ABC에 `ainvoke()` 추가 + `OpenAIChatAgent` 구현 |
| 4 | `process_message()` 공통 진입점 구현 + `POST /v1/channels/slack/events` 라우트 (Webhook + Socket Mode 분기) |
| 5 | `callback.py` 수정 — `reply_channel` 조회 + `process_message()` 호출. Unity 세션(`reply_channel` 없음)은 기존 로직 유지 |
| 6 | `BackgroundSweepService` 수정 — `__init__`에 `slack_service_fn: Callable[[], SlackService \| None]` 주입 + TaskFailed 시 SlackService로 에러 메시지 전송 |
| 7 | 통합 테스트: pytest로 가짜 Slack payload POST → NanoClaw 모킹 → Callback 트리거 검증 |

---

## 12. Out of Scope

- Multi-user auth system / UserRegistry — 개인 프로그램이므로 불필요 (`LTM_USER_ID`, `STM_USER_ID` = `"default"` TODO)
- Unity ↔ Slack 계정 링킹 — auth 시스템 생기면 그때
- Slack 스레드별 독립 세션 — 향후 P2
- Discord 채널 구현 — 향후 P2 (ChannelAdapter 추상화는 그때 Extract Interface)
- Discord slash command — 향후 P2
- Discord DM — 향후 P2
- NanoClaw `add-slack`, `add-discord` 스킬 — 이 설계에서 사용하지 않음
