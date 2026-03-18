# Multi-Channel Support Design

**Date**: 2026-03-18
**Status**: Draft
**Scope**: FastAPI에 Slack/Discord 등 외부 채널 어댑터 추가, NanoClaw는 순수 태스크 실행기로 유지

---

## 1. 목표

Unity(WebSocket) 외에 Slack, Discord 등 외부 채널에서도 Yuri 에이전트를 호출할 수 있도록 한다.

- 외부 채널에서 Yuri에게 멘션/메시지 → Yuri가 페르소나 기반으로 응답
- 태스크는 기존과 동일하게 NanoClaw 컨테이너에서 실행
- 외부 채널에서는 TTS 비활성화
- LTM은 채널 무관하게 공유, STM은 채널별 독립 세션

---

## 2. 아키텍처

```
FastAPI
├── WebSocket (Unity)         ← 기존 변경 없음
├── Slack ChannelAdapter      ← 신규
├── Discord ChannelAdapter    ← 신규
└── process_message()         ← 공통 에이전트 실행 레이어 (신규 추출)
         ↓ (태스크 위임 시만)
      NanoClaw (순수 태스크 실행기)
         ↓ (완료 콜백)
      FastAPI callback.py → process_message() 재실행 → 채널 sender 응답
```

**NanoClaw 역할 변화**: 채널 허브 역할 없음. 오직 `DelegateTaskTool`로 위임된 태스크만 실행.

---

## 3. 메모리 전략

| 구분 | 키 | 설명 |
|------|----|------|
| STM | `slack:{team_id}:{user_id}` | 채널별 독립 대화 컨텍스트 |
| STM | `discord:{guild_id}:{user_id}` | 채널별 독립 대화 컨텍스트 |
| LTM | `registered_user_id` (UUID) | 채널 무관 공유 — 장기 기억 |

Slack user가 Unity에서도 Yuri와 대화한 적 있다면 LTM은 공유된다.
단, STM(현재 대화 맥락)은 채널별로 분리되어 섞이지 않는다.

**STM 세션 메타데이터에 추가 저장**:
```json
{
  "user_id": "uuid-...",
  "agent_id": "yuri",
  "reply_channel": {
    "provider": "slack",
    "channel_id": "C456CHANNEL"
  }
}
```
채널 어댑터는 메시지 수신 시 이 메타데이터를 STM에 저장한다.
콜백 수신 시 `reply_channel`을 조회해 적절한 sender로 응답을 라우팅한다.

---

## 4. UserRegistry

Slack/Discord user_id를 시스템 내부 `registered_user_id`로 매핑.

**MongoDB collection**: `user_registry`

```json
{
  "provider": "slack",
  "provider_user_id": "U789",
  "team_id": "T123",
  "registered_user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

- 미등록 유저: 첫 메시지 수신 시 **UUID**로 lazy registration
- UUID를 사용하므로 나중에 동일 유저의 Slack↔Unity 계정을 통합(Admin API)해도 ID 충돌 없음
- Discord DM(guild_id 없음)은 `discord:dm:{user_id}` 형태로 session_id 생성

---

## 5. 핵심 리팩터: `process_message()` 추출

현재 `handle_chat_message()`는 WebSocket 인프라(`connection_id`, `MessageProcessor`, `forward_events_fn`)에 결합되어 있어 채널 어댑터에서 직접 호출 불가.

공통 핵심 로직을 분리한다:

```python
# backend/src/services/agent_service/runner.py (신규)
async def process_message(
    text: str,
    session_id: str,
    user_id: str,
    agent_id: str,
    tts_enabled: bool,
    on_token: Callable[[str], Awaitable[None]] | None = None,
    on_tts_chunk: Callable[[TtsChunkMessage], Awaitable[None]] | None = None,
) -> str:
    """
    채널 무관 공통 에이전트 실행.
    - WebSocket: on_token/on_tts_chunk 콜백으로 스트리밍
    - 채널 어댑터: 콜백 None → 완성된 텍스트만 반환

    주의: session_lock을 내부에서 획득하지 않는다.
    호출자가 반드시 session_lock을 보유한 상태에서 호출해야 한다.
    (내부에서 중복 획득 시 데드락 발생)
    """
```

**기존 WebSocket 경로**:
```
handle_chat_message() → process_message(on_token=ws_send, on_tts_chunk=ws_send)
```

**채널 어댑터 경로**:
```
slack_adapter → process_message(on_token=None, on_tts_chunk=None) → final_text 반환
```

---

## 6. 새 컴포넌트

### 6.1 ChannelAdapter (FastAPI)

```
backend/src/services/
└── channel_service/
    ├── __init__.py
    ├── base.py               # ChannelAdapter ABC + ChannelSenderRegistry
    ├── slack/
    │   ├── adapter.py        # Slack Socket Mode 연결, 이벤트 수신
    │   └── sender.py         # Slack Web API로 메시지 전송
    └── discord/
        ├── adapter.py        # discord.py 이벤트 수신
        └── sender.py         # Discord 채널 메시지 전송
```

**ChannelAdapter ABC**:
```python
class ChannelAdapter(ABC):
    tts_enabled: bool = False  # 외부 채널은 항상 False

    @abstractmethod
    async def connect(self) -> None: ...

    @abstractmethod
    async def send_message(self, channel_id: str, text: str) -> None: ...
```

**ChannelSenderRegistry**:
```python
class ChannelSenderRegistry:
    """provider 이름으로 적절한 sender를 조회."""

    def __init__(self) -> None:
        self._registry: dict[str, ChannelAdapter] = {}  # 인스턴스 변수 — 클래스 변수 아님

    def register(self, provider: str, adapter: ChannelAdapter) -> None: ...

    def get(self, provider: str) -> ChannelAdapter | None: ...
```

`callback.py`와 `BackgroundSweepService`는 이 레지스트리를 통해 채널 sender를 조회한다.

레지스트리는 기존 서비스 패턴과 동일하게 `src/services/__init__.py`에 module-level getter로 노출한다:
```python
def get_channel_registry() -> ChannelSenderRegistry: ...
```

### 6.2 UserRegistryService (FastAPI)

```
backend/src/services/
└── user_registry_service/
    ├── __init__.py
    └── registry.py
```

```python
class UserRegistryService:
    async def resolve(
        self, provider: str, provider_user_id: str, team_id: str | None = None
    ) -> str:
        """registered_user_id(UUID) 반환. 없으면 UUID로 lazy 생성."""
```

---

## 7. 메시지 처리 흐름

### Case A: 단순 대화

```
Slack 이벤트 수신 (adapter.py)
  ↓
session_id = "slack:{team_id}:{user_id}"
registered_user_id = await user_registry.resolve("slack", slack_user_id, team_id)
  ↓
STM 세션 메타데이터 저장:
  { user_id, agent_id: "yuri", reply_channel: { provider: "slack", channel_id } }
  ↓
await slack_adapter.send_message(channel_id, "⏳ 생각 중...")
  ↓
final_text = await process_message(
    text=text,
    session_id=session_id,
    user_id=registered_user_id,
    agent_id="yuri",
    tts_enabled=False,
)
  ↓
await slack_adapter.send_message(channel_id, final_text)
```

### Case B: 태스크 위임 포함

```
(Case A와 동일하게 process_message 진입까지)
  ↓
PersonaAgent → DelegateTaskTool 발동
  ↓
await slack_adapter.send_message(channel_id, "알았어! 팀한테 맡겨볼게 👀")
  ↓
NanoClaw 컨테이너 실행 (기존 flow 그대로)
process_message() 반환 ("팀에 작업을 지시했습니다." — DelegateTaskTool 즉시 응답)
  ↓
await slack_adapter.send_message(channel_id, "팀에 작업을 지시했습니다.")

--- (NanoClaw 작업 중...) ---

POST /v1/callback/nanoclaw/{session_id} 수신 (callback.py)
  ↓
STM에 synthetic TaskResult 메시지 주입 (기존 동작)
  ↓
STM 세션 메타데이터에서 reply_channel + user_id 조회
  → metadata.get("reply_channel") → { provider: "slack", channel_id: "C456CHANNEL" }
  → metadata.get("user_id") → registered_user_id (이미 callback.py가 읽는 필드)
  ↓
sender = channel_registry.get("slack")
  ↓
final_text = await process_message(
    text="[자동] 태스크 완료, 결과를 요약해줘",  # 합성 트리거 메시지
    session_id=session_id,
    user_id=metadata.get("user_id"),   # STM 메타데이터에서 직접 읽음
    agent_id=metadata.get("agent_id"),
    tts_enabled=False,
)
  ↓
await sender.send_message(channel_id, final_text)
```

**중간 상태 메시지 타입**:

| type | 타이밍 | 예시 텍스트 |
|------|--------|------------|
| thinking | process_message 시작 전 | "⏳ 생각 중..." |
| status | DelegateTaskTool 발동 감지 시 | "알았어! 팀한테 맡겨볼게 👀" |
| final | process_message 완료 후 | Yuri 페르소나 기반 응답 |

DelegateTaskTool 발동 감지는 `process_message()` 내부에서 tool call 이벤트 스트림을 통해 수행.

---

## 8. FastAPI lifespan 변경

```python
# main.py lifespan
channel_registry = ChannelSenderRegistry()

async def _run_with_retry(adapter: ChannelAdapter, provider: str):
    """내부에서 모든 예외를 catch — 절대 외부로 전파하지 않음. 지수 백오프 적용."""
    delay = 10
    max_delay = 300  # 최대 5분
    while True:
        try:
            delay = 10  # 성공 시 초기화
            await adapter.connect()
        except Exception as e:
            logger.error(f"{provider} adapter crashed: {e}, retrying in {delay}s")
            await asyncio.sleep(delay)
            delay = min(delay * 2, max_delay)

# create_task으로 백그라운드 실행 — lifespan의 yield를 블록하지 않음
# BackgroundSweepService.start() 패턴과 동일
asyncio.create_task(_run_with_retry(slack_adapter, "slack"))
asyncio.create_task(_run_with_retry(discord_adapter, "discord"))
```

`_run_with_retry`는 `while True` 루프이므로 `await asyncio.gather(...)` 대신 `create_task`로 백그라운드 실행. 한 채널 크래시가 다른 채널에 전파되지 않음.

---

## 9. 동시성 처리

동일 session_id로 메시지가 연속 수신될 경우 STM 오염 방지:

```python
# 락 내부에서 메타데이터 저장 → thinking 전송 → process_message 모두 순서 보장
async with session_lock(session_id):
    # reply_channel 메타데이터 저장도 락 내부에서 수행 (race condition 방지)
    stm.update_session_metadata(session_id, {"reply_channel": {...}})
    await sender.send_message(channel_id, "⏳ 생각 중...")
    final_text = await process_message(...)
    await sender.send_message(channel_id, final_text)
```

session_id 단위 AsyncLock으로 순차 처리. **메타데이터 저장, thinking 전송, process_message 모두 락 내부**에서 실행하여 동시 메시지로 인한 `reply_channel` 덮어쓰기를 방지한다.

---

## 10. 에러 핸들링

| 상황 | 처리 |
|------|------|
| Slack/Discord 연결 끊김 | `_run_with_retry` 지수 백오프 재연결 (10s → 20s → ... → 최대 5분) |
| `process_message()` 실패 | `send_message("처리 중 오류가 발생했어 😥 다시 시도해줘")` |
| DelegateTaskTool 타임아웃 | `BackgroundSweepService`가 5분 후 `TaskFailed` 처리 → STM `reply_channel` 조회 → `channel_registry.get(provider).send_message(channel_id, "태스크가 시간 초과됐어 😥")`. sweep은 세션 락 없이 메타데이터를 읽는다 — 태스크 만료 시점에는 채널 어댑터의 락이 이미 해제된 상태이므로 안전함. |
| UserRegistry lazy 생성 실패 | 에러 로그 후 `process_message` 중단, 채널에 오류 메시지 전송 |
| Slack/Discord API 전송 실패 | 로그만 기록, 재전송 없음 |
| Discord DM | session_id = `discord:dm:{user_id}`, guild_id 없음으로 처리 |

---

## 11. 환경 변수 (Pydantic Settings 통합)

프로젝트 컨벤션(CLAUDE.md)에 따라 `backend/yaml_files/channel.yaml` + Pydantic settings로 관리:

```yaml
# backend/yaml_files/channel.yaml
slack:
  enabled: true
  bot_token: ${SLACK_BOT_TOKEN}
  app_token: ${SLACK_APP_TOKEN}   # Socket Mode용

discord:
  enabled: false
  bot_token: ${DISCORD_BOT_TOKEN}
```

```python
class ChannelSettings(BaseSettings):
    slack_enabled: bool = False
    slack_bot_token: str = ""
    slack_app_token: str = ""
    discord_enabled: bool = False
    discord_bot_token: str = ""
```

`enabled: false` 또는 토큰 미설정 시 lifespan에서 해당 어댑터를 스킵.

---

## 12. 구현 순서 (Phase)

| Phase | 내용 |
|-------|------|
| 1 | `UserRegistryService` + MongoDB `user_registry` 컬렉션 |
| 2 | `process_message()` 추출 — WebSocket 경로가 기존과 동일하게 동작함을 테스트로 검증 |
| 3 | `ChannelAdapter` ABC + `ChannelSenderRegistry` + session_lock 유틸 |
| 4 | Slack 어댑터 (Socket Mode 수신 + 전송) + STM `reply_channel` 메타데이터 저장 |
| 5 | `callback.py` 수정 — `reply_channel` 조회 + `process_message()` 재실행 + 채널 응답 |
| 6 | `BackgroundSweepService` 수정 — TaskFailed 시 `channel_registry`로 채널 알림 |
| 7 | Discord 어댑터 |
| 8 | E2E 테스트 (실제 Slack 워크스페이스 연동) |

---

## 13. Out of Scope

- Unity ↔ Slack 동일 유저 수동 연동 (Admin API) — 향후 P2
- Slack 스레드별 독립 세션 — 향후 P2
- Discord slash command — 향후 P2
- NanoClaw `add-slack`, `add-discord` 스킬은 이 설계에서 사용하지 않음
