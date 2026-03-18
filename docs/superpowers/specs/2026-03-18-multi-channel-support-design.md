# Multi-Channel Support Design

**Date**: 2026-03-18 (rev.2 — 리드 아키텍트 피드백 반영)
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
├── WebSocket (Unity)              ← 기존 변경 없음
├── POST /v1/channels/slack/events ← 신규 (Slack Events API webhook)
├── POST /v1/channels/discord/interactions ← 신규 (Discord HTTP Interactions)
└── agent.ainvoke() / agent.stream()  ← 채널별 선택
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

**대신 HTTP Webhook 기반으로 구현한다:**

| 채널 | 수신 방식 | FastAPI 라우트 |
|------|-----------|----------------|
| Slack | Slack Events API | `POST /v1/channels/slack/events` |
| Discord | Discord HTTP Interactions | `POST /v1/channels/discord/interactions` |

장점:
- lifespan 재연결 로직 불필요 — `_run_with_retry`, `asyncio.create_task` 전부 삭제
- 단순한 JSON POST로 E2E 테스트 가능
- 멀티 워커 환경에서도 안전

개발 시 퍼블릭 URL이 필요하므로 ngrok 등을 사용한다.

---

## 5. 새 컴포넌트

### 5.1 ChannelAdapter (FastAPI)

```
backend/src/services/
└── channel_service/
    ├── __init__.py
    ├── base.py               # ChannelAdapter ABC
    ├── slack/
    │   ├── adapter.py        # Slack Events API 검증 + 이벤트 파싱
    │   └── sender.py         # Slack Web API로 메시지 전송
    └── discord/
        ├── adapter.py        # Discord Interactions 검증 + 파싱
        └── sender.py         # Discord 채널 메시지 전송
```

**ChannelAdapter ABC**:
```python
class ChannelAdapter(ABC):
    tts_enabled: bool = False  # 외부 채널은 항상 False

    @abstractmethod
    async def parse_event(self, payload: dict) -> ChannelMessage | None:
        """webhook payload에서 메시지를 추출. 무시할 이벤트는 None 반환."""
        ...

    @abstractmethod
    async def send_message(self, channel_id: str, text: str) -> None: ...
```

**ChannelMessage**:
```python
@dataclass
class ChannelMessage:
    session_id: str    # "slack:{team_id}:{channel_id}:{user_id}"
    channel_id: str    # 응답을 보낼 채널 ID
    provider: str      # "slack" | "discord"
    text: str
```

채널 sender 조회는 `provider` 문자열로 단순 팩토리 함수 사용:
```python
def get_channel_sender(provider: str) -> ChannelAdapter:
    return {"slack": slack_adapter, "discord": discord_adapter}[provider]
```

---

## 6. 에이전트 실행 방식

### Unity (기존, 변경 없음)
`agent.stream()` → 토큰 스트리밍 → WebSocket → TTS

### 외부 채널 (신규)
`agent.ainvoke()` → full text 반환 → channel sender

스트리밍이 불필요한 채널에서는 `ainvoke()`를 직접 호출한다. `process_message()`에 콜백 함수를 주입하는 방식을 사용하지 않는다.

```python
# 외부 채널 처리
result = await agent.ainvoke(
    {"messages": history + [HumanMessage(content=text)]},
    config={"configurable": {"session_id": session_id}},
)
final_text = result["messages"][-1].content
await sender.send_message(channel_id, final_text)
```

---

## 7. 메시지 처리 흐름

### Case A: 단순 대화

```
Slack Events API → POST /v1/channels/slack/events
  ↓
adapter.parse_event(payload)
  → ChannelMessage(session_id="slack:T123:C456:U789", channel_id="C456", ...)
  ↓
async with session_lock(session_id):
  STM 세션 메타데이터 저장:
    { user_id: "default", agent_id: "yuri",
      reply_channel: { provider: "slack", channel_id: "C456" } }
  await slack_sender.send_message(channel_id, "⏳ 생각 중...")
  result = await agent.ainvoke({...}, config={session_id})
  await slack_sender.send_message(channel_id, result["messages"][-1].content)
```

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
STM 세션 메타데이터에서 reply_channel 조회:
  → metadata.get("reply_channel") → { provider: "slack", channel_id: "C456" }
  → metadata.get("user_id")       → "default"
  ↓
sender = get_channel_sender("slack")
result = await agent.ainvoke({...}, config={session_id})
await sender.send_message(channel_id, result["messages"][-1].content)
```

**중간 상태 메시지**:

| 타이밍 | 예시 |
|--------|------|
| ainvoke 시작 전 | "⏳ 생각 중..." |
| DelegateTaskTool 발동 후 | "알았어! 팀한테 맡겨볼게 👀" |
| 최종 응답 | Yuri 페르소나 기반 응답 |

---

## 8. 동시성 처리

동일 session_id로 메시지가 연속 수신될 경우 STM 오염 방지:

```python
async with session_lock(session_id):
    # 메타데이터 저장, 중간 메시지, ainvoke 모두 락 내부에서 실행
    stm.update_session_metadata(session_id, {"reply_channel": {...}})
    await sender.send_message(channel_id, "⏳ 생각 중...")
    result = await agent.ainvoke(...)
    await sender.send_message(channel_id, result["messages"][-1].content)
```

메타데이터 저장과 ainvoke 호출이 모두 락 내부에 있어 `reply_channel` 덮어쓰기를 방지한다.

BackgroundSweepService의 `reply_channel` 읽기는 락 없이 수행한다 — 태스크 만료 시점에는 어댑터의 락이 이미 해제된 상태이므로 안전하다.

---

## 9. 에러 핸들링

| 상황 | 처리 |
|------|------|
| Webhook 서명 검증 실패 | `403` 즉시 반환 |
| `agent.ainvoke()` 실패 | `send_message("처리 중 오류가 발생했어 😥 다시 시도해줘")` |
| DelegateTaskTool 타임아웃 | BackgroundSweepService가 5분 후 TaskFailed → STM `reply_channel` 조회 → `get_channel_sender(provider).send_message(channel_id, "태스크가 시간 초과됐어 😥")` |
| Discord DM | session_id = `discord:dm:{user_id}`, guild_id 없음으로 처리 |
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

`enabled: false` 또는 필수 값 미설정 시 해당 라우트를 `503`으로 응답.

---

## 11. 구현 순서 (Phase)

| Phase | 내용 |
|-------|------|
| 1 | `ChannelAdapter` ABC + `ChannelMessage` + `get_channel_sender()` 팩토리 |
| 2 | Slack 어댑터 (Events API 검증 + 파싱 + 전송) + `POST /v1/channels/slack/events` 라우트 |
| 3 | STM `reply_channel` 메타데이터 저장 + session_lock 유틸 |
| 4 | `callback.py` 수정 — `reply_channel` 조회 + `agent.ainvoke()` 재실행 + 채널 응답 |
| 5 | `BackgroundSweepService` 수정 — TaskFailed 시 채널 알림 |
| 6 | Discord 어댑터 |
| 7 | E2E 테스트 (실제 Slack 워크스페이스 + ngrok) |

---

## 12. Out of Scope

- Multi-user auth system / UserRegistry — 개인 프로그램이므로 불필요 (`LTM_USER_ID = "default"` TODO)
- Unity ↔ Slack 계정 링킹 — auth 시스템 생기면 그때
- Slack 스레드별 독립 세션 — 향후 P2
- Discord slash command — 향후 P2
- NanoClaw `add-slack`, `add-discord` 스킬 — 이 설계에서 사용하지 않음
