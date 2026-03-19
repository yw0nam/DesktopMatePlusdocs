# desktopmate-bridge MOD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a desktop-homunculus MOD that bridges the FastAPI backend WebSocket to the engine's VRM speech/timeline API and exposes a React WebView chat UI with session management.

**Architecture:** A `service.ts` process connects to FastAPI over WebSocket, translates `tts_chunk` events into homunculus engine REST calls (`POST localhost:3100/vrm/{entity_id}/speech/timeline`), and broadcasts status Signals (SSE) to a React WebView. The React UI talks directly to FastAPI REST for STM session management and sends chat messages through `service.ts` RPC.

**Tech Stack:** TypeScript (tsx, no build step for service), React 19 + Vite + `vite-plugin-singlefile`, Zustand, Tailwind CSS v4, `@hmcs/sdk`, `@hmcs/ui`, `zod`, `js-yaml`

---

## File Map

| File | Responsibility |
|------|---------------|
| `desktop-homunculus/mods/desktopmate-bridge/package.json` | MOD manifest: service, menus, assets, deps |
| `desktop-homunculus/mods/desktopmate-bridge/config.yaml` | Default config (ws_url, token, user_id, agent_id, entity_id, api_url) |
| `desktop-homunculus/mods/desktopmate-bridge/service.ts` | WebSocket bridge + homunculus engine control + RPC server |
| `desktop-homunculus/mods/desktopmate-bridge/commands/open-chat.ts` | Bin command: opens the chat WebView via SDK `webviews.open` |
| `desktop-homunculus/mods/desktopmate-bridge/scripts/mock-homunculus.ts` | Mock localhost:3100 for integration tests |
| `desktop-homunculus/mods/desktopmate-bridge/ui/index.html` | Vite entry HTML |
| `desktop-homunculus/mods/desktopmate-bridge/ui/vite.config.ts` | Vite + singlefile config |
| `desktop-homunculus/mods/desktopmate-bridge/ui/tsconfig.json` | TypeScript config for UI |
| `desktop-homunculus/mods/desktopmate-bridge/ui/src/main.tsx` | React root mount |
| `desktop-homunculus/mods/desktopmate-bridge/ui/src/App.tsx` | Root layout: three panels + ControlBar |
| `desktop-homunculus/mods/desktopmate-bridge/ui/src/store.ts` | Zustand store: messages, sessions, activeSessionId, isTyping, connectionStatus, settings |
| `desktop-homunculus/mods/desktopmate-bridge/ui/src/components/SessionSidebar.tsx` | Session list, rename, delete, new chat |
| `desktop-homunculus/mods/desktopmate-bridge/ui/src/components/ChatWindow.tsx` | Message list + typing indicator |
| `desktop-homunculus/mods/desktopmate-bridge/ui/src/components/SettingsPanel.tsx` | user_id / agent_id / FastAPI URL inputs + Save to localStorage |
| `desktop-homunculus/mods/desktopmate-bridge/ui/src/components/ControlBar.tsx` | Drag handle, input, Send/Stop, toggle buttons |
| `desktop-homunculus/mods/desktopmate-bridge/ui/src/hooks/useSignals.ts` | Subscribe to dm-* Signals from service.ts |

---

## Phase 1: service.ts — WebSocket bridge + engine control

### Task 1: Package scaffold + config.yaml

**Files:**
- Create: `desktop-homunculus/mods/desktopmate-bridge/package.json`
- Create: `desktop-homunculus/mods/desktopmate-bridge/config.yaml`

**Context:** Follow the voicevox mod pattern at `desktop-homunculus/mods/voicevox/package.json`. The engine runs on `localhost:3100`, service is started by the engine using `node --import tsx`.

- [ ] **Step 1: Create package.json**

```json
{
  "name": "@hmcs/desktopmate-bridge",
  "version": "0.1.0",
  "description": "FastAPI backend bridge for Desktop Homunculus — WebSocket chat + TTS",
  "license": "MIT",
  "type": "module",
  "scripts": {
    "build": "pnpm exec vite build ui",
    "dev": "pnpm exec vite dev ui",
    "mock": "node --import tsx scripts/mock-homunculus.ts"
  },
  "bin": {
    "open-chat": "commands/open-chat.ts"
  },
  "homunculus": {
    "service": "service.ts",
    "menus": [
      {
        "id": "open-chat",
        "text": "Chat",
        "command": "open-chat"
      }
    ],
    "assets": {
      "desktopmate-bridge:ui": {
        "path": "ui/dist/index.html",
        "type": "html",
        "description": "DesktopMate+ chat UI"
      }
    }
  },
  "dependencies": {
    "@hmcs/sdk": "workspace:*",
    "@hmcs/ui": "workspace:*",
    "js-yaml": "^4.1.0",
    "react": "^19.2.4",
    "react-dom": "^19.2.4",
    "zustand": "^5.0.0",
    "zod": "^3.25.76"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.2.1",
    "@types/js-yaml": "^4.0.9",
    "@types/node": "^25.3.3",
    "@types/react": "^19.2.14",
    "@types/react-dom": "^19.2.3",
    "@vitejs/plugin-react-swc": "^4.2.3",
    "tailwindcss": "^4.2.1",
    "typescript": "^5.9.3",
    "vite": "^6.4.1",
    "vite-plugin-singlefile": "^2.3.0"
  }
}
```

Save to `desktop-homunculus/mods/desktopmate-bridge/package.json`.

- [ ] **Step 2: Create config.yaml**

```yaml
fastapi:
  ws_url: "ws://127.0.0.1:5500/v1/chat/stream"
  token: ""
  user_id: "desktop-user"
  agent_id: "persona-agent"

homunculus:
  entity_id: 1
  api_url: "http://127.0.0.1:3100"
```

Save to `desktop-homunculus/mods/desktopmate-bridge/config.yaml`.

- [ ] **Step 3: Create commands/open-chat.ts**

This bin command is invoked by the engine when the user clicks the "Chat" menu item. It opens the WebView using the SDK's `webviews` namespace.

```typescript
import { webviews } from "@hmcs/sdk";
await webviews.open("desktopmate-bridge:ui");
```

Save to `desktop-homunculus/mods/desktopmate-bridge/commands/open-chat.ts`.

- [ ] **Step 4: Verify mod is discovered**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus
pnpm install
```

Expected: no errors, `@hmcs/desktopmate-bridge` appears in workspace.

- [ ] **Step 5: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/package.json mods/desktopmate-bridge/config.yaml mods/desktopmate-bridge/commands/open-chat.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): scaffold MOD package and config"
```

---

### Task 2: Config loader

**Files:**
- Create: `desktop-homunculus/mods/desktopmate-bridge/service.ts` (initial — config loading only)

**Context:** The service is a long-running Node.js process started by the engine. It must load `config.yaml` from `__dirname` (using `import.meta.url`). No build step; tsx runs it directly.

- [ ] **Step 1: Write config types and loader in service.ts**

```typescript
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import yaml from "js-yaml";

interface BridgeConfig {
  fastapi: {
    ws_url: string;
    token: string;
    user_id: string;
    agent_id: string;
  };
  homunculus: {
    entity_id: number;
    api_url: string;
  };
}

function loadConfig(): BridgeConfig {
  const dir = dirname(fileURLToPath(import.meta.url));
  const raw = readFileSync(join(dir, "config.yaml"), "utf-8");
  return yaml.load(raw) as BridgeConfig;
}

const config = loadConfig();
console.log("[desktopmate-bridge] config loaded", JSON.stringify(config));
```

- [ ] **Step 2: Run manually to verify config loads**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
node --import tsx service.ts
```

Expected output: `[desktopmate-bridge] config loaded {"fastapi":{"ws_url":"ws://...`

- [ ] **Step 3: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/service.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add config loader"
```

---

### Task 3: Signal broadcasting helpers

**Files:**
- Modify: `desktop-homunculus/mods/desktopmate-bridge/service.ts`

**Context:** The SDK's `signals.send()` calls `POST localhost:3100/signals/{signal}`. Signal names are `dm-typing-start`, `dm-tts-chunk`, `dm-message-complete`, `dm-connection-status`. These are the Signals the React UI subscribes to. Import `signals` from `@hmcs/sdk`.

- [ ] **Step 1: Add signal broadcast functions to service.ts**

Add after the config loader:

```typescript
import { signals } from "@hmcs/sdk";

interface DmConnectionStatus {
  status: "connecting" | "connected" | "disconnected" | "restart-required";
}

interface DmTypingStart {
  session_id: string;
}

interface DmTtsChunk {
  session_id: string;
  chunk_index: number;
}

interface DmMessageComplete {
  session_id: string;
  content: string;
}

async function broadcastConnectionStatus(status: DmConnectionStatus["status"]): Promise<void> {
  await signals.send<DmConnectionStatus>("dm-connection-status", { status });
}

async function broadcastTypingStart(session_id: string): Promise<void> {
  await signals.send<DmTypingStart>("dm-typing-start", { session_id });
}

async function broadcastTtsChunk(session_id: string, chunk_index: number): Promise<void> {
  await signals.send<DmTtsChunk>("dm-tts-chunk", { session_id, chunk_index });
}

async function broadcastMessageComplete(session_id: string, content: string): Promise<void> {
  await signals.send<DmMessageComplete>("dm-message-complete", { session_id, content });
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus
pnpm check-types 2>&1 | grep desktopmate-bridge
```

Expected: no errors for desktopmate-bridge.

- [ ] **Step 3: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/service.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add signal broadcast helpers"
```

---

### Task 4: Homunculus engine speech caller

**Files:**
- Modify: `desktop-homunculus/mods/desktopmate-bridge/service.ts`

**Context:** On `tts_chunk` events from FastAPI, call `POST localhost:3100/vrm/{entity_id}/speech/timeline` with `{ wav: <base64>, keyframes: [...] }`. FastAPI sends base64-encoded WAV and keyframes in `tts_chunk`. The engine API URL comes from `config.homunculus.api_url`.

- [ ] **Step 1: Add speech timeline poster**

```typescript
interface TtsChunkPayload {
  session_id: string;
  chunk_index: number;
  wav: string;        // base64-encoded WAV
  keyframes: Array<{ duration: number; targets?: Record<string, number> }>;
}

async function postSpeechTimeline(payload: TtsChunkPayload): Promise<void> {
  const url = `${config.homunculus.api_url}/vrm/${config.homunculus.entity_id}/speech/timeline`;
  const wavBytes = Buffer.from(payload.wav, "base64");
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      wav: Array.from(wavBytes),
      keyframes: payload.keyframes,
    }),
  });
  if (!response.ok) {
    const text = await response.text().catch(() => "(unreadable)");
    throw new Error(`speech/timeline failed (${response.status}): ${text}`);
  }
}
```

- [ ] **Step 2: Manually test against mock (mock server is in Task 12; skip run for now)**

Verify TypeScript compiles:

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus
pnpm check-types 2>&1 | grep desktopmate-bridge
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/service.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add speech timeline poster"
```

---

### Task 5: WebSocket event handler

**Files:**
- Modify: `desktop-homunculus/mods/desktopmate-bridge/service.ts`

**Context:** The FastAPI WebSocket sends JSON events. Event types: `authorize_success`, `authorize_error`, `stream_start`, `stream_token` (ignored), `tts_chunk`, `stream_end`, `ping`, `error`. On connect, send `{ type: "authorize", token: config.fastapi.token }`. On `ping`, reply `{ type: "pong" }`. Use the native `WebSocket` available in Node.js 22+.

- [ ] **Step 1: Add FastAPI event types**

```typescript
type FastApiEvent =
  | { type: "authorize_success" }
  | { type: "authorize_error"; message: string }
  | { type: "stream_start"; session_id: string }
  | { type: "stream_token"; session_id: string; token: string }
  | { type: "tts_chunk"; session_id: string; chunk_index: number; wav: string; keyframes: Array<{ duration: number; targets?: Record<string, number> }> }
  | { type: "stream_end"; session_id: string; content: string }
  | { type: "ping" }
  | { type: "error"; message: string };
```

- [ ] **Step 2: Add event handler function**

```typescript
async function handleFastapiEvent(
  ws: WebSocket,
  event: FastApiEvent,
): Promise<void> {
  switch (event.type) {
    case "authorize_success":
      console.log("[desktopmate-bridge] authorized");
      await broadcastConnectionStatus("connected");
      break;
    case "authorize_error":
      console.error("[desktopmate-bridge] auth error:", event.message);
      await broadcastConnectionStatus("disconnected");
      break;
    case "stream_start":
      await broadcastTypingStart(event.session_id);
      break;
    case "stream_token":
      // intentionally ignored
      break;
    case "tts_chunk":
      await postSpeechTimeline(event);
      await broadcastTtsChunk(event.session_id, event.chunk_index);
      break;
    case "stream_end":
      await broadcastMessageComplete(event.session_id, event.content);
      break;
    case "ping":
      ws.send(JSON.stringify({ type: "pong" }));
      break;
    case "error":
      console.error("[desktopmate-bridge] FastAPI error:", event.message);
      break;
  }
}
```

- [ ] **Step 3: Verify types compile**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus
pnpm check-types 2>&1 | grep desktopmate-bridge
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/service.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add FastAPI event handler"
```

---

### Task 6: WebSocket connection with reconnect logic

**Files:**
- Modify: `desktop-homunculus/mods/desktopmate-bridge/service.ts`

**Context:** Connect to FastAPI WS. Reconnect up to 3 times on disconnect/error with linear backoff (1s, 2s, 3s). After 3 failures, broadcast `status: "restart-required"` and stop retrying. Send `{ type: "authorize", token }` immediately on open.

- [ ] **Step 1: Add connection manager**

```typescript
const MAX_RETRIES = 3;
let retryCount = 0;
let activeWs: WebSocket | null = null;

function connectToFastApi(): void {
  console.log(`[desktopmate-bridge] connecting (attempt ${retryCount + 1})`);
  broadcastConnectionStatus("connecting").catch(() => {});

  const ws = new WebSocket(config.fastapi.ws_url);
  activeWs = ws;

  ws.addEventListener("open", () => {
    retryCount = 0;
    ws.send(JSON.stringify({ type: "authorize", token: config.fastapi.token }));
  });

  ws.addEventListener("message", (event) => {
    let parsed: FastApiEvent;
    try {
      parsed = JSON.parse(event.data as string) as FastApiEvent;
    } catch {
      console.error("[desktopmate-bridge] invalid JSON from FastAPI");
      return;
    }
    handleFastapiEvent(ws, parsed).catch((err) => {
      console.error("[desktopmate-bridge] event handler error:", err);
    });
  });

  ws.addEventListener("close", () => scheduleReconnect());
  ws.addEventListener("error", (err) => {
    console.error("[desktopmate-bridge] WS error:", err);
  });
}

function scheduleReconnect(): void {
  if (retryCount >= MAX_RETRIES) {
    console.error("[desktopmate-bridge] max retries reached — restart required");
    broadcastConnectionStatus("restart-required").catch(() => {});
    return;
  }
  const delaySecs = retryCount + 1;
  retryCount++;
  broadcastConnectionStatus("disconnected").catch(() => {});
  console.log(`[desktopmate-bridge] reconnecting in ${delaySecs}s`);
  setTimeout(() => connectToFastApi(), delaySecs * 1000);
}
```

- [ ] **Step 2: Add interrupt function and wire start**

```typescript
function interruptStream(): void {
  if (activeWs?.readyState === WebSocket.OPEN) {
    activeWs.send(JSON.stringify({ type: "interrupt" }));
  }
}

// Start connection
connectToFastApi();
```

- [ ] **Step 3: Verify service.ts runs without crashing when FastAPI is absent**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
node --import tsx service.ts
```

Expected: connects, gets ECONNREFUSED, schedules reconnect. After 3 retries, logs "restart required". No crash. Ctrl-C to stop.

- [ ] **Step 4: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/service.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add WebSocket connection with reconnect"
```

---

### Task 7: RPC server — sendMessage + interruptStream

**Files:**
- Modify: `desktop-homunculus/mods/desktopmate-bridge/service.ts`

**Context:** Expose two RPC methods using `rpc.serve` from `@hmcs/sdk/rpc`. `sendMessage` sends `{ type: "message", content, session_id?, user_id, agent_id }` over the active WebSocket. `interruptStream` sends `{ type: "interrupt" }`. Requires env vars `HMCS_RPC_PORT`, `HMCS_MOD_NAME`, `HMCS_PORT`.

- [ ] **Step 1: Add RPC server at bottom of service.ts**

```typescript
import { z } from "zod";
import { rpc } from "@hmcs/sdk/rpc";

await rpc.serve({
  methods: {
    sendMessage: rpc.method({
      description: "Send a chat message to FastAPI backend",
      timeout: 30_000,
      input: z.object({
        content: z.string().min(1),
        session_id: z.string().optional(),
      }),
      handler: async ({ content, session_id }) => {
        if (!activeWs || activeWs.readyState !== WebSocket.OPEN) {
          throw new Error("WebSocket not connected");
        }
        activeWs.send(
          JSON.stringify({
            type: "message",
            content,
            session_id,
            user_id: config.fastapi.user_id,
            agent_id: config.fastapi.agent_id,
          }),
        );
        return { sent: true };
      },
    }),

    interruptStream: rpc.method({
      description: "Interrupt the current AI response stream",
      handler: async () => {
        interruptStream();
        return { interrupted: true };
      },
    }),
  },
});
```

- [ ] **Step 2: Verify RPC server starts with env vars**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
HMCS_RPC_PORT=9101 HMCS_MOD_NAME=desktopmate-bridge node --import tsx service.ts
```

Expected: starts, attempts WS connect, attempts RPC registration with engine. Ctrl-C to stop.

- [ ] **Step 3: Verify TypeScript types**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus
pnpm check-types 2>&1 | grep desktopmate-bridge
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/service.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add RPC server with sendMessage and interruptStream"
```

---

## Phase 2: React UI scaffold + Zustand store + Settings Panel

### Task 8: Vite UI scaffold

**Files:**
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/index.html`
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/vite.config.ts`
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/tsconfig.json`
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/src/main.tsx`
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/src/App.tsx` (skeleton)

**Context:** Follow `mods/voicevox/ui/` exactly. Use `vite-plugin-singlefile` to bundle to a single `index.html`. The WebView runs with `disable-web-security` so it can fetch `localhost:5500` directly.

- [ ] **Step 1: Create index.html**

```html
<!doctype html>
<html lang="en" class="dark">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>DesktopMate+ Chat</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 2: Create vite.config.ts**

```typescript
import react from "@vitejs/plugin-react-swc";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

export default defineConfig({
  plugins: [react(), tailwindcss(), viteSingleFile()],
  resolve: {
    dedupe: ["react", "react-dom", "react/jsx-runtime"],
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    assetsInlineLimit: 100000,
    cssCodeSplit: false,
  },
});
```

- [ ] **Step 3: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  },
  "include": ["src"]
}
```

- [ ] **Step 4: Create src/main.tsx**

```tsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
```

- [ ] **Step 5: Create src/App.tsx (skeleton)**

```tsx
export function App() {
  return (
    <div className="flex h-screen w-screen bg-black/80 text-white text-sm">
      <p>desktopmate-bridge loading…</p>
    </div>
  );
}
```

- [ ] **Step 6: Build to verify Vite works**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
pnpm build
```

Expected: `ui/dist/index.html` is created with no errors.

- [ ] **Step 7: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/ui/
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): scaffold React UI with Vite"
```

---

### Task 9: Zustand store

**Files:**
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/src/store.ts`

**Context:** Central store for all UI state. Settings are persisted to `localStorage` via Zustand's `persist` middleware. The `fastapiUrl` is used by all direct REST calls from the UI. `activeSessionId` is `null` until the user selects or creates a session.

- [ ] **Step 1: Write the store**

```typescript
import { create } from "zustand";
import { persist } from "zustand/middleware";

export interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  timestamp: number;
}

export interface Session {
  session_id: string;
  name: string;
  created_at: string;
  updated_at: string;
}

export interface Settings {
  userId: string;
  agentId: string;
  fastapiUrl: string;
}

export type ConnectionStatus =
  | "connecting"
  | "connected"
  | "disconnected"
  | "restart-required";

interface BridgeState {
  messages: Message[];
  sessions: Session[];
  activeSessionId: string | null;
  isTyping: boolean;
  connectionStatus: ConnectionStatus;
  settings: Settings;
  // actions
  addMessage: (msg: Message) => void;
  setSessions: (sessions: Session[]) => void;
  setActiveSessionId: (id: string | null) => void;
  setIsTyping: (v: boolean) => void;
  setConnectionStatus: (s: ConnectionStatus) => void;
  updateSettings: (patch: Partial<Settings>) => void;
  clearMessages: () => void;
}

const DEFAULT_SETTINGS: Settings = {
  userId: "desktop-user",
  agentId: "persona-agent",
  fastapiUrl: "http://127.0.0.1:5500",
};

export const useBridgeStore = create<BridgeState>()(
  persist(
    (set) => ({
      messages: [],
      sessions: [],
      activeSessionId: null,
      isTyping: false,
      connectionStatus: "connecting",
      settings: DEFAULT_SETTINGS,
      addMessage: (msg) => set((s) => ({ messages: [...s.messages, msg] })),
      setSessions: (sessions) => set({ sessions }),
      setActiveSessionId: (id) => set({ activeSessionId: id, messages: [] }),
      setIsTyping: (v) => set({ isTyping: v }),
      setConnectionStatus: (connectionStatus) => set({ connectionStatus }),
      updateSettings: (patch) =>
        set((s) => ({ settings: { ...s.settings, ...patch } })),
      clearMessages: () => set({ messages: [] }),
    }),
    {
      name: "desktopmate-bridge-settings",
      partialize: (s) => ({ settings: s.settings }),
    },
  ),
);
```

- [ ] **Step 2: Build to verify**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
pnpm build
```

Expected: builds successfully.

- [ ] **Step 3: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/ui/src/store.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add Zustand store"
```

---

### Task 10: useSignals hook + SettingsPanel

**Files:**
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/src/hooks/useSignals.ts`
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/src/components/SettingsPanel.tsx`

**Context:** `useSignals` subscribes to `dm-*` SSE Signals from the engine (`localhost:3100/signals/{name}`). Use the `EventSource` browser API (not the SDK's Node EventSource). `SettingsPanel` reads/writes settings via Zustand and `localStorage`.

- [ ] **Step 1: Write useSignals.ts**

```typescript
import { useEffect } from "react";
import { useBridgeStore, type ConnectionStatus } from "../store";

const ENGINE_URL = "http://127.0.0.1:3100";

interface DmConnectionStatus { status: ConnectionStatus }
interface DmTypingStart { session_id: string }
interface DmMessageComplete { session_id: string; content: string }

function makeSignalUrl(name: string): string {
  return `${ENGINE_URL}/signals/${name}`;
}

function parseEvent<T>(data: string): T | null {
  try {
    return JSON.parse(data) as T;
  } catch {
    return null;
  }
}

export function useSignals(): void {
  const setConnectionStatus = useBridgeStore((s) => s.setConnectionStatus);
  const setIsTyping = useBridgeStore((s) => s.setIsTyping);
  const addMessage = useBridgeStore((s) => s.addMessage);

  useEffect(() => {
    const connectionEs = new EventSource(makeSignalUrl("dm-connection-status"));
    connectionEs.addEventListener("message", (e) => {
      const payload = parseEvent<DmConnectionStatus>(e.data);
      if (payload) setConnectionStatus(payload.status);
    });

    const typingEs = new EventSource(makeSignalUrl("dm-typing-start"));
    typingEs.addEventListener("message", (e) => {
      const payload = parseEvent<DmTypingStart>(e.data);
      if (payload) setIsTyping(true);
    });

    const completeEs = new EventSource(makeSignalUrl("dm-message-complete"));
    completeEs.addEventListener("message", (e) => {
      const payload = parseEvent<DmMessageComplete>(e.data);
      if (payload) {
        setIsTyping(false);
        addMessage({
          id: crypto.randomUUID(),
          role: "assistant",
          content: payload.content,
          timestamp: Date.now(),
        });
      }
    });

    return () => {
      connectionEs.close();
      typingEs.close();
      completeEs.close();
    };
  }, [setConnectionStatus, setIsTyping, addMessage]);
}
```

- [ ] **Step 2: Write SettingsPanel.tsx**

```tsx
import { useState } from "react";
import { useBridgeStore } from "../store";

export function SettingsPanel({ onClose }: { onClose: () => void }) {
  const { settings, updateSettings } = useBridgeStore();
  const [draft, setDraft] = useState(settings);
  const [saved, setSaved] = useState(false);

  function handleSave() {
    updateSettings(draft);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  }

  return (
    <div className="flex flex-col gap-3 p-4 h-full bg-black/60 backdrop-blur-sm border-l border-white/10">
      <div className="flex items-center justify-between">
        <h2 className="text-white font-semibold">Settings</h2>
        <button onClick={onClose} className="text-white/50 hover:text-white text-xs">✕</button>
      </div>

      <SettingsField
        label="User ID"
        value={draft.userId}
        onChange={(v) => setDraft({ ...draft, userId: v })}
      />
      <SettingsField
        label="Agent ID"
        value={draft.agentId}
        onChange={(v) => setDraft({ ...draft, agentId: v })}
      />
      <SettingsField
        label="FastAPI REST URL"
        value={draft.fastapiUrl}
        onChange={(v) => setDraft({ ...draft, fastapiUrl: v })}
      />

      <button
        onClick={handleSave}
        className="mt-2 px-3 py-1.5 bg-white/10 hover:bg-white/20 rounded text-white text-xs"
      >
        {saved ? "Saved!" : "Save"}
      </button>
    </div>
  );
}

function SettingsField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <label className="flex flex-col gap-1 text-white/70 text-xs">
      {label}
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="bg-white/5 border border-white/15 rounded px-2 py-1 text-white text-xs outline-none focus:border-white/40"
      />
    </label>
  );
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
pnpm build
```

Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/ui/src/hooks/ mods/desktopmate-bridge/ui/src/components/SettingsPanel.tsx
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add useSignals hook and SettingsPanel"
```

---

## Phase 3: Chat Window + Session Sidebar + ControlBar + App layout

### Task 11: ChatWindow + ControlBar

**Files:**
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/src/components/ChatWindow.tsx`
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/src/components/ControlBar.tsx`

**Context:** `ChatWindow` shows `messages` from the store and a typing indicator when `isTyping` is true. `ControlBar` has: drag handle (`data-hmcs-drag`), text input, Send/Stop button (Send = call RPC `sendMessage`, Stop = call RPC `interruptStream`), and toggle buttons for History/Sessions/Settings panels. RPC calls go through `fetch` to the engine: `POST localhost:3100/mods/desktopmate-bridge/bin/{method}` — but actually the correct RPC client call is `rpc.call` from `@hmcs/sdk/rpc-client`. Import from `@hmcs/sdk/rpc` (conditional export resolves to browser-safe client in bundler).

- [ ] **Step 1: Write ChatWindow.tsx**

```tsx
import { useEffect, useRef } from "react";
import { useBridgeStore } from "../store";

export function ChatWindow() {
  const messages = useBridgeStore((s) => s.messages);
  const isTyping = useBridgeStore((s) => s.isTyping);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isTyping]);

  return (
    <div className="flex flex-col flex-1 overflow-y-auto gap-2 p-3">
      {messages.map((msg) => (
        <MessageBubble key={msg.id} role={msg.role} content={msg.content} timestamp={msg.timestamp} />
      ))}
      {isTyping && <TypingIndicator />}
      <div ref={bottomRef} />
    </div>
  );
}

function MessageBubble({
  role,
  content,
  timestamp,
}: {
  role: "user" | "assistant";
  content: string;
  timestamp: number;
}) {
  const time = new Date(timestamp).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });

  return (
    <div className={`flex flex-col gap-0.5 ${role === "user" ? "items-end" : "items-start"}`}>
      <div
        className={`max-w-[80%] rounded-lg px-3 py-2 text-xs text-white whitespace-pre-wrap ${
          role === "user" ? "bg-white/20" : "bg-white/10"
        }`}
      >
        {content}
      </div>
      <span className="text-white/30 text-[10px]">{time}</span>
    </div>
  );
}

function TypingIndicator() {
  return (
    <div className="flex items-start">
      <div className="bg-white/10 rounded-lg px-3 py-2 text-xs text-white/60 italic">
        typing…
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Write ControlBar.tsx**

```tsx
import { useState, useCallback } from "react";
import { rpc } from "@hmcs/sdk/rpc";
import { useBridgeStore } from "../store";

interface ControlBarProps {
  onToggleSessions: () => void;
  onToggleSettings: () => void;
  showSessions: boolean;
  showSettings: boolean;
}

export function ControlBar({
  onToggleSessions,
  onToggleSettings,
  showSessions,
  showSettings,
}: ControlBarProps) {
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const { isTyping, activeSessionId, settings, addMessage } = useBridgeStore();

  const handleSend = useCallback(async () => {
    const content = input.trim();
    if (!content || sending) return;
    setInput("");
    setSending(true);
    addMessage({ id: crypto.randomUUID(), role: "user", content, timestamp: Date.now() });
    try {
      await rpc.call({ modName: "desktopmate-bridge", method: "sendMessage", body: { content, session_id: activeSessionId ?? undefined } });
    } catch (err) {
      console.error("sendMessage failed:", err);
    } finally {
      setSending(false);
    }
  }, [input, sending, activeSessionId, addMessage]);

  const handleStop = useCallback(async () => {
    try {
      await rpc.call({ modName: "desktopmate-bridge", method: "interruptStream", body: {} });
    } catch (err) {
      console.error("interruptStream failed:", err);
    }
  }, []);

  return (
    <div className="flex items-center gap-2 px-2 py-2 border-t border-white/10 bg-black/40">
      <div data-hmcs-drag className="cursor-grab text-white/20 select-none px-1">⠿</div>
      <input
        type="text"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSend(); } }}
        placeholder="Message…"
        className="flex-1 bg-white/5 border border-white/10 rounded px-2 py-1 text-xs text-white outline-none focus:border-white/30"
      />
      {isTyping ? (
        <button onClick={handleStop} className="px-2 py-1 bg-red-500/20 hover:bg-red-500/40 text-red-300 text-xs rounded">
          Stop
        </button>
      ) : (
        <button onClick={handleSend} disabled={!input.trim() || sending} className="px-2 py-1 bg-white/10 hover:bg-white/20 text-white text-xs rounded disabled:opacity-40">
          Send
        </button>
      )}
      <button onClick={onToggleSessions} className={`px-2 py-1 text-xs rounded ${showSessions ? "bg-white/20 text-white" : "text-white/40 hover:text-white"}`} title="Sessions">
        ☰
      </button>
      <button onClick={onToggleSettings} className={`px-2 py-1 text-xs rounded ${showSettings ? "bg-white/20 text-white" : "text-white/40 hover:text-white"}`} title="Settings">
        ⚙
      </button>
    </div>
  );
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
pnpm build
```

Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/ui/src/components/ChatWindow.tsx mods/desktopmate-bridge/ui/src/components/ControlBar.tsx
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add ChatWindow and ControlBar"
```

---

### Task 12: SessionSidebar (STM REST calls)

**Files:**
- Create: `desktop-homunculus/mods/desktopmate-bridge/ui/src/components/SessionSidebar.tsx`

**Context:** Session data comes from `GET /v1/stm/sessions` on the FastAPI REST URL (`settings.fastapiUrl`). After `stream_end` (dm-message-complete signal), the parent App calls `getSessions()` to refresh. Session rename = `PATCH /v1/stm/sessions/{session_id}/metadata`. Delete = `DELETE /v1/stm/sessions/{session_id}`. New Chat = set `activeSessionId` to null and clear messages (a new session_id is assigned by FastAPI on the next message).

- [ ] **Step 1: Write SessionSidebar.tsx**

```tsx
import { useState } from "react";
import { useBridgeStore, type Session } from "../store";

interface SessionSidebarProps {
  onClose: () => void;
  onRefreshSessions: () => Promise<void>;
}

export function SessionSidebar({ onClose, onRefreshSessions }: SessionSidebarProps) {
  const { sessions, activeSessionId, settings, setActiveSessionId, clearMessages, setSessions } =
    useBridgeStore();

  return (
    <div className="flex flex-col w-52 h-full bg-black/60 backdrop-blur-sm border-r border-white/10">
      <div className="flex items-center justify-between px-3 py-2 border-b border-white/10">
        <span className="text-white text-xs font-semibold">Sessions</span>
        <button onClick={onClose} className="text-white/40 hover:text-white text-xs">✕</button>
      </div>

      <button
        onClick={() => { setActiveSessionId(null); clearMessages(); }}
        className="mx-2 my-2 px-2 py-1 bg-white/10 hover:bg-white/20 text-white text-xs rounded text-left"
      >
        + New Chat
      </button>

      <div className="flex flex-col gap-0.5 overflow-y-auto px-2 pb-2">
        {sessions.map((session) => (
          <SessionItem
            key={session.session_id}
            session={session}
            isActive={session.session_id === activeSessionId}
            fastapiUrl={settings.fastapiUrl}
            onSelect={() => setActiveSessionId(session.session_id)}
            onDelete={async () => {
              await deleteSession(settings.fastapiUrl, session.session_id);
              await onRefreshSessions();
            }}
            onRename={async (name) => {
              await renameSession(settings.fastapiUrl, session.session_id, name);
              await onRefreshSessions();
            }}
          />
        ))}
      </div>
    </div>
  );
}

function SessionItem({
  session,
  isActive,
  onSelect,
  onDelete,
  onRename,
}: {
  session: Session;
  isActive: boolean;
  fastapiUrl: string;
  onSelect: () => void;
  onDelete: () => Promise<void>;
  onRename: (name: string) => Promise<void>;
}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(session.name);

  async function commitRename() {
    setEditing(false);
    if (draft !== session.name) await onRename(draft);
  }

  return (
    <div
      className={`group flex items-center gap-1 px-2 py-1.5 rounded cursor-pointer text-xs ${
        isActive ? "bg-white/15 text-white" : "text-white/60 hover:bg-white/10 hover:text-white"
      }`}
      onClick={onSelect}
    >
      {editing ? (
        <input
          autoFocus
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={commitRename}
          onKeyDown={(e) => { if (e.key === "Enter") commitRename(); }}
          onClick={(e) => e.stopPropagation()}
          className="flex-1 bg-transparent border-b border-white/30 outline-none text-white"
        />
      ) : (
        <span className="flex-1 truncate">{session.name || session.session_id.slice(0, 8)}</span>
      )}
      <button
        onClick={(e) => { e.stopPropagation(); setEditing(true); }}
        className="opacity-0 group-hover:opacity-100 text-white/40 hover:text-white"
        title="Rename"
      >
        ✎
      </button>
      <button
        onClick={(e) => { e.stopPropagation(); onDelete(); }}
        className="opacity-0 group-hover:opacity-100 text-white/40 hover:text-red-400"
        title="Delete"
      >
        🗑
      </button>
    </div>
  );
}

async function deleteSession(baseUrl: string, sessionId: string): Promise<void> {
  const res = await fetch(`${baseUrl}/v1/stm/sessions/${sessionId}`, { method: "DELETE" });
  if (!res.ok) throw new Error(`DELETE session failed: ${res.status}`);
}

async function renameSession(baseUrl: string, sessionId: string, name: string): Promise<void> {
  const res = await fetch(`${baseUrl}/v1/stm/sessions/${sessionId}/metadata`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  if (!res.ok) throw new Error(`PATCH session failed: ${res.status}`);
}
```

- [ ] **Step 2: Build to verify**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
pnpm build
```

Expected: builds successfully.

- [ ] **Step 3: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/ui/src/components/SessionSidebar.tsx
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add SessionSidebar with STM REST calls"
```

---

### Task 13: App layout — wire all components together

**Files:**
- Modify: `desktop-homunculus/mods/desktopmate-bridge/ui/src/App.tsx`

**Context:** Three-panel layout with toggle state for Sessions sidebar and Settings panel. After `dm-message-complete` fires (via `useSignals`), call `getSessions()` to refresh the sidebar. `getSessions` fetches `GET /v1/stm/sessions`.

- [ ] **Step 1: Rewrite App.tsx**

```tsx
import { useState, useCallback, useEffect } from "react";
import { useSignals } from "./hooks/useSignals";
import { useBridgeStore } from "./store";
import { ChatWindow } from "./components/ChatWindow";
import { SessionSidebar } from "./components/SessionSidebar";
import { SettingsPanel } from "./components/SettingsPanel";
import { ControlBar } from "./components/ControlBar";

export function App() {
  const [showSessions, setShowSessions] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const { settings, setSessions } = useBridgeStore();

  useSignals();

  const getSessions = useCallback(async () => {
    try {
      const res = await fetch(`${settings.fastapiUrl}/v1/stm/sessions`);
      if (res.ok) {
        const data = await res.json();
        setSessions(data);
      }
    } catch {
      // silently ignore — FastAPI may be offline
    }
  }, [settings.fastapiUrl, setSessions]);

  useEffect(() => {
    getSessions();
  }, [getSessions]);

  return (
    <div className="flex flex-col h-screen w-screen bg-black/70 backdrop-blur-sm text-white overflow-hidden">
      <div className="flex flex-1 overflow-hidden">
        {showSessions && (
          <SessionSidebar
            onClose={() => setShowSessions(false)}
            onRefreshSessions={getSessions}
          />
        )}
        <ChatWindow />
        {showSettings && (
          <SettingsPanel onClose={() => setShowSettings(false)} />
        )}
      </div>
      <ControlBar
        onToggleSessions={() => setShowSessions((v) => !v)}
        onToggleSettings={() => setShowSettings((v) => !v)}
        showSessions={showSessions}
        showSettings={showSettings}
      />
    </div>
  );
}
```

- [ ] **Step 2: Also wire getSessions to dm-message-complete in useSignals**

Update `ui/src/hooks/useSignals.ts` — change the hook signature to accept an optional callback, and call it after `addMessage`. Replace the full `useSignals` export with:

```typescript
export function useSignals(onMessageComplete?: () => void): void {
  const setConnectionStatus = useBridgeStore((s) => s.setConnectionStatus);
  const setIsTyping = useBridgeStore((s) => s.setIsTyping);
  const addMessage = useBridgeStore((s) => s.addMessage);

  useEffect(() => {
    const connectionEs = new EventSource(makeSignalUrl("dm-connection-status"));
    connectionEs.addEventListener("message", (e) => {
      const payload = parseEvent<DmConnectionStatus>(e.data);
      if (payload) setConnectionStatus(payload.status);
    });

    const typingEs = new EventSource(makeSignalUrl("dm-typing-start"));
    typingEs.addEventListener("message", (e) => {
      const payload = parseEvent<DmTypingStart>(e.data);
      if (payload) setIsTyping(true);
    });

    const completeEs = new EventSource(makeSignalUrl("dm-message-complete"));
    completeEs.addEventListener("message", (e) => {
      const payload = parseEvent<DmMessageComplete>(e.data);
      if (payload) {
        setIsTyping(false);
        addMessage({
          id: crypto.randomUUID(),
          role: "assistant",
          content: payload.content,
          timestamp: Date.now(),
        });
        onMessageComplete?.();
      }
    });

    return () => {
      connectionEs.close();
      typingEs.close();
      completeEs.close();
    };
  }, [setConnectionStatus, setIsTyping, addMessage, onMessageComplete]);
}
```

Update `App.tsx` line `useSignals()` to:

```tsx
useSignals(getSessions);
```

- [ ] **Step 3: Build final UI**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
pnpm build
```

Expected: `ui/dist/index.html` generated with no errors.

- [ ] **Step 4: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/ui/src/App.tsx mods/desktopmate-bridge/ui/src/hooks/useSignals.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): wire App layout with all panels"
```

---

## Phase 4: Mock server + integration testing

### Task 14: Mock homunculus server

**Files:**
- Create: `desktop-homunculus/mods/desktopmate-bridge/scripts/mock-homunculus.ts`

**Context:** The mock must accept `POST /vrm/{entity_id}/speech/timeline` and all other engine endpoints. Return 200 OK for everything. This allows manual E2E testing of `service.ts` without the real engine running.

- [ ] **Step 1: Write mock-homunculus.ts**

```typescript
import * as http from "node:http";

const PORT = 3100;

function handleRequest(req: http.IncomingMessage, res: http.ServerResponse): void {
  const chunks: Buffer[] = [];
  req.on("data", (c) => chunks.push(c as Buffer));
  req.on("end", () => {
    const body = Buffer.concat(chunks).toString("utf-8");
    console.log(`[mock] ${req.method} ${req.url}`, body.length > 0 ? body.slice(0, 120) : "");
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
  });
}

const server = http.createServer(handleRequest);
server.listen(PORT, "127.0.0.1", () => {
  console.log(`[mock-homunculus] listening on http://127.0.0.1:${PORT}`);
});
```

- [ ] **Step 2: Run mock and verify**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
npm run mock
```

In another terminal:

```bash
curl -X POST http://127.0.0.1:3100/vrm/1/speech/timeline \
  -H "Content-Type: application/json" \
  -d '{"wav":[1,2,3],"keyframes":[]}'
```

Expected: `{"ok":true}` response. Mock logs the request.

- [ ] **Step 3: Commit**

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus add mods/desktopmate-bridge/scripts/mock-homunculus.ts
git -C /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus commit -m "feat(desktopmate-bridge): add mock homunculus server"
```

---

### Task 15: Manual integration test checklist

**Files:**
- None created (manual verification steps)

**Context:** Run service.ts against mock homunculus + real FastAPI to verify the full flow end-to-end.

- [ ] **Step 1: Start mock homunculus**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
npm run mock
```

Expected: `[mock-homunculus] listening on http://127.0.0.1:3100`

- [ ] **Step 2: Start FastAPI backend**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/backend
uvicorn src.main:app --port 5500
```

Expected: FastAPI starts at `http://127.0.0.1:5500`.

- [ ] **Step 3: Start service.ts with mock ports**

```bash
cd /home/spow12/codes/2025_lower/DesktopMatePlus/desktop-homunculus/mods/desktopmate-bridge
HMCS_RPC_PORT=9101 HMCS_MOD_NAME=desktopmate-bridge HMCS_PORT=3100 node --import tsx service.ts
```

Expected:
- `[desktopmate-bridge] config loaded`
- `[desktopmate-bridge] connecting`
- `[desktopmate-bridge] authorized` (after WS connect + auth success)

- [ ] **Step 4: Send test message via RPC**

```bash
curl -X POST http://127.0.0.1:9101/sendMessage \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello!"}'
```

Expected: `{"sent":true}`. FastAPI receives message. Mock homunculus logs `POST /vrm/1/speech/timeline` if a tts_chunk arrives.

- [ ] **Step 5: Test reconnect behavior**

Stop FastAPI (Ctrl-C). Watch service.ts logs.

Expected:
- `[desktopmate-bridge] reconnecting in 1s`
- `[desktopmate-bridge] reconnecting in 2s`
- `[desktopmate-bridge] reconnecting in 3s`
- `[desktopmate-bridge] max retries reached — restart required`

- [ ] **Step 6: Commit workspace-level plan cross-reference**

Update `docs/prds/feature/INDEX.md` to mark `desktopmate-bridge` MOD as IN PROGRESS.

```bash
git -C /home/spow12/codes/2025_lower/DesktopMatePlus add docs/prds/feature/INDEX.md
git -C /home/spow12/codes/2025_lower/DesktopMatePlus commit -m "docs: mark desktopmate-bridge as IN PROGRESS in INDEX.md"
```

---

## Summary

| Phase | Tasks | Deliverable |
|-------|-------|------------|
| 1 | 1–7 | `service.ts` fully functional: WS bridge, engine speech calls, reconnect, RPC |
| 2 | 8–10 | React UI scaffold: Vite, Zustand store, Settings Panel, Signals hook |
| 3 | 11–13 | Full chat UI: ChatWindow, ControlBar, SessionSidebar, wired App |
| 4 | 14–15 | Mock server + manual E2E verification |

Each task ends with a passing build or manual verification step and a commit. The MOD can be installed into `~/.homunculus/mods/` with `hmcs mod install` after Phase 1 is complete and tested independently.
