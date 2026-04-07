# Desktop Homunculus MOD 유형별 구조

→ **상위 문서**: [Desktop Homunculus MOD 시스템](./desktop-homunculus-mod-system.md)

MOD는 목적에 따라 3가지 유형으로 나뉜다. 각 유형의 전형적인 구조와 코드를 설명한다.

## 1. Service-only MOD (`elmer` 참고)

캐릭터 스폰, 애니메이션 루프처럼 앱 전체 생명주기 동안 실행되는 로직.

```
mods/my-mod/
├── package.json    # homunculus.service: "service.ts"
└── service.ts
```

```json
{
  "homunculus": {
    "service": "service.ts"
  }
}
```

```typescript
// service.ts
import { Vrm, repeat, sleep } from "@hmcs/sdk";

const char = await Vrm.spawn("vrm:elmer", { transform });
await char.playVrma({ asset: "vrma:idle-maid", repeat: repeat.forever() });

char.events().on("state-change", async (e) => {
  if (e.state === "idle") {
    await char.playVrma({ asset: "vrma:idle-maid", repeat: repeat.forever() });
    await char.lookAtCursor();
  } else if (e.state === "drag") {
    await char.playVrma({ asset: "vrma:grabbed", repeat: repeat.forever() });
  }
});
```

## 2. UI MOD (`settings`, `voicevox` 참고)

WebView 기반 React UI를 여는 MOD. 트레이나 우클릭 메뉴에 진입점을 등록.

```
mods/my-mod/
├── package.json
├── commands/
│   └── open-ui.ts      # Webview.open() 호출
└── ui/                 # React + Vite 앱
    ├── vite.config.ts
    └── src/
        ├── main.tsx
        └── App.tsx
```

```json
{
  "homunculus": {
    "tray": {
      "id": "open-my-mod",
      "text": "My Mod",
      "command": "my-mod-open-ui"
    },
    "assets": {
      "my-mod:ui": {
        "path": "ui/dist/index.html",
        "type": "html",
        "description": "My mod UI panel"
      }
    }
  },
  "bin": {
    "my-mod-open-ui": "commands/open-ui.ts"
  }
}
```

```typescript
// commands/open-ui.ts
import { Webview, webviewSource, audio } from "@hmcs/sdk";
import { output } from "@hmcs/sdk/commands";

try {
  await Webview.open({
    source: webviewSource.local("my-mod:ui"),
    size: [0.6, 0.6],
    viewportSize: [500, 400],
    offset: [1.1, 0],
  });
  await audio.se.play("se:open");
  output.succeed();
} catch (e) {
  output.fail("OPEN_UI_FAILED", (e as Error).message);
}
```

## 3. Service + UI MOD (`voicevox` 참고)

백그라운드 서비스와 WebView UI를 함께 가지는 MOD. service에서 상태를 관리하고, UI는 별도로 열 수 있다.

```json
{
  "homunculus": {
    "service": "service.ts",
    "menus": [
      {
        "id": "open-my-settings",
        "text": "My Settings",
        "command": "open-settings"
      }
    ],
    "assets": { "...": "..." }
  },
  "bin": {
    "open-settings": "commands/open-settings.ts"
  }
}
```
