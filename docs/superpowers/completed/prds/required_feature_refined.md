# 🏗️ Core Architecture (Final Draft): "Decoupled Director-Artisan"

## 1. The Director (FastAPI Backend)

* **Role**: State Owner & Fast-Path Router (단일 진실 공급원 및 프론트 컨트롤러)
* **Responsibilities**:
* **WebSocket Gateway**: Unity(Dumb UI)와의 유일한 실시간 연결 통로.
* **Memory Management**: STM(MongoDB)과 LTM(Mem0).
* **Persona Agent (LangGraph)**: System Prompt에 위임(Delegation) 가이드라인을 주입받은 메인 에이전트. 사용자의 입력을 받아 즉각적인 스트리밍 응답(Fast-path)을 제공하며, 무거운 작업이나 코딩 지시는 `DelegateTaskTool`을 호출하여 NanoClaw로 던집니다. 유저에게는 "팀에 지시했습니다"라고 알리고 다음 대화를 이어갑니다. (위임 경계 정책은 하단 [TODO] 참고)
* **Service Layer**: TTS와 VLM을 위한 REST/WebSocket 인터페이스 제공. Persona Agent의 출력 토큰을 Queue에 담아 Sentence Boundary를 감지하여 TTS_Text와 TTS를 비동기 트리거하여 Unity로 푸시합니다.
* **HTTP Webhook Server**: NanoClaw로 작업을 보낼 때는 HTTP POST(`Fire-and-forget`)를 쏘고, 결과를 받을 때는 자신의 Webhook Endpoint(`POST /api/callback/nanoclaw`)를 열어 대기합니다.
* **Background Sweep Task**: `pending_tasks` 중 `created_at + TTL`을 초과한 `running` 상태 Task를 주기적으로 스캔해 `failed`로 마킹합니다. NanoClaw는 fire-and-forget이므로 timeout 책임은 FastAPI 측이 가집니다.

## 2. The Core Bridge (`add-fastapi-channel` Skill)

* **Role**: NanoClaw와 FastAPI 간의 비동기 위임(Non-blocking Delegation) 전용 입출력 단자.
* **구현 방식**: NanoClaw의 Channel self-registration 패턴(`src/channels/registry.ts`)을 따르는 신규 채널 Skill. `add-slack`이 Slack 채널을 추가한 것과 동일한 패턴으로, NanoClaw 내부에 **Fastify 기반 HTTP 서버를 채널로서 추가**합니다.

Skill manifest 개요:

```yaml
skill: fastapi-channel
version: 1.0.0
depends: []
adds:
  - src/channels/http.ts
modifies:
  - src/channels/index.ts
structured:
  npm_dependencies:
    fastify: "^5.0.0"
  env_additions:
    - HTTP_PORT
    - FASTAPI_CALLBACK_URL
```

* **Responsibilities**:
* **Ingress (수신)**: `POST /api/webhooks/fastapi`로 FastAPI가 쏜 JSON(Task, 관련된 STM/LTM Context, `task_id`, `session_id`, `callback_url`)을 수신합니다. `callback_url`을 기반으로 `http:{url_hash}` 형태의 synthetic JID를 생성해 내부 라우팅에 사용하고, 내용을 `groupQueue`에 밀어 넣은 뒤 `202 Accepted`를 즉시 반환합니다.
* **Egress (송신)**: NanoClaw container 실행이 끝나면 `sendMessage(jid, text)` 인터페이스가 호출됩니다. HTTP channel은 JID에서 `callback_url`을 역산하여 FastAPI의 Callback Endpoint로 `{ task_id, status, summary }` 를 POST합니다.
  * `ContainerOutput.status === 'error'` 시 `status: "failed"` + 에러 메시지를 포함해 전송.
  * Callback 전송 실패 시 retry는 하지 않습니다 (FastAPI의 Background Sweep이 TTL로 처리).
  * (학습 메타데이터의 FastAPI 측 처리 정책은 [TODO] - 현재 보류)

## 3. The Artisan Team (NanoClaw Swarm)

* **Role**: Intelligence & Heavy Task Execution (백그라운드 워커)
* **Responsibilities**:
* **Pure Execution**: 큐(`groupQueue`)에 들어온 작업만 처리합니다. 외부 채널(Slack, Unity)의 존재는 모릅니다.
* **Sub-Agent Driven Multi-Persona**: **1 Group = 1 Container = 1 Main Agent(Orchestrator)**. Main Agent가 task를 분석하고, `TeamCreate`로 Persona별 Sub-agent를 spawn하여 작업을 위임합니다. 각 Sub-agent는 필요한 context만 수신하며, 독립적인 task는 병렬 실행 가능합니다. 에이전트 간 컨텍스트 공유는 Container 내부의 파일시스템과 Main Agent를 통한 결과 전달로 이루어집니다.
* **Agent Skills**: 각 Persona의 행동 지침(역할, 사용 툴, 책임 범위)은 `container/skills/` 안에 개별 Skill 파일로 캡슐화됩니다. 기존 `agent-browser/`와 동일한 디렉토리 패턴입니다. Claude는 Task 실행 시 해당 Skill 파일들을 참조해 각 Persona를 수행하며, System Prompt가 아닌 Skill 파일로 분리하므로 Persona 추가/수정이 독립적으로 가능합니다.

```
container/skills/
├── agent-browser/
├── dev-agent/
├── reviewer-agent/
└── pm-agent/
```

* **IPC는 출력 경로**: `src/ipc.ts`의 IPC는 에이전트 간 통신이 아닙니다. Container 안의 Claude가 `send_message` MCP tool을 호출하면 IPC 파일이 기록되고, host의 IPC watcher가 이를 읽어 해당 채널로 전달합니다. (`sender` 필드로 현재 Persona를 구분합니다.)
* **Agnostic Routing**: 작업이 완료되면 자신을 호출한 Ingress의 출처(JID)로 결과를 반환합니다.

## 4. The Observers & Bypasses

### Observer (`add-ipc-observer` Skill)

* **Role**: NanoClaw 내부 IPC 흐름을 낚아채 외부로 미러링하는 독립 플러그인. Core 비즈니스 로직과 철저히 격리.
* **완전 독립 (depends: 없음)**: 채널 메커니즘에 의존하지 않습니다. Staging 디렉토리 패턴은 NanoClaw의 어떤 채널이 설치되어 있든 무관하게 동작합니다.

Skill manifest 개요:

```yaml
skill: ipc-observer
version: 1.0.0
depends: []
modifies:
  - src/ipc.ts
  - container/agent-runner/src/ipc-mcp-stdio.ts
structured:
  env_additions:
    - IPC_OBSERVER_SLACK_JID
```

**Staging Directory 패턴:**

Container의 `send_message`가 기록하는 경로를 `ipc/{group}/messages/` 대신 `ipc/{group}/staging/`으로 변경합니다. IPC watcher 루프 상단의 `promoteStagingFiles()` 함수가 staging 파일을 읽어 설정된 Observer 채널(`IPC_OBSERVER_SLACK_JID`)로 mirror한 뒤 `messages/`로 atomic move(`fs.renameSync`)합니다.

```
Container writes → ipc/{group}/staging/*.json
                        ↓ promoteStagingFiles()
              Observer로 mirror (실패해도 무관)
                        ↓ fs.renameSync (atomic, 항상 실행)
              ipc/{group}/messages/*.json
                        ↓ 기존 IPC watcher
                   send → delete
```

**핵심 설계 원칙:**
* Slack posting 실패 여부와 관계없이 promote는 항상 실행 (Observer는 core flow의 의존성이 아님)
* IPC 메시지의 `sender` 필드를 활용해 Persona별 로깅 구분 (Observer 단독으로 동작, 외부 Skill 의존 없음)
* **[TODO]** `sender` 기반 Slack Thread 분리 로깅 (Observer 내부 구현)

### Direct Access (채널 메커니즘 불필요)

유저가 Unity/FastAPI를 거치지 않고 NanoClaw에 직접 명령을 꽂는 방법은 **IPC 파일을 직접 작성**하는 것입니다. `ipc/{group}/tasks/` 에 task JSON 파일을 쓰면 기존 IPC watcher가 그대로 처리합니다. NanoClaw의 채널 메커니즘을 건드리지 않습니다.

Slack을 통한 접근은 `add-slack`이 설치되어 있으면 별도 작업 없이 이미 동작합니다.

### Skill 구성 요약

| Skill (manifest name) | 역할 | depends |
|---|---|---|
| `slack` | Slack 채널 (기존) | — |
| **`fastapi-channel`** (신규) | HTTP 채널 + Ingress/Egress + synthetic JID routing | — |
| **`ipc-observer`** (신규) | Staging IPC 패턴 + 외부 미러링 + Persona별 로깅 | — |

`fastapi-channel`과 `ipc-observer`는 서로 독립적이며 각각 단독으로도 동작합니다.

## 5. The Dumb UI (Unity)

* **Role**: Performer.
* **Responsibilities**: FastAPI가 주는 텍스트 렌더링, 오디오 청크 재생, Emotion 기반 VRM 모델 제어, 사용자 입력 수집 및 전달.

---

## 6. 🔄 Interaction Flow

### 비동기 위임 (Non-Blocking Delegation Flow)

1. **Unity**: "auth-fix 브랜치 코드 리뷰 좀 해줘."
2. **FastAPI (PersonaAgent)**: LLM이 System Prompt의 위임 규칙에 따라 `DelegateTaskTool`을 트리거합니다.
   * `DelegateTaskTool` 내부: `task_id(uuid)` 생성 → `session.metadata.pending_tasks`에 Task Record 추가 (status: `running`)
   * 스트리밍 응답: "알겠습니다. 코드 리뷰 팀에 작업을 지시하고 결과가 나오면 알려드릴게요."
3. **FastAPI → NanoClaw (Ingress)**: `POST /api/webhooks/fastapi`로 Task 내용 + `task_id` + `session_id` + `callback_url` 전송. NanoClaw는 `202 Accepted` 즉시 반환.
4. **NanoClaw 내부 처리 (Artisan Team)**: 단일 Claude 인스턴스가 `container/skills/` Skill 파일들을 참조해 Persona들을 순차적으로 수행. (`ipc-observer` 적용 시 Slack Observer가 IPC staging을 통해 Thread에 Persona별 로깅. Claude는 Slack의 존재를 모릅니다.)
5. **NanoClaw → FastAPI (Egress)**: 작업 완료 후 `POST /api/callback/nanoclaw`로 `task_id` + `status` + 요약본 전송.
6. **FastAPI (Callback 수신)**:
   * `task_id`로 `session.metadata.pending_tasks` 조회 → status `done` 또는 `failed` 업데이트
   * 요약본을 STM chat history에 **system 메시지로 삽입** (synthetic message injection)
   * LTM consolidation은 **이 시점에 트리거하지 않습니다.** Callback handler는 삽입과 status 업데이트만 담당합니다.
7. **다음 사용자 발화 시**: Agent_Service의 기존 턴 처리 흐름에서 LTM consolidation 조건(`current_turn - ltm_last_consolidated_at_turn >= 10`)을 체크합니다. synthetic message가 chat history에 포함된 상태에서 자연스럽게 처리됩니다. turn counter는 user message에만 increment됩니다.
   * PersonaAgent가 `get_chat_history()`에서 삽입된 system 메시지를 읽어 보고합니다.
   * *"사용자님, 아까 지시하신 코드 리뷰가 완료되었습니다. 보안 결함이 하나 발견되었다고 하네요."*

#### Task Record Schema (STM `session.metadata`)

```json
{
  "ltm_last_consolidated_at_turn": 0,
  "pending_tasks": [
    {
      "task_id": "uuid-v4",
      "description": "auth-fix 브랜치 코드 리뷰",
      "status": "running | done | failed",
      "created_at": "ISO8601"
    }
  ]
}
```

`failed` 마킹 주체: NanoClaw Egress가 `status: "failed"`로 callback 전송하거나, FastAPI Background Sweep이 TTL 초과를 감지하여 직접 마킹.

#### Synthetic Message Schema (STM chat history 삽입)

```json
{
  "role": "system",
  "content": "[TaskResult:{task_id}] 코드 리뷰 완료 - 보안 결함 1건 발견 (line 45)"
}
```

#### [TODO] Push 알림

현재는 Pull 방식 (다음 발화 시 PersonaAgent가 system 메시지를 읽어 보고). 유저가 오래 침묵할 경우를 위한 Push (Callback 수신 시 WebSocket으로 Unity에 알림)는 Unity 알림 UI 구현 시점에 추가합니다.

#### [TODO] Delegation 경계 정책

PersonaAgent System Prompt에 위임 기준 규칙을 정의합니다. 경계가 애매한 경우 유저에게 재질문하거나 Human-in-the-Loop 방식으로 처리합니다. 별도 classifier는 TTFT 이중 비용 문제로 도입하지 않습니다.

#### Appendix: `ipc-observer` 적용 시 Slack 로깅 예시

```text
[ReviewAgent]: "Found potential security flaw in auth-fix branch."
[DevAgent]: "Initial implementation draft..."
[ReviewerAgent]: "Wait, security flaw detected at line 45."
[DevAgent]: "Corrected. Here is the patch."
[ReviewerAgent]: "Approved. Sending to PMAgent."
[PMAgent]: "Review complete. Auth-fix branch looks good. Summarizing for FastAPI callback."
```

### Real-time TTS Flow

* **FastAPI**: PersonaAgent가 뱉어내는 토큰을 큐잉하며 문장 경계(Sentence Boundary)를 감지합니다.
* **TTS Trigger**: 문장이 완성되면 비동기로 TTS 합성을 시작하고, 완료된 오디오 청크와 Text Chunk, Emotion등의 Metadata를 WebSocket을 통해 Unity로 푸시합니다.

### Explicit Interrupt (Barge-in) - *[TODO]*

현재 설계에서는 보류. 향후 FastAPI 측의 TTS 오디오 큐 클리어 및 Persona Agent 대화 강제 중단, 그리고 필요한 경우 NanoClaw에 `CancelTaskTool` 명령을 전송하는 방향으로 설계될 예정입니다.
