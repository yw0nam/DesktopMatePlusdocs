# Desktop Homunculus MOD 시스템

desktop-homunculus에 MOD를 추가하는 방법, MOD의 철학, UI 설정 방법을 정리한 문서.

## MOD 시스템 핵심 철학

## "MOD = pnpm workspace 패키지"

MOD는 `package.json`에 `"homunculus"` 필드가 추가된 Node.js 패키지다. 엔진이 `pnpm ls --parseable`로 `~/.homunculus/mods/` 디렉토리를 스캔하여 자동 발견한다. 별도 등록 절차 없이, 패키지를 해당 디렉토리에 설치(`hmcs mod install`)하면 된다.

## MOD의 3가지 진입점

| 진입점 | `package.json` 키 | 설명 |
| ------ | ----------------- | ---- |
| **Service** | `homunculus.service` | 앱 시작 시 자동 실행되는 장기 프로세스. `tsx`로 TypeScript 직접 실행. |
| **Bin commands** | `bin` | HTTP API(`POST /mods/{mod}/bin/{cmd}`)로 호출되는 명령. 트레이/메뉴에서 트리거 가능. |
| **Assets** | `homunculus.assets` | `html`, `vrm`, `vrma`, `sound`, `image` 등 에셋 선언. Asset ID = `"mod-name:asset-id"` |

## MOD 유형별 구조

| 유형 | 설명 | 참고 MOD |
|------|------|----------|
| **Service-only** | 앱 전체 생명주기 동안 실행되는 백그라운드 로직 | `elmer` |
| **UI MOD** | WebView 기반 React UI. 트레이/메뉴에서 진입 | `settings`, `voicevox` |
| **Service + UI** | 백그라운드 서비스 + 별도로 열 수 있는 UI 패널 | `voicevox`, `desktopmate-bridge` |

전체 코드 예제 → [MOD 유형별 구조 상세](./desktop-homunculus-mod-types.md)

## UI 개발 — Glassmorphism 디자인

모든 WebView UI는 투명한 Bevy 창 위에 올라가는 오버레이이므로 **Glassmorphism** 스타일을 사용한다.

```tsx
// 기본 패널 스타일
className="bg-primary/30 backdrop-blur-sm border border-white/20 text-white rounded-lg"
```

### UI 스택

- **React 19** + **Vite**
- **Tailwind CSS v4**
- **`@hmcs/ui`**: shadcn/ui (new-york style) + Radix UI + lucide-react
- **`cn()`**: clsx + tailwind-merge 유틸리티

### 빌드 방법

UI는 `vite-plugin-singlefile`을 사용해 **단일 `index.html`**로 번들링된다. CEF WebView가 이 파일을 직접 로드한다.

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import tailwindcss from "@tailwindcss/vite";
import { viteSingleFile } from "vite-plugin-singlefile";

export default defineConfig({
  plugins: [react(), tailwindcss(), viteSingleFile()],
  root: ".",
  build: { outDir: "dist" },
});
```

```bash
# ui/ 디렉토리에서
pnpm build    # → dist/index.html (단일 파일)
```

## Service ↔ UI 통신

WebView UI와 Service 간 실시간 통신은 SDK의 `signals` 모듈을 사용한다.

```typescript
// service.ts에서 signal 발행
import { signals } from "@hmcs/sdk";
await signals.emit("my-mod:status", { value: "running" });

// UI React 컴포넌트에서 수신
import { signals } from "@hmcs/sdk";
useEffect(() => {
  const unsub = signals.on("my-mod:status", (data) => {
    setStatus(data.value);
  });
  return unsub;
}, []);
```

## 설정 저장 (preferences)

```typescript
import { preferences } from "@hmcs/sdk";

// 저장
await preferences.save("my-mod:config", { speed: 1.5, enabled: true });

// 불러오기
const config = await preferences.load<MyConfig>("my-mod:config");
```

데이터는 `~/.homunculus/preferences.db` (SQLite JSON key-value)에 저장된다.

## MOD 설치 및 런타임

```bash
# 개발 중 (workspace 링크)
# pnpm-workspace.yaml에 mods/* 포함되어 있으면 자동

# 배포용 설치
hmcs mod install ./my-mod

# 설치 위치
~/.homunculus/mods/
```

엔진은 시작 시 `homunculus.service`를 `node --import tsx`로 실행한다 (`tsx`는 `ensure_tsx()`로 로컬 설치).

## 레포 내 MOD 목록

| MOD | 설명 | 진입점 |
|-----|------|--------|
| `elmer` | 기본 캐릭터 스폰 + 애니메이션 | service |
| `assets` | 기본 VRMA/SE 에셋 제공 | assets only |
| `settings` | FPS/그림자 설정 패널 | tray + UI |
| `menu` | 우클릭 HUD 메뉴 | service + UI |
| `voicevox` | VoiceVox TTS 연동 | service + menu + UI |
| `character-settings` | 캐릭터별 설정 UI | UI |
| `app-exit` | 앱 종료 버튼 | tray + bin |
| `desktopmate-bridge` | FastAPI WebSocket 브릿지 + Carlotta VRM + 채팅 UI | service + menu + UI |

## 글로벌 패널 vs per-VRM 패널

bin command 내에서 `input.parseMenu()`를 호출하는지 여부가 다르다:

- **per-VRM 패널** (예: `voicevox/open-settings.ts`): `input.parseMenu()`로 트리거된 VRM entity를 파악한 뒤 패널 오픈
- **글로벌 패널** (예: `desktopmate-bridge/open-chat.ts`): 특정 VRM에 귀속되지 않으므로 `input.parseMenu()` 미호출, 바로 `Webview.open()` 실행

## MOD 테스트 전략 (vitest unit/e2e 분리)

MOD에 E2E 테스트가 있을 경우 vitest 설정 파일을 분리한다. `test.exclude`는 CLI에서 경로를 직접 지정해도 적용되어 E2E 단독 실행이 불가능해지기 때문이다:

```typescript
// vitest.config.ts — unit 전용 (pnpm test)
export default defineConfig({ test: { exclude: ["**/node_modules/**", "tests/e2e/**"] } });

// vitest.e2e.config.ts — E2E 전용 (pnpm test:e2e)
export default defineConfig({ test: { include: ["tests/e2e/**/*.test.ts"] } });
```

```json
// package.json scripts
"test": "vitest run",
"test:e2e": "FASTAPI_URL=http://localhost:5500 vitest run -c vitest.e2e.config.ts"
```
