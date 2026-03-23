# **세션 사이드바와 채팅창 UI 구성**

Updated: 2026-03-22

## 기본 상태 (패널 모두 숨김)

앱 시작 시 패널은 모두 숨겨져 있고, 하단 컨트롤 바만 표시된다.

```text
┌────────────────────────────────────────────────────────────┐
│                      ✔ Connected                           │
│ [⠿] [☰] [ Enter message... ] [Send] [💬] [⚙]             │
└────────────────────────────────────────────────────────────┘
```

## 패널 열린 상태 (위로 최대 350px 확장, 스크롤)

패널은 컨트롤 바 위쪽으로 확장된다. 최대 높이 350px, 초과 시 스크롤.

```text
┌──────────────────────────────────────────────────────────────────┐
│ [세션 사이드바]    | [채팅창]                   | [설정 패널]     │  ↑
│                    |                            |                 │  max
│  Conversations     |  AI: What is the most...  | user_id: ____   │  350px
│                    |                 01:33:17   | agent_id: ____  │  (scroll)
│  - Meeting Notes   |  User: How are you...     | FastAPI WS: __  │
│    [✎] [🗑]       |                 01:33:39   | FastAPI REST: _ │
│    CreatedAt ...   |  AI: What leads...        | FastAPI Token:  │
│    UpdatedAt ...   |               01:33:53    |  ••••••         │
│  - API Plan        |  User: Example... 01:34:19| Homunculus: ___ │
│    [✎] [🗑]       |                            | TTS Ref ID: ___ │
│    CreatedAt ...   |                            |                 │
│    UpdatedAt ...   |                            | [    Save    ]  │
│                    |                            |                 │
│  [ + New Chat ]    |                            |                 │
├──────────────────────────────────────────────────────────────────┤
│                      ✔ Connected                                  │
│ [⠿] [☰] [ Enter message... ] [Send/Stop] [💬] [⚙]              │
└──────────────────────────────────────────────────────────────────┘
```

### 주요 컴포넌트

- **세션 사이드바**: 세션 목록 (CreatedAt / UpdatedAt 두 줄 표시), [✎ 이름변경] [🗑 삭제], [+ New Chat]
- **채팅창**: AI/User 메시지 + 타임스탬프 (backend `created_at` 기준), typing indicator (stream_start ~ stream_end)
- **설정 패널**: 7개 필드 모두 인라인 편집 가능. Save 버튼(idle / saving / ✓ Saved / ✗ Error 4단계 상태). 저장 시 `updateConfig` RPC → `config.yaml` write-back → `dm-config` signal로 UI 즉시 갱신. `fastapi_token` 필드는 `type="password"`.
- **하단 컨트롤 바**:
  - 연결 상태: `✔ Connected` / `✖ Disconnected` / `⚠ Restart required`
  - `⠿` — 웹뷰 위치 드래그 (world-space offset, `DRAG_SCALE=0.002`)
  - `☰` — 세션 사이드바 토글
  - 메시지 입력창
  - `Send` / `Stop` — AI 처리 중 Stop으로 전환, 입력창 비활성화
  - `💬` — 채팅창 토글
  - `⚙` — 설정 패널 토글

## 설정 필드 목록

| 필드 | config.yaml 키 | 비고 |
|------|---------------|------|
| user_id | `user_id` | |
| agent_id | `agent_id` | |
| FastAPI WS URL | `fastapi.ws_url` | |
| FastAPI REST URL | `fastapi.rest_url` | |
| FastAPI Token | `fastapi.token` | password 마스킹 |
| Homunculus API URL | `homunculus_api_url` | |
| TTS Reference ID | `tts.reference_id` | VoiceVox 참조 음성 |

## 채팅창, 세션사이드바는 모두 Toggle 여부와 관련없이 작동해야 함

시나리오

1. 세션사이드바 열림, 채팅창 닫힘 → 사이드바에서 New Chat 버튼 → 채팅창 토글 무관하게 새 대화 시작
2. 세션사이드바 열림, 채팅창 닫힘 → 사이드바에서 기존 대화 클릭 → 채팅창 토글 무관하게 해당 대화로 이동
3. 세션사이드바 닫힘, 채팅창 열림 → 새 메시지 입력 → 채팅창 메시지 추가 + 사이드바 UpdatedAt 갱신
4. 세션사이드바 닫힘, 채팅창 닫힘 → 새 메시지 입력 → 채팅창 메시지 추가 + 사이드바 UpdatedAt 갱신
