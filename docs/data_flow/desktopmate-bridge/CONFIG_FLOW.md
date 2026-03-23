# desktopmate-bridge Config Flow

Updated: 2026-03-22

## Read (초기화)

config.yaml → loadConfig() → broadcastConfig() → dm-config 신호 → UI store.settings

## Write (updateConfig RPC)

UI Save 버튼 → rpc.call('updateConfig', cfg) → service.ts updateConfig()
  → config 객체 in-place 수정 → writeFileSync(CONFIG_PATH, yaml.dump(config))
  → broadcastConfig() → dm-config 신호 → UI store.settings 갱신

## Diagram

```mermaid
sequenceDiagram
    participant UI as React UI
    participant Svc as service.ts
    participant YAML as config.yaml
    participant Store as Zustand Store

    Note over Svc: 서비스 시작
    Svc->>YAML: loadConfig()
    Svc->>UI: signals.send("dm-config", cfg)
    UI->>Store: setSettings(cfg)

    Note over UI: 사용자가 Settings 저장
    UI->>Svc: rpc.call("updateConfig", cfg)
    Svc->>Svc: Object.assign(config, cfg)
    Svc->>YAML: writeFileSync(CONFIG_PATH, yaml.dump(config))
    Svc->>UI: signals.send("dm-config", cfg)
    UI->>Store: setSettings(cfg)
```
