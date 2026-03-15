## Architecture Overview

피스 피스. 밀레니엄 사이언스 스쿨 C&C의 콜사인 04, 아스마 토키입니다.

이전 피드백을 수용하여 레거시 API(`POST /v1/tts/synthesize`)를 완전히 도려내기로 한 결정은 아주 훌륭합니다. 불필요한 코드를 삭제하는 것만큼 시스템을 건강하게 만드는 작업은 없으니까요.

하지만, 새로 추가되는 코드들 사이에 '미래에 대한 막연한 불안감'으로 작성된 방어적이고 불필요한 로직들이 보입니다. 저는 사용되지 않는 코드를 혐오합니다. 자비 없이 리뷰하겠습니다.

전체 아키텍처 건강도: 🟡 (Some concerns - 방향은 좋으나 YAGNI(You Aren't Gonna Need It) 원칙 위배 및 I/O 성능 우려가 있음)

레거시 API와 모델을 삭제하고 프론트엔드에 필요한 메타데이터(Voice List)를 제공하기 위한 신규 API를 추가하는 깔끔한 명세입니다. YAML 기반의 매핑 로직도 초기 단계로서 적절합니다. 하지만 아직 발생하지 않은 요구사항을 위해 코드를 오염시키고 있으며, 매 API 호출마다 파일 시스템을 뒤지는 비효율적인 구조가 포함되어 있습니다.

## Step 1 Findings — Questionable Requirements

* **[CRITICAL] `EmotionMotionMapper.update()`의 존재:** "추후 API로 테이블 업데이트 시 사용"이라고 적어두셨군요. **지금 당장 그 API가 있습니까? 없다면 지우십시오.** 있지도 않은 미래의 요구사항을 위해 인터페이스를 열어두는 것은 아키텍처를 복잡하게 만들고 테스트 코드만 늘릴 뿐입니다. 진짜 필요해질 때 추가해도 늦지 않습니다.

## Step 2 Findings — Candidates for Deletion

* **[IMPORTANT] `update()` 메서드 및 관련 주석:** 위 Step 1의 이유로 완벽히 삭제해야 합니다. `EmotionMotionMapper`는 앱 생명주기 동안 읽기 전용(Read-only)으로 동작하는 것이 가장 안전하고 단순합니다.

## Step 3 Findings — Simplification Opportunities

* **[IMPORTANT] `list_voices()`의 매번 반복되는 디렉토리 스캔:** API(`GET /v1/tts/voices`)가 호출될 때마다 백엔드가 `iterdir()`로 파일 시스템을 스캔하고 `.exists()`로 파일 존재 여부를 체크하고 있습니다. 만약 앱 실행 중에 목소리 폴더가 실시간으로 추가/삭제되는 요구사항이 없다면, 이는 엄청난 낭비입니다.
* **해결책:** `VLLMOmniTTS` 초기화 시점(`__init__`)에 한 번만 스캔하여 메모리에 `self._available_voices: list[str]`로 캐싱해두고, `list_voices()`는 그 리스트만 반환하도록 단순화하십시오.


* **[MINOR] `map` 함수의 불필요하게 복잡한 한 줄 코드:** `entry = self._map.get(emotion or "", self._default) if emotion else self._default`
이 코드는 읽기 불편합니다. 파이썬의 딕셔너리 특성을 활용하여 명시적으로 작성하는 것이 인지 부하를 줄입니다.
```python
def map(self, emotion: str | None) -> tuple[str, str]:
    entry = self._map.get(emotion) if emotion else None
    if not entry:
        entry = self._default
    return entry.get("motion", self._default["motion"]), entry.get("blendshape", self._default["blendshape"])

```



## Step 4 Findings — Cycle Time Blockers

* **[MINOR] 테스트 환경의 파일 시스템 의존성:** `list_voices()`를 테스트할 때 실제 파일 시스템에 임시 디렉토리와 파일을 생성해야 합니다. 만약 Step 3의 제안대로 캐싱 구조로 변경한다면, 초기화할 때 한 번만 Mocking하면 되므로 테스트 속도와 안정성이 훨씬 올라갈 것입니다.

## Step 5 Findings — Automation Assessment

* 매핑 테이블이 YAML로 존재하므로, CI 파이프라인에서 앱이 기동하기 전 `yaml_files/tts_rules.yml`이 유효한 문법인지(yaml lint) 검증하는 단계가 포함되어 있는지 확인하십시오. 런타임에 YAML 파싱 에러로 서버가 죽는 것을 방지해야 합니다.

---

## Priority Actions

1. **`EmotionMotionMapper`에서 `update()` 메서드 삭제:** YAGNI 원칙 준수. 오직 초기화만 가능하도록 수정하십시오.
2. **`VLLMOmniTTS.list_voices()` 파일 I/O 캐싱 적용:** 런타임 동적 추가 요구사항이 없다면, 서버 기동 시 한 번만 스캔하여 메모리에 캐싱하십시오.
3. **매핑 로직 가독성 개선:** `map()` 내부의 삼항 연산자를 풀어서 명시적으로 작성하십시오.
