# Design: desktopmate-bridge MOD Completion

**Date:** 2026-03-20
**Branch:** `feature/desktopmate-bridge`
**Status:** Approved

## Summary

Complete the `mods/desktopmate-bridge` MOD by adding the missing pieces identified in gap analysis:
1. Carlotta VRM asset + spawn logic in service.ts
2. Fix `package.json` menus format and add `open-chat` bin command
3. Clarify test strategy (mock dev / real E2E)

The UI (ChatWindow, SessionSidebar, ControlBar, SettingsPanel, store, useSignals, api) is already implemented and requires no changes.

---

## 1. File Structure Changes

### New files
```
mods/desktopmate-bridge/
├── vrm/
│   └── Carlotta.vrm          # copied from /home/spow12/codes/2025_lower/DesktopMatePlus/Carlotta.vrm
└── commands/
    └── open-chat.ts          # bin command: opens chat WebView
```

### Modified files
```
mods/desktopmate-bridge/
├── package.json              # menus format fix + Carlotta asset + open-chat bin
└── service.ts                # add Vrm.spawn() + animation state machine
```

---

## 2. package.json Changes

### Assets — add Carlotta VRM
```json
"homunculus": {
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
}
```

### Menus — fix format (current: `label/asset`, required: `id/text/command`)

`menus` is nested inside the `homunculus` object:

```json
"homunculus": {
  "menus": [
    {
      "id": "open-desktopmate-chat",
      "text": "Chat",
      "command": "open-chat"
    }
  ]
}
```

### Bin — add open-chat command
```json
"bin": {
  "open-chat": "commands/open-chat.ts"
}
```

---

## 3. commands/open-chat.ts

Opens the chat WebView anchored to the right of the character, plays the open sound effect.

> **Note:** This command intentionally does **not** call `input.parseMenu()`. The chat UI is a global panel (not per-VRM), so `linkedVrm` is not needed. This diverges from per-VRM menu commands like voicevox's `open-settings.ts`.

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

---

## 4. service.ts Changes

### Remove `config.homunculus.entity_id`
The `entity_id` field in `config.yaml` / `Config` interface is removed. The VRM entity is obtained dynamically from `Vrm.spawn()` and used directly.

### Import paths

All service.ts imports:
- `@hmcs/sdk` — `Vrm`, `TransformArgs`, `type TimelineKeyframe`, `signals`, `sleep`, `repeat`, `preferences`
- `@hmcs/sdk/rpc` — `rpc` (NOT from `@hmcs/sdk` main entry)

### Add VRM spawn + animation state machine

`spawnCharacter()` is defined as a top-level async function in service.ts. It returns the spawned `Vrm` instance which is then passed into the WebSocket message handler via closure.

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

### Wire VRM entity to TTS handler — full call chain

`vrm` must propagate through the entire call chain. All affected function signatures:

```typescript
// handleTtsChunk: config → vrm
async function handleTtsChunk(
  msg: { sequence: number; text: string; emotion: string; audio_base64: string | null; keyframes: TimelineKeyframe[] },
  vrm: Vrm,  // replaces config
): Promise<void>

// handleMessage: add vrm parameter
async function handleMessage(event: MessageEvent, config: Config, vrm: Vrm): Promise<void>

// connectWithRetry: add vrm parameter
async function connectWithRetry(config: Config, vrm: Vrm, retryState: RetryState): Promise<void>
// Inside: ws.addEventListener("message", (event) => { handleMessage(event, config, vrm) })

// handleClose: add vrm, propagate to reconnect
async function handleClose(event: CloseEvent, config: Config, vrm: Vrm, retryState: RetryState): Promise<void>
// Inside: await connectWithRetry(config, vrm, { attempts: retryState.attempts + 1 })

// connectAndServe: add vrm
async function connectAndServe(config: Config, vrm: Vrm): Promise<void>
// Inside: await connectWithRetry(config, vrm, { attempts: 0 })
```

### Entry point

`connectAndServe` uses async event callbacks (WebSocket `addEventListener`) and does **not** block — it returns after setup. The entry point sequences the calls to make the flow explicit:

```typescript
// --- entry point ---
const config = loadConfig();
const vrm = await spawnCharacter();        // VRM spawned first
connectAndServe(config, vrm);              // fire-and-forget: WS + RPC
```

---

## 5. config.yaml — Remove entity_id

```yaml
# Before
homunculus:
  entity_id: 0
  api_url: http://localhost:3100

# After
homunculus:
  api_url: http://localhost:3100
```

---

## 6. Toggle Behavior (No Change Required)

The existing `{showX && <Component />}` conditional rendering is correct because:
- `useSignals()` lives in `App.tsx` — signals flow to Zustand store regardless of toggle state
- Zustand store persists all state across mount/unmount cycles
- UILayout.md scenarios are satisfied: actions taken while a panel is hidden are reflected in the store, and visible when the panel is re-opened

---

## 7. Test Strategy

| Level | Tool | Command | Requires |
|-------|------|---------|----------|
| Unit | Vitest | `pnpm test` | nothing |
| Dev / integration | mock-homunculus.ts | `pnpm mock` | nothing |
| E2E | real FastAPI + NanoClaw | `pnpm test:e2e` | both services running |

### New unit test cases (store.test.ts)
- `appendStreamChunk` accumulates correctly across multiple chunks
- `setActiveSession` clears messages (session switch)
- `setConnectionStatus("restart-required")` reflects in store

### E2E 격리 — 설정 파일 분리

Vitest의 `exclude`는 CLI에서 경로를 명시해도 적용되므로, `vitest.config.ts`에서 e2e를 exclude하면 `vitest run tests/e2e`도 "No test files found" 에러가 난다. 따라서 unit/e2e 설정 파일을 분리한다.

**`vitest.config.ts`** — unit 테스트 전용 (기본 `pnpm test`):
```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    exclude: ["**/node_modules/**", "tests/e2e/**"],
  },
});
```

**`vitest.e2e.config.ts`** — E2E 전용 (`pnpm test:e2e`):
```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/e2e/**/*.test.ts"],
  },
});
```

**`package.json` scripts:**
```json
"test": "vitest run",
"test:e2e": "FASTAPI_URL=http://localhost:5500 vitest run -c vitest.e2e.config.ts"
```

`pnpm test`는 unit 테스트만 실행하고, `pnpm test:e2e`는 실제 백엔드가 필요한 E2E만 실행한다.

### Mock server
`scripts/mock-homunculus.ts` is already implemented. Used during development and CI for integration tests.

---

## 8. Out of Scope (TODOs)

- **VRM selection UI** — user picks VRM from settings panel. `CHARACTER_ASSET_ID` is hardcoded for now.
- **@hmcs/elmer conflict** — if `@hmcs/elmer` is also installed, two characters will spawn. Documented as a known limitation; user should uninstall elmer when using desktopmate-bridge.
- **Drag button** in ControlBar (mentioned in UILayout.md) — deferred.
- **New Chat via RPC** — creating a new session from the ControlBar currently only clears local state; actual backend session creation is deferred.
