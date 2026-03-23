# desktopmate-bridge UI Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix layout shrink-to-fit, open-chat toggle, editable settings with yaml write-back, TTS reference ID, and a collection of bugs/code quality issues found in code review.

**Architecture:** UI state is managed in Zustand store; signals from service.ts push config/connection/stream events to the React app; RPC calls from the app invoke service.ts methods. Config is stored in `config.yaml` and written back via a new `updateConfig` RPC method.

**Tech Stack:** React 19, Zustand, Tailwind CSS v4, Vite, Vitest, `@hmcs/sdk`, `js-yaml`

---

## File Map

| File | Change |
|------|--------|
| `commands/open-chat.ts` | toggle behavior (close if open, open if closed) |
| `service.ts` | add `tts` to Config; add `updateConfig` RPC; expand `dm-config` signal |
| `config.yaml` | add `tts.reference_id` field |
| `ui/src/types.ts` | extend `DmConfig` with all config fields |
| `ui/src/store.ts` | add `setMessages` action; update `DmConfig` default; update settings initial state |
| `ui/src/store.test.ts` | add `setMessages` test; update `beforeEach` for new DmConfig shape |
| `ui/src/api.ts` | move `rpc` import to top; add `updateConfig`; fix `fetchChatHistory` timestamps |
| `ui/src/App.tsx` | default all panels to `false`; remove `h-full`; add `max-h-[350px]` to panels area |
| `ui/src/index.css` | add `justify-end` to `#root` to anchor control bar at bottom |
| `ui/src/components/SettingsPanel.tsx` | full rewrite: editable inputs for all fields + Save button |
| `ui/src/components/SessionSidebar.tsx` | use `setMessages`; show `created_at`; add error handling |
| `ui/src/components/ControlBar.tsx` | add drag; add error handling in `handleSend`; fix status label language |
| `ui/src/hooks/useSignals.ts` | add explanatory comment for `eslint-disable` |

---

## Task 1: open-chat toggle

**Files:**
- Modify: `commands/open-chat.ts`

- [ ] **Step 1: Replace open-only with toggle logic**

```typescript
#!/usr/bin/env tsx
import { Webview, webviewSource, audio } from "@hmcs/sdk";
import { output } from "@hmcs/sdk/commands";

const CHAT_UI_ASSET = "desktopmate-bridge:chat-ui";

try {
  const webviews = await Webview.list();
  const existing = webviews.find(
    (w) => w.source.type === "local" && (w.source as { id: string }).id === CHAT_UI_ASSET,
  );

  if (existing && !(await new Webview(existing.entity).isClosed())) {
    await new Webview(existing.entity).close();
    await audio.se.play("se:close");
  } else {
    await Webview.open({
      source: webviewSource.local(CHAT_UI_ASSET),
      size: [0.9, 1.0],
      viewportSize: [700, 600],
      offset: [1.1, 0],
    });
    await audio.se.play("se:open");
  }
  output.succeed();
} catch (e) {
  output.fail("TOGGLE_CHAT_FAILED", (e as Error).message);
}
```

- [ ] **Step 2: Commit**

```bash
git add commands/open-chat.ts
git commit -m "feat: make open-chat a toggle (close if already open)"
```

---

## Task 2: Layout — shrink-to-fit, panels hidden by default

**Files:**
- Modify: `ui/src/App.tsx`
- Modify: `ui/src/index.css`

- [ ] **Step 1: Update `index.css` — anchor content to bottom of viewport**

```css
@import "tailwindcss";
@import "@hmcs/ui/dist/index.css";

body {
  background: transparent;
  margin: 0;
}

#root {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
}
```

- [ ] **Step 2: Update `App.tsx` — remove `h-full`, fix defaults, add `max-h`**

```tsx
import { useState } from "react";
import { useSignals } from "./hooks/useSignals";
import { ControlBar } from "./components/ControlBar";
import { SessionSidebar } from "./components/SessionSidebar";
import { ChatWindow } from "./components/ChatWindow";
import { SettingsPanel } from "./components/SettingsPanel";

export function App() {
  const [showSidebar, setShowSidebar] = useState(false);
  const [showChat, setShowChat] = useState(false);
  const [showSettings, setShowSettings] = useState(false);

  useSignals();

  const anyPanelOpen = showSidebar || showChat || showSettings;

  return (
    <div className="w-full flex flex-col text-white">
      {anyPanelOpen && (
        <div className="flex overflow-hidden max-h-[350px] bg-black/20 backdrop-blur-sm">
          {showSidebar && <SessionSidebar />}
          {showChat && <ChatWindow />}
          {showSettings && <SettingsPanel />}
        </div>
      )}
      <ControlBar
        onToggleSidebar={() => setShowSidebar((v) => !v)}
        onToggleChat={() => setShowChat((v) => !v)}
        onToggleSettings={() => setShowSettings((v) => !v)}
      />
    </div>
  );
}
```

- [ ] **Step 3: Build to verify no type errors**

```bash
cd ui && npx tsc --noEmit
```

Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add ui/src/App.tsx ui/src/index.css
git commit -m "fix: shrink-to-fit layout — panels hidden by default, anchored to bottom"
```

---

## Task 3: Store — add `setMessages`, update `DmConfig` defaults

**Files:**
- Modify: `ui/src/store.ts`
- Modify: `ui/src/store.test.ts`

- [ ] **Step 1: Write failing test for `setMessages`**

Add to `ui/src/store.test.ts` (inside the `messages` describe block):

```typescript
it("setMessages replaces all messages", () => {
  useStore.getState().addUserMessage("existing");
  const newMessages = [
    { id: "a", role: "user" as const, content: "new", timestamp: 1000 },
  ];
  useStore.getState().setMessages(newMessages);
  expect(useStore.getState().messages).toEqual(newMessages);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ui && npx vitest run src/store.test.ts
```

Expected: FAIL — `setMessages is not a function`

- [ ] **Step 3: Add `setMessages` to `store.ts`**

In the `StoreState` interface add:
```typescript
setMessages: (messages: Message[]) => void;
```

In the store implementation add:
```typescript
setMessages: (messages) => set({ messages }),
```

- [ ] **Step 4: Update `settings` initial state in `store.ts`**

```typescript
settings: {
  user_id: "",
  agent_id: "",
  fastapi_rest_url: "",
  fastapi_ws_url: "",
  fastapi_token: "",
  homunculus_api_url: "",
  tts_reference_id: "",
},
```

Note: `DmConfig` will be expanded in Task 4 before this compiles.

- [ ] **Step 5: Update `beforeEach` in `store.test.ts`**

```typescript
beforeEach(() => {
  useStore.setState({
    messages: [],
    sessions: [],
    activeSessionId: null,
    isTyping: false,
    connectionStatus: "disconnected",
    settings: {
      user_id: "",
      agent_id: "",
      fastapi_rest_url: "",
      fastapi_ws_url: "",
      fastapi_token: "",
      homunculus_api_url: "",
      tts_reference_id: "",
    },
  });
});
```

Also update the `setSettings` test to use the full shape:

```typescript
it("setSettings updates settings", () => {
  useStore.getState().setSettings({
    user_id: "alice",
    agent_id: "yuri",
    fastapi_rest_url: "http://localhost:5500",
    fastapi_ws_url: "ws://localhost:5500/v1/chat/stream",
    fastapi_token: "tok",
    homunculus_api_url: "http://localhost:3100",
    tts_reference_id: "speaker_001",
  });
  expect(useStore.getState().settings.user_id).toBe("alice");
});
```

- [ ] **Step 6: Run all store tests**

```bash
cd ui && npx vitest run src/store.test.ts
```

Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add ui/src/store.ts ui/src/store.test.ts
git commit -m "feat: add setMessages action; expand DmConfig initial state"
```

---

## Task 4: Types + API layer

**Files:**
- Modify: `ui/src/types.ts`
- Modify: `ui/src/api.ts`

- [ ] **Step 1: Expand `DmConfig` in `types.ts`**

```typescript
export interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  timestamp: number;
  /** true if still streaming */
  streaming?: boolean;
}

export interface Session {
  session_id: string;
  name: string;
  created_at: string;
  updated_at: string;
}

export interface DmConfig {
  user_id: string;
  agent_id: string;
  fastapi_rest_url: string;
  fastapi_ws_url: string;
  fastapi_token: string;
  homunculus_api_url: string;
  tts_reference_id: string;
}

export type ConnectionStatus = "connected" | "disconnected" | "restart-required";
```

- [ ] **Step 2: Fix `api.ts` — move `rpc` import to top, fix timestamps, add `updateConfig`**

Full rewrite of `ui/src/api.ts`:

```typescript
import { rpc } from "@hmcs/sdk/rpc";
import type { Session, Message, DmConfig } from "./types";

async function apiFetch(
  restUrl: string,
  path: string,
  init?: RequestInit,
): Promise<Response> {
  return fetch(`${restUrl}${path}`, init);
}

interface BackendSession {
  session_id: string;
  created_at: string;
  updated_at: string;
  metadata: Record<string, unknown>;
}

export async function fetchSessions(
  restUrl: string,
  userId: string,
  agentId: string,
): Promise<Session[]> {
  const res = await apiFetch(
    restUrl,
    `/v1/stm/sessions?user_id=${userId}&agent_id=${agentId}`,
  );
  if (!res.ok) throw new Error(`fetchSessions failed: ${res.status}`);
  const data = (await res.json()) as { sessions: BackendSession[] };
  return data.sessions.map((s) => ({
    session_id: s.session_id,
    name: (s.metadata?.name as string | undefined) ?? s.session_id.slice(0, 12),
    created_at: s.created_at,
    updated_at: s.updated_at,
  }));
}

interface BackendMessage {
  role: "user" | "assistant";
  content: string;
  created_at?: string;
}

export async function fetchChatHistory(
  restUrl: string,
  sessionId: string,
  userId: string,
  agentId: string,
): Promise<Message[]> {
  const res = await apiFetch(
    restUrl,
    `/v1/stm/get-chat-history?session_id=${sessionId}&user_id=${userId}&agent_id=${agentId}`,
  );
  if (!res.ok) throw new Error(`fetchChatHistory failed: ${res.status}`);
  const data = (await res.json()) as { messages: BackendMessage[] };
  return data.messages
    .filter((m) => m.role === "user" || m.role === "assistant")
    .map((m) => ({
      id: crypto.randomUUID(),
      role: m.role,
      content: typeof m.content === "string" ? m.content : JSON.stringify(m.content),
      timestamp: m.created_at ? new Date(m.created_at).getTime() : Date.now(),
    }));
}

export async function deleteSession(
  restUrl: string,
  sessionId: string,
  userId: string,
  agentId: string,
): Promise<void> {
  const res = await apiFetch(
    restUrl,
    `/v1/stm/sessions/${sessionId}?user_id=${userId}&agent_id=${agentId}`,
    { method: "DELETE" },
  );
  if (!res.ok) throw new Error(`deleteSession failed: ${res.status}`);
}

export async function patchSessionName(
  restUrl: string,
  sessionId: string,
  name: string,
): Promise<void> {
  const res = await apiFetch(
    restUrl,
    `/v1/stm/sessions/${sessionId}/metadata`,
    {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    },
  );
  if (!res.ok) throw new Error(`patchSessionName failed: ${res.status}`);
}

export async function sendChatMessage(
  sessionId: string | undefined,
  content: string,
): Promise<void> {
  await rpc.call({
    modName: "@hmcs/desktopmate-bridge",
    method: "sendMessage",
    body: { content, session_id: sessionId },
  });
}

export async function interruptStream(): Promise<void> {
  await rpc.call({
    modName: "@hmcs/desktopmate-bridge",
    method: "interruptStream",
  });
}

export async function updateConfig(config: DmConfig): Promise<void> {
  await rpc.call({
    modName: "@hmcs/desktopmate-bridge",
    method: "updateConfig",
    body: config,
  });
}
```

- [ ] **Step 3: Type-check**

```bash
cd ui && npx tsc --noEmit
```

Expected: no errors (store.ts may still error until service.ts is done — that's OK)

- [ ] **Step 4: Commit**

```bash
git add ui/src/types.ts ui/src/api.ts
git commit -m "feat: expand DmConfig; fix history timestamps; add updateConfig API"
```

---

## Task 5: service.ts — Config expansion + updateConfig RPC

**Files:**
- Modify: `service.ts`
- Modify: `config.yaml`

- [ ] **Step 1: Add `tts` to `config.yaml`**

```yaml
fastapi:
  ws_url: "ws://127.0.0.1:5500/v1/chat/stream"
  rest_url: "http://127.0.0.1:5500"
  token: "<auth_token>"
  user_id: "default"
  agent_id: "yuri"
homunculus:
  api_url: "http://localhost:3100"
tts:
  reference_id: ""
```

- [ ] **Step 2: Update `service.ts` — Config interface, CONFIG_PATH constant, updateConfig RPC**

Key changes to `service.ts`:

**Add `writeFileSync` import and `CONFIG_PATH` constant:**
```typescript
import { readFileSync, writeFileSync } from "node:fs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFIG_PATH = resolve(__dirname, "config.yaml");
```

**Expand `Config` interface:**
```typescript
interface Config {
  fastapi: {
    ws_url: string;
    rest_url: string;
    token: string;
    user_id: string;
    agent_id: string;
  };
  homunculus: {
    api_url: string;
  };
  tts: {
    reference_id: string;
  };
}
```

**Update `loadConfig` to use `CONFIG_PATH`:**
```typescript
function loadConfig(): Config {
  const raw = yaml.load(readFileSync(CONFIG_PATH, "utf-8")) as Config;
  return raw;
}
```

**Add `updateConfig` method to `startRpcServer`:**
```typescript
function startRpcServer(config: Config) {
  const sendMessage = rpc.method({ /* unchanged */ });
  const interruptStream = rpc.method({ /* unchanged */ });

  const updateConfig = rpc.method({
    description: "Update config fields and write back to config.yaml",
    input: z.object({
      user_id: z.string(),
      agent_id: z.string(),
      fastapi_rest_url: z.string(),
      fastapi_ws_url: z.string(),
      fastapi_token: z.string(),
      homunculus_api_url: z.string(),
      tts_reference_id: z.string(),
    }),
    // JS objects are reference-passed, so mutating `config` here updates the same
    // object held by `connectAndServe` — changes take effect for subsequent operations.
    handler: async (input) => {
      config.fastapi.user_id = input.user_id;
      config.fastapi.agent_id = input.agent_id;
      config.fastapi.rest_url = input.fastapi_rest_url;
      config.fastapi.ws_url = input.fastapi_ws_url;
      config.fastapi.token = input.fastapi_token;
      config.homunculus.api_url = input.homunculus_api_url;
      config.tts.reference_id = input.tts_reference_id;
      writeFileSync(CONFIG_PATH, yaml.dump(config), "utf-8");
      await broadcastConfig(config);
      return { ok: true };
    },
  });

  return rpc.serve({ methods: { sendMessage, interruptStream, updateConfig } });
}
```

**Extract `broadcastConfig` helper and update `connectAndServe`:**
```typescript
async function broadcastConfig(config: Config): Promise<void> {
  await signals.send("dm-config", {
    user_id: config.fastapi.user_id,
    agent_id: config.fastapi.agent_id,
    fastapi_rest_url: config.fastapi.rest_url,
    fastapi_ws_url: config.fastapi.ws_url,
    fastapi_token: config.fastapi.token,
    homunculus_api_url: config.homunculus.api_url,
    tts_reference_id: config.tts.reference_id,
  });
}

async function connectAndServe(config: Config, vrm: Vrm): Promise<void> {
  await broadcastConfig(config);
  await startRpcServer(config);
  await connectWithRetry(config, vrm, { attempts: 0 });
}
```

- [ ] **Step 3: Verify service.ts compiles**

`service.ts` runs via `tsx` (no tsconfig in mod root). Use the pnpm build step from the parent workspace to type-check, or do a quick dry-run:

```bash
# From desktop-homunculus repo root:
pnpm --filter @hmcs/desktopmate-bridge build 2>&1 | head -30
# Expected: no TypeScript errors printed
```

If the filter name differs, check `package.json` in `mods/desktopmate-bridge/`.

- [ ] **Step 4: Commit**

```bash
git add service.ts config.yaml
git commit -m "feat: expand Config with tts; add updateConfig RPC; broadcast all fields via dm-config"
```

---

## Task 6: SettingsPanel — editable fields + Save

**Files:**
- Modify: `ui/src/components/SettingsPanel.tsx`

- [ ] **Step 1: Rewrite `SettingsPanel.tsx`**

```tsx
import { useState, useEffect } from "react";
import { useStore } from "../store";
import { updateConfig } from "../api";
import type { DmConfig } from "../types";

export function SettingsPanel() {
  const { settings } = useStore();
  const [form, setForm] = useState<DmConfig>(settings);
  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");

  useEffect(() => {
    setForm(settings);
  }, [settings]);

  function handleChange(key: keyof DmConfig, value: string) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  async function handleSave() {
    setStatus("saving");
    try {
      await updateConfig(form);
      setStatus("saved");
      setTimeout(() => setStatus("idle"), 2000);
    } catch {
      setStatus("error");
      setTimeout(() => setStatus("idle"), 3000);
    }
  }

  const saveLabel = {
    idle: "Save",
    saving: "Saving...",
    saved: "✔ Saved",
    error: "✖ Error",
  }[status];

  return (
    <div className="w-52 flex flex-col bg-black/30 backdrop-blur-sm border-l border-white/10 p-3 gap-2 overflow-y-auto">
      <div className="text-white/80 text-xs font-semibold">⚙ Settings</div>
      <SettingInput label="user_id" value={form.user_id} onChange={(v) => handleChange("user_id", v)} />
      <SettingInput label="agent_id" value={form.agent_id} onChange={(v) => handleChange("agent_id", v)} />
      <SettingInput label="FastAPI REST URL" value={form.fastapi_rest_url} onChange={(v) => handleChange("fastapi_rest_url", v)} />
      <SettingInput label="FastAPI WS URL" value={form.fastapi_ws_url} onChange={(v) => handleChange("fastapi_ws_url", v)} />
      <SettingInput label="Token" value={form.fastapi_token} onChange={(v) => handleChange("fastapi_token", v)} type="password" />
      <SettingInput label="Homunculus API URL" value={form.homunculus_api_url} onChange={(v) => handleChange("homunculus_api_url", v)} />
      <SettingInput label="TTS Reference ID" value={form.tts_reference_id} onChange={(v) => handleChange("tts_reference_id", v)} />
      <button
        className="mt-1 bg-white/15 border border-white/25 rounded px-2 py-1 text-white text-xs hover:bg-white/25 disabled:opacity-40"
        onClick={handleSave}
        disabled={status === "saving"}
      >
        {saveLabel}
      </button>
    </div>
  );
}

function SettingInput({
  label,
  value,
  onChange,
  type = "text",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: "text" | "password";
}) {
  return (
    <div>
      <div className="text-white/40 text-[10px] mb-0.5">{label}</div>
      <input
        type={type}
        className="w-full bg-white/10 border border-white/20 rounded px-1.5 py-0.5 text-white text-xs outline-none focus:border-white/40"
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}
```

- [ ] **Step 2: Type-check**

```bash
cd ui && npx tsc --noEmit
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add ui/src/components/SettingsPanel.tsx
git commit -m "feat: editable settings panel with TTS reference ID and yaml write-back"
```

---

## Task 7: SessionSidebar — code quality fixes

**Files:**
- Modify: `ui/src/components/SessionSidebar.tsx`

- [ ] **Step 1: Fix `useStore.setState` direct access, add `created_at`, add error handling**

```tsx
import { useState } from "react";
import { useStore } from "../store";
import {
  fetchChatHistory,
  fetchSessions,
  deleteSession,
  patchSessionName,
} from "../api";

export function SessionSidebar() {
  const {
    sessions,
    activeSessionId,
    setActiveSession,
    setMessages,
    setSessions,
    settings,
  } = useStore();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");

  async function handleSelectSession(sessionId: string) {
    setActiveSession(sessionId);
    const history = await fetchChatHistory(
      settings.fastapi_rest_url,
      sessionId,
      settings.user_id,
      settings.agent_id,
    ).catch(() => []);
    setMessages(history);
  }

  function handleNewChat() {
    setActiveSession(null);
  }

  async function handleDelete(sessionId: string) {
    if (!confirm("Delete this session?")) return;
    try {
      await deleteSession(
        settings.fastapi_rest_url,
        sessionId,
        settings.user_id,
        settings.agent_id,
      );
      const updated = await fetchSessions(
        settings.fastapi_rest_url,
        settings.user_id,
        settings.agent_id,
      );
      setSessions(updated);
    } catch {
      alert("Failed to delete session.");
    }
  }

  async function handleRenameCommit(sessionId: string) {
    try {
      await patchSessionName(settings.fastapi_rest_url, sessionId, editName);
    } catch {
      // silently revert
    }
    setEditingId(null);
    const updated = await fetchSessions(
      settings.fastapi_rest_url,
      settings.user_id,
      settings.agent_id,
    ).catch(() => sessions);
    setSessions(updated);
  }

  return (
    <div className="w-48 flex flex-col bg-black/30 backdrop-blur-sm border-r border-white/10 overflow-y-auto">
      <div className="text-white/80 text-xs font-semibold px-2 pt-2 pb-1">
        Conversations
      </div>
      <div className="flex-1 overflow-y-auto">
        {sessions.map((s) => (
          <div
            key={s.session_id}
            className={`px-2 py-1 cursor-pointer hover:bg-white/10 ${
              s.session_id === activeSessionId ? "bg-white/20" : ""
            }`}
            onClick={() => handleSelectSession(s.session_id)}
          >
            {editingId === s.session_id ? (
              <input
                className="bg-white/20 text-white text-xs w-full outline-none rounded px-1"
                value={editName}
                autoFocus
                onChange={(e) => setEditName(e.target.value)}
                onBlur={() => handleRenameCommit(s.session_id)}
                onKeyDown={(e) =>
                  e.key === "Enter" && handleRenameCommit(s.session_id)
                }
              />
            ) : (
              <>
                <div className="text-white text-xs truncate">{s.name}</div>
                <div className="flex gap-1 mt-0.5 items-center">
                  <button
                    className="text-white/40 text-[10px] hover:text-white"
                    onClick={(e) => {
                      e.stopPropagation();
                      setEditingId(s.session_id);
                      setEditName(s.name);
                    }}
                  >
                    ✎
                  </button>
                  <button
                    className="text-white/40 text-[10px] hover:text-red-400"
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDelete(s.session_id);
                    }}
                  >
                    🗑
                  </button>
                  <div className="ml-auto text-right">
                    <div className="text-white/20 text-[10px]">
                      {new Date(s.updated_at).toLocaleDateString()}
                    </div>
                    <div className="text-white/15 text-[9px]">
                      {new Date(s.created_at).toLocaleDateString()}
                    </div>
                  </div>
                </div>
              </>
            )}
          </div>
        ))}
      </div>
      <button
        className="text-white/60 text-xs py-2 hover:text-white hover:bg-white/10 border-t border-white/10"
        onClick={handleNewChat}
      >
        + New Chat
      </button>
    </div>
  );
}
```

- [ ] **Step 2: Type-check**

```bash
cd ui && npx tsc --noEmit
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add ui/src/components/SessionSidebar.tsx
git commit -m "fix: use setMessages store action; show created_at; add error handling in sidebar"
```

---

## Task 8: ControlBar — drag, error handling, language fix

**Files:**
- Modify: `ui/src/components/ControlBar.tsx`

> **Note on drag:** The webview `offset` is in world-space units relative to the VRM. The `DRAG_SCALE` constant (0.002) maps screen pixels to world units — adjust if the drag speed feels off.

- [ ] **Step 1: Rewrite `ControlBar.tsx`**

```tsx
import { useRef, useState } from "react";
import { Webview } from "@hmcs/sdk";
import { useStore } from "../store";
import { sendChatMessage, interruptStream } from "../api";

interface ControlBarProps {
  onToggleChat: () => void;
  onToggleSidebar: () => void;
  onToggleSettings: () => void;
}

const DRAG_SCALE = 0.002;

export function ControlBar({
  onToggleChat,
  onToggleSidebar,
  onToggleSettings,
}: ControlBarProps) {
  const [input, setInput] = useState("");
  const { isTyping, connectionStatus, activeSessionId, addUserMessage } =
    useStore();

  const dragState = useRef<{
    startX: number;
    startY: number;
    startOffset: [number, number];
  } | null>(null);

  const statusLabel = {
    connected: "✔ Connected",
    disconnected: "✖ Disconnected",
    "restart-required": "⚠ Restart required",
  }[connectionStatus];

  async function handleSend() {
    if (!input.trim() || isTyping) return;
    const content = input.trim();
    setInput("");
    addUserMessage(content);
    try {
      await sendChatMessage(activeSessionId ?? undefined, content);
    } catch {
      // message is already shown in UI; WS send failure is handled by connection status
    }
  }

  async function handleStop() {
    await interruptStream();
  }

  async function handleDragStart(e: React.MouseEvent) {
    const wv = Webview.current();
    if (!wv) return;
    try {
      const info = await wv.info();
      dragState.current = {
        startX: e.clientX,
        startY: e.clientY,
        startOffset: info.offset,
      };
      window.addEventListener("mousemove", handleDragMove);
      window.addEventListener("mouseup", handleDragEnd);
    } catch {
      // engine unavailable
    }
  }

  function handleDragMove(e: MouseEvent) {
    if (!dragState.current) return;
    const wv = Webview.current();
    if (!wv) return;
    const dx = (e.clientX - dragState.current.startX) * DRAG_SCALE;
    const dy = (e.clientY - dragState.current.startY) * DRAG_SCALE;
    wv.setOffset([
      dragState.current.startOffset[0] + dx,
      dragState.current.startOffset[1] - dy,
    ]).catch(() => {});
  }

  function handleDragEnd() {
    dragState.current = null;
    window.removeEventListener("mousemove", handleDragMove);
    window.removeEventListener("mouseup", handleDragEnd);
  }

  return (
    <div className="flex flex-col gap-1 px-2 py-1 bg-black/30 backdrop-blur-sm border-t border-white/10">
      <div className="text-xs text-white/60 text-center">{statusLabel}</div>
      <div className="flex items-center gap-1">
        <button
          className="text-white/60 text-xs px-1 hover:text-white cursor-grab active:cursor-grabbing"
          onMouseDown={handleDragStart}
          title="Drag"
        >
          ⠿
        </button>
        <button
          className="text-white/60 text-xs px-1 hover:text-white"
          onClick={onToggleSidebar}
          title="Session List"
        >
          ☰
        </button>
        <input
          className="flex-1 bg-white/10 text-white text-sm rounded px-2 py-1 outline-none placeholder-white/40"
          placeholder="Enter message..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && handleSend()}
          disabled={isTyping}
        />
        {isTyping ? (
          <button
            className="text-red-400 text-xs px-2 py-1 hover:text-red-300"
            onClick={handleStop}
          >
            Stop
          </button>
        ) : (
          <button
            className="text-white/80 text-xs px-2 py-1 hover:text-white disabled:opacity-30"
            onClick={handleSend}
            disabled={!input.trim()}
          >
            Send
          </button>
        )}
        <button
          className="text-white/60 text-xs px-1 hover:text-white"
          onClick={onToggleChat}
          title="Chat History"
        >
          💬
        </button>
        <button
          className="text-white/60 text-xs px-1 hover:text-white"
          onClick={onToggleSettings}
          title="Settings"
        >
          ⚙
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Type-check**

```bash
cd ui && npx tsc --noEmit
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add ui/src/components/ControlBar.tsx
git commit -m "feat: add drag handle; fix handleSend error handling; fix status label language"
```

---

## Task 9: useSignals — minor fixes

**Files:**
- Modify: `ui/src/hooks/useSignals.ts`

- [ ] **Step 1: Add explanatory comment for eslint-disable**

Replace:
```typescript
  }, []); // eslint-disable-line react-hooks/exhaustive-deps
```

With:
```typescript
  // Empty deps is intentional: handlers close over store actions (stable refs) and
  // read fresh state via useStore.getState() — re-subscribing on every render would
  // cause duplicate SSE connections.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
```

- [ ] **Step 2: Commit**

```bash
git add ui/src/hooks/useSignals.ts
git commit -m "chore: clarify useSignals empty-deps rationale"
```

---

## Task 10: Build UI and verify

- [ ] **Step 1: Run all unit tests**

```bash
cd ui && npx vitest run
```

Expected: all PASS

- [ ] **Step 2: Build the UI bundle**

```bash
cd ui && npx vite build
```

Expected: build succeeds, `ui/dist/index.html` updated

- [ ] **Step 3: Final commit**

```bash
git add ui/
git commit -m "build: rebuild UI bundle after overhaul"
```
