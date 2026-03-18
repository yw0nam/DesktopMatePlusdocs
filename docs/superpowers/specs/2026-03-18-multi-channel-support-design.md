# Multi-Channel Support Design

**Date**: 2026-03-18 (rev.3)
**Status**: Draft
**Scope**: FastAPI에 Slack/Discord 등 외부 채널 어댑터 추가, NanoClaw는 순수 태스크 실행기로 유지

---

## 1. 목표

Unity(WebSocket) 외에 Slack, Discord 등 외부 채널에서도 Yuri 에이전트를 호출할 수 있도록 한다.

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
├── POST /v1/channels/slack/events         ← 신규 (Slack Events API webhook)
├── POST /v1/channels/discord/interactions ← 신규 (Discord HTTP Interactions)
└── agent.ainvoke() / agent.stream()       ← 채널별 선택
         ↓ (태스크 위임 시만)
      NanoClaw (순수 태스크 실행기)
         ↓ (완료 콜백)
      FastAPI callback.py → agent.ainvoke() 재실행 → 채널 sender 응답
```

**NanoClaw 역할 변화**: 채널 허브 역할 없음. 오직 `DelegateTaskTool`로 위임된 태스크만 실행.

---

## 3. 메모리 전략

| 구분 | 키 | 설명 |
|------|----|------|
| STM | `slack:{team_id}:{channel_id}:{user_id}` | 대화별 독립 컨텍스트 |
| STM | `discord:{guild_id}:{channel_id}:{user_id}` | 대화별 독립 컨텍스트 |
| LTM | `"default"` | 전 채널 공유 |

```python
# TODO: multi-user support requires auth system
LTM_USER_ID = "default"
```

단일 사용자 개인 프로그램이므로 LTM user_id를 하드코딩한다.
모든 채널(Unity, Slack, Discord)이 동일한 LTM을 공유하여 Yuri가 채널 무관하게 같은 장기 기억을 유지한다.

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

콜백 수신 시 `reply_channel`을 조회해 적절한 sender로 응답을 라우팅한다.

---

## 4. 채널 수신 방식: HTTP Webhook

Socket Mode / WebSocket 데몬 방식을 사용하지 않는다. FastAPI는 stateless HTTP 서버이며, `lifespan` 안에서 `while True` 데몬을 구동하면 멀티 워커 환경에서 봇 연결이 중복 생성된다. 개발 시 `--reload`마다 재연결 문제도 발생한다.

**HTTP Webhook 기반으로 구현한다:**

| 채널 | 수신 방식 | FastAPI 라우트 |
|------|-----------|----------------|
| Slack | Slack Events API | `POST /v1/channels/slack/events` |
| Discord | Discord HTTP Interactions | `POST /v1/channels/discord/interactions` |

장점:
- lifespan 재연결 로직 불필요
- 단순한 JSON POST로 E2E 테스트 가능
- 멀티 워커 환경에서도 안전

개발 시 퍼블릭 URL이 필요하므로 ngrok 등을 사용한다.

**Slack URL Verification**: Slack Events API 최초 등록 시 `{"type": "url_verification", "challenge": "..."}` 요청이 온다. 라우트에서 `challenge` 값을 그대로 반환해야 한다.

**Discord 3초 제한**: Discord HTTP Interactions는 3초 내에 응답이 없으면 실패로 간주한다. `agent.ainvoke()`가 3초를 초과할 수 있으므로 Discord 라우트는 즉시 `{"type": 5}` (Deferred Response)를 반환하고, 처리 완료 후 Discord followup webhook URL로 결과를 전송한다. Slack은 이 제한이 없으므로 Slack/Discord 처리 흐름이 다르다.

---

## 5. 새 컴포넌트

### 5.1 ChannelAdapter (FastAPI)

```
backend/src/services/
└── channel_service/
    ├── __init__.py           # get_channel_sender() 팩토리 + 싱글톤 초기화
    ├── base.py               # ChannelAdapter ABC + ChannelMessage
    ├── slack/
    │   ├── adapter.py        # Slack Events API 검증 + 이벤트 파싱
    │   └── sender.py         # Slack Web API로 메시지 전송
    └── discord/
        ├── adapter.py        # Discord Interactions 검증 + 파싱
        └── sender.py         # Discord followup webhook 전송
```

**ChannelAdapter ABC**:

```python
class ChannelAdapter(ABC):
    @abstractmethod
    async def parse_event(self, payload: dict) -> ChannelMessage | None:
        """webhook payload에서 메시지를 추출. 무시할 이벤트(봇 메시지 등)는 None 반환."""
        ...

    @abstractmethod
    async def send_message(self, channel_id: str, text: str) -> None: ...
```

`tts_enabled`는 외부 채널에서 항상 `False`이므로 ABC 필드가 아닌 호출 시 상수로 처리한다.

**ChannelMessage**:

```python
@dataclass
class ChannelMessage:
    session_id: str    # "slack:{team_id}:{channel_id}:{user_id}"
    channel_id: str    # 응답을 보낼 채널 ID
    provider: str      # "slack" | "discord"
    text: str
```

**채널 sender 팩토리**:

```python
# channel_service/__init__.py
_slack_adapter: SlackAdapter | None = None
_discord_adapter: DiscordAdapter | None = None

def init_channel_service(settings: ChannelSettings) -> None:
    """main.py lifespan에서 호출."""
    global _slack_adapter, _discord_adapter
    if settings.slack_enabled:
        _slack_adapter = SlackAdapter(settings)
    if settings.discord_enabled:
        _discord_adapter = DiscordAdapter(settings)

def get_channel_sender(provider: str) -> ChannelAdapter | None:
    """provider에 해당하는 sender 반환. 비활성화된 경우 None."""
    return {"slack": _slack_adapter, "discord": _discord_adapter}.get(provider)
```

`callback.py`와 `BackgroundSweepService`는 `get_channel_sender(provider)`를 호출하고, `None` 반환 시(비활성화된 채널) 로그만 남기고 skip한다.

**`main.py` lifespan 등록**:

```python
# src/main.py lifespan
from src.services.channel_service import init_channel_service
init_channel_service(settings.channel)
```

`channel_service`는 백그라운드 태스크 없이 설정만 초기화한다 — lifespan에 비동기 태스크를 추가하지 않는다.

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
    """전체 응답을 한 번에 반환. 스트리밍 불필요한 채널(Slack, Discord)에서 사용."""
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

`save_turn()`은 STM 저장 + LTM 10턴 consolidation을 내부에서 처리한다. Unity WebSocket 경로와 동일한 패턴이다.

채널 핸들러는 `agent_service`, `stm_service`, `ltm_service`, `memory_orchestrator`에 접근해야 한다.

### 5.3 `session_lock` 유틸리티

```python
# src/services/channel_service/session_lock.py
import asyncio
from collections import defaultdict

_locks: dict[str, asyncio.Lock] = defaultdict(asyncio.Lock)

def session_lock(session_id: str) -> asyncio.Lock:
    return _locks[session_id]
```

- 타입: `asyncio.Lock` per `session_id` (인메모리, 프로세스 범위)
- 정리 정책: 개인 프로그램이므로 lock 수가 소수 — 명시적 정리 불필요. TODO로 남긴다.

---

## 6. 에이전트 실행 방식

### Unity (기존, 변경 없음)

`agent.stream()` → 토큰 스트리밍 → WebSocket → TTS

### 외부 채널 (신규)

`agent.ainvoke()` → full text 반환 → channel sender

스트리밍이 불필요한 채널에서는 `ainvoke()`를 직접 호출한다.

---

## 7. 메시지 처리 흐름

### Case A: 단순 대화 (Slack 예시)

```
Slack Events API → POST /v1/channels/slack/events
  ↓
서명 검증 (SLACK_SIGNING_SECRET)
  ↓
url_verification 요청이면 → challenge 반환 후 종료
  ↓
adapter.parse_event(payload) → ChannelMessage | None
None이면 → 200 OK 반환 후 종료 (봇 메시지, 무관한 이벤트 등)
  ↓
asyncio.create_task(_handle_channel_message(msg))  # 즉시 200 반환
  ↓ (백그라운드)
async with session_lock(session_id):
  # 1. STM 세션 upsert (신규 메서드, Phase 2에서 추가)
  stm.upsert_session(session_id, user_id="default", agent_id="yuri")
  # 2. reply_channel 메타데이터 저장
  stm.update_session_metadata(session_id, {
      "user_id": "default", "agent_id": "yuri",
      "reply_channel": {"provider": "slack", "channel_id": channel_id}
  })
  # 3. 중간 메시지 전송
  await slack_sender.send_message(channel_id, "⏳ 생각 중...")
  # 4. 컨텍스트 로드 (memory_orchestrator가 LTM prefix + STM history 통합)
  context = await memory_orchestrator.load_context(
      stm, ltm, user_id="default", agent_id="yuri",
      session_id=session_id, query=text,
  )
  # 5. 에이전트 실행
  final_text = await agent_service.ainvoke(context + [HumanMessage(text)], session_id)
  # 6. STM/LTM 저장 (fire-and-forget, Unity 경로와 동일한 패턴)
  asyncio.create_task(memory_orchestrator.save_turn(
      new_chats=[HumanMessage(text), AIMessage(final_text)],
      stm_service=stm, ltm_service=ltm,
      user_id="default", agent_id="yuri", session_id=session_id,
  ))
  # 7. 응답 전송
  await slack_sender.send_message(channel_id, final_text)
```

**주의**: Slack 라우트는 즉시 `200 OK`를 반환하고 실제 처리는 `create_task`로 백그라운드 실행한다. Slack은 응답을 기다리지 않는다.

### Case B: 태스크 위임 포함

```
(Case A와 동일하게 ainvoke 진입까지)
  ↓
DelegateTaskTool 발동 → ainvoke 즉시 반환 ("팀에 작업을 지시했습니다.")
  ↓
await slack_sender.send_message(channel_id, "알았어! 팀한테 맡겨볼게 👀")

--- (NanoClaw 작업 중...) ---

POST /v1/callback/nanoclaw/{session_id} 수신 (callback.py)
  ↓
STM에 synthetic TaskResult 메시지 주입 (기존 동작)
  ↓
STM 세션 메타데이터에서 reply_channel + user_id + agent_id 조회:
  metadata.get("reply_channel") → { provider: "slack", channel_id: "C456" }
  metadata.get("user_id")       → "default"
  metadata.get("agent_id")      → "yuri"
  ↓
reply_channel이 None이면 → Unity WebSocket 세션이므로 기존 로직 유지 (skip)
  ↓
sender = get_channel_sender(metadata["reply_channel"]["provider"])
sender가 None이면 → 채널 비활성화, 로그 후 skip
  ↓
channel_id = metadata["reply_channel"]["channel_id"]
  ↓
context = await memory_orchestrator.load_context(
    stm, ltm, user_id="default", agent_id="yuri",
    session_id=session_id, query="",  # synthetic message 포함된 history 반영
)
final_text = await agent_service.ainvoke(context, session_id)
asyncio.create_task(memory_orchestrator.save_turn(
    new_chats=[AIMessage(final_text)],
    stm_service=stm, ltm_service=ltm,
    user_id="default", agent_id="yuri", session_id=session_id,
))
  ↓
await sender.send_message(channel_id, final_text)
```

**중간 상태 메시지**:

| 타이밍 | 예시 |
|--------|------|
| ainvoke 시작 전 | "⏳ 생각 중..." |
| DelegateTaskTool 발동 후 | "알았어! 팀한테 맡겨볼게 👀" |
| 최종 응답 | Yuri 페르소나 기반 응답 |

### Discord Case

Discord 라우트는 즉시 `{"type": 5}` (Deferred Response)를 반환하고, 처리 완료 후 Discord followup URL로 결과를 전송한다. `DiscordSender.send_message(channel_id, text)`가 내부적으로 followup webhook을 호출하도록 구현한다.

---

## 8. 동시성 처리

동일 session_id로 메시지가 연속 수신될 경우 STM 오염 방지:

```python
async with session_lock(session_id):
    # 메타데이터 저장, 중간 메시지, ainvoke, STM 저장 모두 락 내부에서 실행
```

`BackgroundSweepService`의 `reply_channel` 읽기는 락 없이 수행한다 — 태스크 만료 시점에는 어댑터의 락이 이미 해제된 상태이므로 안전하다.

---

## 9. 에러 핸들링

| 상황 | 처리 |
|------|------|
| Webhook 서명 검증 실패 | `403` 즉시 반환 |
| Slack URL verification | `challenge` 값 그대로 반환 |
| Discord 3초 초과 | 즉시 `{"type": 5}` 반환 후 followup으로 결과 전송 |
| `agent.ainvoke()` 실패 | `sender.send_message("처리 중 오류가 발생했어 😥 다시 시도해줘")` |
| DelegateTaskTool 타임아웃 | BackgroundSweepService → STM `reply_channel` 조회 → `get_channel_sender(provider)?.send_message(channel_id, "태스크가 시간 초과됐어 😥")` |
| `get_channel_sender()` → None | 채널 비활성화. 로그 후 skip |
| STM 세션 없음 | `upsert_session()`으로 upsert 보장 (Phase 2 신규 메서드) |
| Slack/Discord API 전송 실패 | 로그만 기록, 재전송 없음 |

---

## 10. 환경 변수 (Pydantic Settings + YAML)

```yaml
# backend/yaml_files/channel.yaml
slack:
  enabled: true
  bot_token: ${SLACK_BOT_TOKEN}
  signing_secret: ${SLACK_SIGNING_SECRET}  # webhook 서명 검증용

discord:
  enabled: false
  bot_token: ${DISCORD_BOT_TOKEN}
  public_key: ${DISCORD_PUBLIC_KEY}        # interactions 서명 검증용
```

```python
class ChannelSettings(BaseSettings):
    slack_enabled: bool = False
    slack_bot_token: str = ""
    slack_signing_secret: str = ""
    discord_enabled: bool = False
    discord_bot_token: str = ""
    discord_public_key: str = ""
```

`enabled: false` 또는 필수 값 미설정 시 해당 어댑터 초기화 skip → `get_channel_sender()` → `None` 반환.

---

## 11. 구현 순서 (Phase)

| Phase | 내용 |
|-------|------|
| 1 | `ChannelAdapter` ABC + `ChannelMessage` + `get_channel_sender()` 팩토리 + `init_channel_service()` + `main.py` 등록 |
| 2 | `session_lock` 유틸리티 + `STMService` ABC에 `upsert_session(session_id, user_id, agent_id)` 추가 + `MongoDBSTM` 구현 (upsert 보장) |
| 3 | `AgentService` ABC에 `ainvoke()` 추가 + `OpenAIChatAgent` 구현 |
| 4 | Slack 어댑터 (서명 검증 + URL verification + 이벤트 파싱 + 전송) + `POST /v1/channels/slack/events` 라우트 |
| 5 | `callback.py` 수정 — `reply_channel` 조회 + `agent_service.ainvoke()` 호출 + 채널 응답. Unity 세션(`reply_channel` 없음)은 기존 로직 유지 |
| 6 | `BackgroundSweepService` 수정 — `__init__`에 `channel_sender_fn: Callable[[str], ChannelAdapter \| None]` 주입 + TaskFailed 시 `await channel_sender_fn(provider).send_message(...)` 호출. `main.py`에서 `BackgroundSweepService(stm, config, channel_sender_fn=get_channel_sender)` 형태로 초기화 |
| 7 | Discord 어댑터 (서명 검증 + Deferred Response + followup 전송) |
| 8 | E2E 테스트 (실제 Slack 워크스페이스 + ngrok) |

---

## 12. Out of Scope

- Multi-user auth system / UserRegistry — 개인 프로그램이므로 불필요 (`LTM_USER_ID = "default"` TODO)
- Unity ↔ Slack 계정 링킹 — auth 시스템 생기면 그때
- Slack 스레드별 독립 세션 — 향후 P2
- Discord slash command — 향후 P2
- Discord DM (guild_id 없는 경우) — followup URL 구조 차이로 향후 P2
- NanoClaw `add-slack`, `add-discord` 스킬 — 이 설계에서 사용하지 않음
