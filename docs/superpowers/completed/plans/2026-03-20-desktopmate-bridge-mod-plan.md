# desktopmate-bridge MOD Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `feature/desktopmate-bridge` 브랜치에서 누락된 VRM spawn 로직, package.json menus 형식 수정, open-chat 커맨드, vitest 격리 설정을 추가해 MOD를 완성한다.

**Architecture:** `service.ts`가 Carlotta VRM을 스폰하고 WebSocket 브릿지와 병렬로 실행된다. `vrm` 인스턴스는 `spawnCharacter()` → `connectAndServe(config, vrm)` → `connectWithRetry` → `handleMessage` → `handleTtsChunk` 전체 체인을 통해 전달된다. UI(ChatWindow/SessionSidebar/ControlBar/SettingsPanel)는 이미 완성되어 변경하지 않는다.

**Tech Stack:** TypeScript, `@hmcs/sdk` (Vrm, signals, rpc, preferences), Vitest, pnpm workspace

---

## Branch & Working Directory

모든 작업은 `feature/desktopmate-bridge` 브랜치에서 진행한다.

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus
git checkout feature/desktopmate-bridge
```

작업 디렉토리는 항상 `mods/desktopmate-bridge/`다.

---

## File Map

| 상태 | 경로 | 역할 |
|------|------|------|
| **복사** | `mods/desktopmate-bridge/vrm/Carlotta.vrm` | VRM 에셋 |
| **신규** | `mods/desktopmate-bridge/commands/open-chat.ts` | 채팅 WebView 오픈 커맨드 |
| **신규** | `mods/desktopmate-bridge/vitest.config.ts` | unit 테스트 전용 설정 (e2e 제외) |
| **신규** | `mods/desktopmate-bridge/vitest.e2e.config.ts` | E2E 전용 설정 |
| **수정** | `mods/desktopmate-bridge/package.json` | menus 형식 수정 + Carlotta asset + open-chat bin + scripts |
| **수정** | `mods/desktopmate-bridge/service.ts` | spawnCharacter() 추가 + vrm 체인 전파 + entity_id 제거 |
| **수정** | `mods/desktopmate-bridge/config.yaml` | entity_id 필드 제거 |
| **수정** | `mods/desktopmate-bridge/ui/src/store.test.ts` | 누락된 테스트 케이스 3개 추가 |

---

## Task 1: Carlotta VRM 에셋 추가 및 package.json 수정

**Files:**
- Copy: `/home/spow12/codes/2025_lower/DesktopMatePlus/Carlotta.vrm` → `mods/desktopmate-bridge/vrm/Carlotta.vrm`
- Modify: `mods/desktopmate-bridge/package.json`
- Modify: `mods/desktopmate-bridge/config.yaml`

- [ ] **Step 1: Carlotta.vrm 복사**

```bash
mkdir -p mods/desktopmate-bridge/vrm
cp /home/spow12/codes/2025_lower/DesktopMatePlus/Carlotta.vrm mods/desktopmate-bridge/vrm/Carlotta.vrm
ls -lh mods/desktopmate-bridge/vrm/
```

Expected: `Carlotta.vrm` 파일 존재 확인.

- [ ] **Step 2: package.json 전체 교체**

`mods/desktopmate-bridge/package.json`을 아래 내용으로 교체한다:

```json
{
  "name": "@hmcs/desktopmate-bridge",
  "version": "0.1.0",
  "description": "FastAPI WebSocket bridge and chat UI for DesktopMate+",
  "license": "MIT",
  "type": "module",
  "scripts": {
    "build:ui": "pnpm --filter @hmcs/desktopmate-bridge-ui build",
    "dev:ui": "pnpm --filter @hmcs/desktopmate-bridge-ui dev",
    "mock": "node --import tsx scripts/mock-homunculus.ts",
    "test": "vitest run",
    "test:e2e": "FASTAPI_URL=http://localhost:5500 vitest run -c vitest.e2e.config.ts"
  },
  "homunculus": {
    "service": "service.ts",
    "menus": [
      {
        "id": "open-desktopmate-chat",
        "text": "Chat",
        "command": "open-chat"
      }
    ],
    "assets": {
      "desktopmate-bridge:carlotta": {
        "path": "vrm/Carlotta.vrm",
        "type": "vrm",
        "description": "Carlotta VRM character for DesktopMate+"
      },
      "desktopmate-bridge:chat-ui": {
        "path": "ui/dist/index.html",
        "type": "html",
        "description": "DesktopMate+ chat UI"
      }
    }
  },
  "bin": {
    "open-chat": "commands/open-chat.ts"
  },
  "dependencies": {
    "@hmcs/sdk": "workspace:*",
    "js-yaml": "^4.1.1",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "@types/js-yaml": "^4.0.9",
    "@types/node": "^22.0.0",
    "tsx": "^4.19.0",
    "typescript": "^5.9.3",
    "vitest": "^3.0.0",
    "zustand": "^5.0.12"
  }
}
```

- [ ] **Step 3: config.yaml에서 entity_id 제거**

`mods/desktopmate-bridge/config.yaml`의 `homunculus` 섹션에서 `entity_id` 라인을 제거한다:

```yaml
fastapi:
  ws_url: "ws://127.0.0.1:5500/v1/chat/stream"
  rest_url: "http://127.0.0.1:5500"
  token: "<auth_token>"
  user_id: "default"
  agent_id: "yuri"
homunculus:
  api_url: "http://localhost:3100"
```

- [ ] **Step 4: 커밋**

```bash
git add mods/desktopmate-bridge/vrm/Carlotta.vrm \
        mods/desktopmate-bridge/package.json \
        mods/desktopmate-bridge/config.yaml
git commit -m "feat(desktopmate-bridge): add Carlotta VRM asset and fix package.json"
```

---

## Task 2: commands/open-chat.ts 추가

**Files:**
- Create: `mods/desktopmate-bridge/commands/open-chat.ts`

> **참고:** 이 커맨드는 채팅 UI가 전역 패널(특정 VRM에 귀속되지 않음)이기 때문에 `input.parseMenu()`를 호출하지 않는다. voicevox의 `open-settings.ts`는 per-VRM 패널이라 다르다.

- [ ] **Step 1: commands 디렉토리 및 파일 생성**

`mods/desktopmate-bridge/commands/open-chat.ts` 파일을 생성한다:

```typescript
#!/usr/bin/env tsx
import { Webview, webviewSource, audio } from "@hmcs/sdk";
import { output } from "@hmcs/sdk/commands";

try {
  await Webview.open({
    source: webviewSource.local("desktopmate-bridge:chat-ui"),
    size: [0.9, 1.0],
    viewportSize: [700, 600],
    offset: [1.1, 0],
  });
  await audio.se.play("se:open");
  output.succeed();
} catch (e) {
  output.fail("OPEN_CHAT_FAILED", (e as Error).message);
}
```

- [ ] **Step 2: 커밋**

```bash
git add mods/desktopmate-bridge/commands/open-chat.ts
git commit -m "feat(desktopmate-bridge): add open-chat bin command"
```

---

## Task 3: service.ts — spawnCharacter() 추가 및 vrm 체인 전파

**Files:**
- Modify: `mods/desktopmate-bridge/service.ts`

현재 `service.ts`의 전체 구조를 파악하고 수정한다. 변경 범위:
1. `Config` 인터페이스에서 `homunculus.entity_id` 제거
2. `handleTtsChunk(msg, config)` → `handleTtsChunk(msg, vrm: Vrm)` 시그니처 변경
3. `handleMessage(event, config)` → `handleMessage(event, config, vrm: Vrm)`
4. `connectWithRetry(config, retryState)` → `connectWithRetry(config, vrm: Vrm, retryState)`
5. `handleClose(event, config, retryState)` → `handleClose(event, config, vrm: Vrm, retryState)`
6. `connectAndServe(config)` → `connectAndServe(config, vrm: Vrm)`
7. `spawnCharacter()` 함수 추가
8. entry point 수정: `vrm = await spawnCharacter()` 후 `connectAndServe(config, vrm)` fire-and-forget

- [ ] **Step 1: import 라인 수정 확인**

현재 service.ts 상단의 import를 확인한다:

```bash
head -10 mods/desktopmate-bridge/service.ts
```

import 라인이 아래와 같아야 한다 (이미 맞으면 그대로):

```typescript
import { signals, Vrm, type TimelineKeyframe } from "@hmcs/sdk";
import { rpc } from "@hmcs/sdk/rpc";
```

`Vrm`, `type TimelineKeyframe`이 없으면 추가한다. `preferences`, `repeat`, `sleep`, `type TransformArgs`도 추가한다:

```typescript
import { signals, Vrm, type TimelineKeyframe, type TransformArgs, preferences, repeat, sleep } from "@hmcs/sdk";
import { rpc } from "@hmcs/sdk/rpc";
```

- [ ] **Step 2: Config 인터페이스에서 entity_id 제거**

`Config` 인터페이스의 `homunculus` 필드를 수정한다:

```typescript
// Before
homunculus: {
  entity_id: number;
  api_url: string;
};

// After
homunculus: {
  api_url: string;
};
```

`loadConfig()` 함수에서 `raw.homunculus.entity_id = Number(raw.homunculus.entity_id);` 라인도 제거한다.

- [ ] **Step 3: handleTtsChunk 시그니처 변경**

```typescript
// Before
async function handleTtsChunk(
  msg: {
    sequence: number;
    text: string;
    emotion: string;
    audio_base64: string | null;
    keyframes: TimelineKeyframe[];
  },
  config: Config,
): Promise<void> {
  if (msg.audio_base64) {
    const audioBytes = Buffer.from(msg.audio_base64, "base64");
    const vrm = new Vrm(config.homunculus.entity_id);
    await vrm.speakWithTimeline(audioBytes, msg.keyframes);
  }
  await signals.send("dm-tts-chunk", {
    sequence: msg.sequence,
    text: msg.text,
    emotion: msg.emotion,
  });
}

// After
async function handleTtsChunk(
  msg: {
    sequence: number;
    text: string;
    emotion: string;
    audio_base64: string | null;
    keyframes: TimelineKeyframe[];
  },
  vrm: Vrm,
): Promise<void> {
  if (msg.audio_base64) {
    const audioBytes = Buffer.from(msg.audio_base64, "base64");
    await vrm.speakWithTimeline(audioBytes, msg.keyframes);
  }
  await signals.send("dm-tts-chunk", {
    sequence: msg.sequence,
    text: msg.text,
    emotion: msg.emotion,
  });
}
```

- [ ] **Step 4: handleMessage 시그니처 변경**

```typescript
// Before
async function handleMessage(
  event: MessageEvent,
  config: Config,
): Promise<void> {
  const msg = JSON.parse(event.data as string);
  switch (msg.type) {
    // ...
    case "tts_chunk":
      await handleTtsChunk(msg, config);
      break;
    // ...
  }
}

// After
async function handleMessage(
  event: MessageEvent,
  config: Config,
  vrm: Vrm,
): Promise<void> {
  const msg = JSON.parse(event.data as string);
  switch (msg.type) {
    // ...
    case "tts_chunk":
      await handleTtsChunk(msg, vrm);
      break;
    // ...
  }
}
```

- [ ] **Step 5: connectWithRetry 시그니처 변경**

```typescript
// Before
async function connectWithRetry(
  config: Config,
  retryState: RetryState,
): Promise<void> {
  const ws = new WebSocket(config.fastapi.ws_url);
  _ws = ws;
  // ...
  ws.addEventListener("message", (event) => {
    handleMessage(event, config).catch(console.error);
  });
  ws.addEventListener("close", async (event) => {
    await handleClose(event, config, retryState);
  });
}

// After
async function connectWithRetry(
  config: Config,
  vrm: Vrm,
  retryState: RetryState,
): Promise<void> {
  const ws = new WebSocket(config.fastapi.ws_url);
  _ws = ws;
  // ...
  ws.addEventListener("message", (event) => {
    handleMessage(event, config, vrm).catch(console.error);
  });
  ws.addEventListener("close", async (event) => {
    await handleClose(event, config, vrm, retryState);
  });
}
```

- [ ] **Step 6: handleClose 시그니처 변경**

```typescript
// Before
async function handleClose(
  event: CloseEvent,
  config: Config,
  retryState: RetryState,
): Promise<void> {
  // ...
  await connectWithRetry(config, { attempts: retryState.attempts + 1 });
}

// After
async function handleClose(
  event: CloseEvent,
  config: Config,
  vrm: Vrm,
  retryState: RetryState,
): Promise<void> {
  // ...
  await connectWithRetry(config, vrm, { attempts: retryState.attempts + 1 });
}
```

- [ ] **Step 7: connectAndServe 시그니처 변경**

```typescript
// Before
async function connectAndServe(config: Config): Promise<void> {
  // ...
  await connectWithRetry(config, { attempts: 0 });
}

// After
async function connectAndServe(config: Config, vrm: Vrm): Promise<void> {
  // ...
  await connectWithRetry(config, vrm, { attempts: 0 });
}
```

- [ ] **Step 8: spawnCharacter() 함수 추가**

`connectAndServe` 함수 위에 아래 함수를 추가한다:

```typescript
// TODO: make VRM asset configurable via UI settings
const CHARACTER_ASSET_ID = "desktopmate-bridge:carlotta";

async function spawnCharacter(): Promise<Vrm> {
  const transform = await preferences.load<TransformArgs>(`transform::${CHARACTER_ASSET_ID}`);
  const vrm = await Vrm.spawn(CHARACTER_ASSET_ID, { transform });
  const animOpts = { repeat: repeat.forever(), transitionSecs: 0.5 } as const;

  await vrm.playVrma({ asset: "vrma:idle-maid", ...animOpts });

  vrm.events().on("state-change", async (e) => {
    if (e.state === "idle") {
      await vrm.playVrma({ asset: "vrma:idle-maid", ...animOpts });
      await sleep(500);
      await vrm.lookAtCursor();
    } else if (e.state === "drag") {
      await vrm.unlook();
      await vrm.playVrma({ asset: "vrma:grabbed", ...animOpts, resetSpringBones: true });
    } else if (e.state === "sitting") {
      await vrm.playVrma({ asset: "vrma:idle-sitting", ...animOpts });
      await sleep(500);
      await vrm.lookAtCursor();
    }
  });

  return vrm;
}
```

- [ ] **Step 9: entry point 수정**

파일 맨 아래의 entry point를 수정한다:

```typescript
// Before
const config = loadConfig();
await connectAndServe(config);

// After
const config = loadConfig();
const vrm = await spawnCharacter();              // VRM spawned first
connectAndServe(config, vrm).catch(console.error); // fire-and-forget: WS + RPC
```

> `.catch(console.error)` 필수: fire-and-forget 패턴에서 unhandled rejection이 silently swallowed되는 것을 방지한다.

- [ ] **Step 10: 커밋**

```bash
git add mods/desktopmate-bridge/service.ts
git commit -m "feat(desktopmate-bridge): add Carlotta VRM spawn and wire vrm through WS call chain"
```

---

## Task 4: Vitest 설정 분리 및 store 테스트 추가

**Files:**
- Create: `mods/desktopmate-bridge/vitest.config.ts`
- Create: `mods/desktopmate-bridge/vitest.e2e.config.ts`
- Modify: `mods/desktopmate-bridge/ui/src/store.test.ts`

- [ ] **Step 1: vitest.config.ts 생성 (unit 전용)**

`mods/desktopmate-bridge/vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    exclude: ["**/node_modules/**", "tests/e2e/**"],
  },
});
```

- [ ] **Step 2: vitest.e2e.config.ts 생성 (E2E 전용)**

`mods/desktopmate-bridge/vitest.e2e.config.ts`:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/e2e/**/*.test.ts"],
  },
});
```

- [ ] **Step 3: store.test.ts에 누락된 테스트 케이스 추가**

`mods/desktopmate-bridge/ui/src/store.test.ts` 파일에 아래 세 케이스를 추가한다 (기존 `describe` 블록 아래에 이어서):

```typescript
describe("store — appendStreamChunk isolation", () => {
  it("chunks for a different turnId do not affect unrelated messages", () => {
    useStore.getState().startStreaming("turn-A", "sess-1");
    useStore.getState().startStreaming("turn-B", "sess-1");
    useStore.getState().appendStreamChunk("turn-A", "Hello");
    useStore.getState().appendStreamChunk("turn-B", "World");
    const msgs = useStore.getState().messages;
    const msgA = msgs.find((m) => m.id === "turn-A")!;
    const msgB = msgs.find((m) => m.id === "turn-B")!;
    expect(msgA.content).toBe("Hello");
    expect(msgB.content).toBe("World");
  });
});

describe("store — session switch", () => {
  it("setActiveSession clears messages", () => {
    useStore.getState().addUserMessage("old message");
    expect(useStore.getState().messages).toHaveLength(1);
    useStore.getState().setActiveSession("new-session-id");
    expect(useStore.getState().messages).toHaveLength(0);
    expect(useStore.getState().activeSessionId).toBe("new-session-id");
  });
});

describe("store — restart-required status", () => {
  it("setConnectionStatus restart-required reflects in store", () => {
    useStore.getState().setConnectionStatus("restart-required");
    expect(useStore.getState().connectionStatus).toBe("restart-required");
  });
});
```

- [ ] **Step 4: 새 테스트 실행하여 통과 확인**

```bash
cd mods/desktopmate-bridge
pnpm test
```

Expected: 기존 테스트 + 새 3개 모두 PASS. 실패하면 store.ts의 `setActiveSession` 구현을 확인한다 (`messages: []` 초기화가 있어야 함).

- [ ] **Step 5: 커밋**

```bash
git add mods/desktopmate-bridge/vitest.config.ts \
        mods/desktopmate-bridge/vitest.e2e.config.ts \
        mods/desktopmate-bridge/ui/src/store.test.ts
git commit -m "test(desktopmate-bridge): add vitest config split and missing store test cases"
```

---

## Task 5: 전체 검증

- [ ] **Step 1: 전체 unit 테스트 통과 확인**

```bash
cd mods/desktopmate-bridge
pnpm test
```

Expected: 모든 테스트 PASS, `tests/e2e/` 관련 파일은 실행되지 않음.

- [ ] **Step 2: mock 서버 기동 확인**

별도 터미널에서:

```bash
cd mods/desktopmate-bridge
pnpm mock
```

Expected: mock 서버가 포트(기본 5500)에서 WebSocket 연결 대기 로그 출력.

- [ ] **Step 3: 파일 구조 최종 확인**

```bash
ls mods/desktopmate-bridge/vrm/
ls mods/desktopmate-bridge/commands/
ls mods/desktopmate-bridge/vitest*.config.ts
```

Expected:
```
vrm/Carlotta.vrm
commands/open-chat.ts
vitest.config.ts  vitest.e2e.config.ts
```

- [ ] **Step 4: 최종 커밋 (필요 시)**

변경 사항이 모두 커밋되었는지 확인:

```bash
git status
git log --oneline -5
```

---

## Known Limitations (TODOs)

- `@hmcs/elmer`가 함께 설치되어 있으면 캐릭터가 두 개 스폰된다. `@hmcs/elmer` 비설치 필요.
- VRM 선택 UI는 미구현 — `CHARACTER_ASSET_ID` 하드코딩 상태.
- ControlBar의 Drag 버튼 미구현.
- New Chat 시 실제 백엔드 세션 생성 미구현 (로컬 상태만 초기화).
