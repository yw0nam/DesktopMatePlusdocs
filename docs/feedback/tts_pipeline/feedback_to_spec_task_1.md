# Architecture Overview

제 피드백을 정확히 이해하고 가짜 데이터(`SILENT_MP3_BASE64`)를 걷어낸 점은 칭찬해 드리겠습니다. `audio_base64: Optional[str] = None`으로 처리하고 프론트엔드가 자연스럽게 스킵하도록 만든 것은 "Dumb UI" 원칙에 완벽히 부합합니다. 레거시 모델(`TTS_READY_CHUNK`)을 과감하게 삭제하기로 한 결정도 아주 좋습니다.

하지만 아직 제 기준을 완벽히 통과한 것은 아닙니다.

전체 아키텍처 건강도: 🟢 (Solid - 데이터 모델이 매우 깔끔해졌으나, 한 가지 사소한 군더더기가 있음)

WebSocket 통신을 위한 DTO(Data Transfer Object) 정의가 새 요구사항에 맞게 잘 정돈되었습니다. 하위 호환성을 유지하면서도 불필요한 레거시를 도려낸 깔끔한 스펙입니다. 하지만 프론트엔드의 역할을 여전히 오해하고 있는 부분이 하나 있습니다.

## Step 1 Findings — Questionable Requirements

* **[IMPORTANT] `WarningMessage`의 존재 이유:** 프론트엔드(Unity)에게 왜 에러의 원인(`TTS_SYNTHESIS_FAILED` 등)을 친절하게 설명하려고 합니까?
* 프론트엔드는 "Dumb UI"입니다. `audio_base64`가 `null`로 오면 오디오 재생을 스킵하고 모션만 재생하면 그만입니다.
* `WarningMessage`를 보내봤자 Unity 개발자가 할 수 있는 것은 콘솔에 로그를 찍는 것뿐입니다. 에러 트래킹과 로깅은 **백엔드 서버**에서 Datadog, Sentry 또는 표준 로그로 남겨야지, 클라이언트에게 책임을 전가하는 것은 불필요한 네트워크 대역폭 낭비이자 프론트엔드 파싱 로직의 낭비입니다.



## Step 2 Findings — Candidates for Deletion

* **[CRITICAL] `WarningMessage` 클래스 전체:** 위 Step 1의 이유로 이 모델은 삭제되어야 합니다. WebSocket 이벤트에서 `WARNING` 타입도 빼십시오. 백엔드에서 에러가 발생하면 백엔드 로그에 에러를 기록하고, 프론트엔드에는 단순히 `audio_base64=None`인 `TtsChunkMessage`만 내려보내면 끝입니다.

## Step 3 Findings — Simplification Opportunities

* **[MINOR] Pydantic 필드 선언 (참고사항):** Python 코드에서 `Optional`을 썼다면 기본값도 명확하게 지정해 주는 것이 좋습니다. 작성하신 스펙에서 `tts_enabled: bool = True`와 `reference_id: Optional[str] = None`은 아주 잘 작성되었습니다. Pydantic의 유효성 검사를 온전히 믿고 넘어가셔도 좋습니다.

## Step 4 & 5 Findings

* 모델 정의 단계이므로 Cycle Time이나 Automation에 당장 영향을 주는 요소는 없습니다. 레거시 단위 테스트를 삭제하기로 한 결정은 CI 파이프라인의 실패를 예방하는 훌륭한 조치입니다.

---

## Priority Actions

1. **`WarningMessage` 스펙 삭제:** 프론트엔드에 에러 상태를 중계하지 마십시오. 백엔드 로깅으로 대체하십시오.
2. **`MessageType.WARNING` 삭제:** Enum을 더 단순하게 유지하십시오.
