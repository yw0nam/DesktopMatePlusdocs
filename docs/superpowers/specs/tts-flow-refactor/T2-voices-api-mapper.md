# T2: 참조 API & EmotionMotionMapper

**선행 조건**: 없음 (T1과 병렬 가능)
**차단 대상**: T3 (EmotionMotionMapper), T4 (list_voices 불필요)

---

## 목표

1. `GET /v1/tts/voices` — 사용 가능한 reference voice 목록 API
2. `EmotionMotionMapper` — emotion → motion/blendshape 매핑
3. `POST /v1/tts/synthesize` — 즉시 삭제

---

## 변경 파일

### `src/api/routes/tts.py`

#### 삭제

- `POST /v1/tts/synthesize` 핸들러 전체 삭제
- `src/models/tts.py`의 `TTSRequest`, `TTSResponse` 임포트 제거

#### 추가: `GET /v1/tts/voices`

```python
@router.get(
    "/v1/tts/voices",
    summary="List available TTS reference voices",
    response_model=VoicesResponse,
    responses={503: {"description": "TTS service not initialized"}},
)
async def list_voices() -> VoicesResponse:
    tts_service = get_tts_service()
    if tts_service is None:
        raise HTTPException(status_code=503, detail="TTS service not available")
    voices = tts_service.list_voices()
    return VoicesResponse(voices=voices)
```

**응답 모델** (`src/models/tts.py`에 추가):

```python
class VoicesResponse(BaseModel):
    voices: list[str]   # ref_audio_dir/ 하위 유효 디렉토리명 목록
```

**에러**:
- `503`: TTS 서비스 미초기화
- `ref_audio_dir` 미존재 → 빈 리스트 반환 (예외 없음)

---

### `src/services/tts_service/service.py`

`list_voices()` 추상 메서드 추가:

```python
@abstractmethod
def list_voices(self) -> list[str]:
    """사용 가능한 reference voice ID 목록 반환."""
    pass
```

---

### `src/services/tts_service/vllm_omni.py`

서버 기동 시 `__init__`에서 한 번만 스캔하여 캐싱. 런타임 중 동적 추가/삭제 요구사항 없음.

```python
def __init__(self, ...):
    ...
    # 서버 기동 시 한 번만 스캔
    self._available_voices: list[str] = self._scan_voices()

def _scan_voices(self) -> list[str]:
    """ref_audio_dir/ 하위에서 유효한 voice 디렉토리 스캔.
    유효 조건: merged_audio.mp3 + combined.lab 모두 존재."""
    if not self.ref_audio_dir.exists():
        return []
    voices = []
    for d in sorted(self.ref_audio_dir.iterdir()):
        if d.is_dir():
            if (d / "merged_audio.mp3").exists() and (d / "combined.lab").exists():
                voices.append(d.name)
    return voices

def list_voices(self) -> list[str]:
    return self._available_voices
```

---

### `src/services/tts_service/fish_speech.py`

```python
def list_voices(self) -> list[str]:
    """FishSpeech는 reference voice 디렉토리 구조 없음."""
    return []
```

---

### `src/services/tts_service/emotion_motion_mapper.py` — 신규

```python
class EmotionMotionMapper:
    """YAML emotion_motion_map 섹션 기반 매핑. Dummy 테이블로 시작."""

    def __init__(self, config: dict[str, dict[str, str]]):
        self._map = config
        self._default = config.get("default", {"motion": "neutral_idle", "blendshape": "neutral"})

    def map(self, emotion: str | None) -> tuple[str, str]:
        """Returns (motion_name, blendshape_name). 미등록/None → default."""
        entry = self._map.get(emotion) if emotion else None
        if not entry:
            entry = self._default
        return entry.get("motion", self._default["motion"]), entry.get("blendshape", self._default["blendshape"])
```

---

### `src/services/service_manager.py`

```python
_emotion_motion_mapper_instance: EmotionMotionMapper | None = None

def initialize_emotion_motion_mapper() -> EmotionMotionMapper:
    """yaml_files/tts_rules.yml의 emotion_motion_map 섹션 로드.
    TTSTextProcessor의 tts_rules.yml 로드 방식과 동일한 loader 사용."""
    global _emotion_motion_mapper_instance
    config = load_yaml("yaml_files/tts_rules.yml")
    _emotion_motion_mapper_instance = EmotionMotionMapper(config.get("emotion_motion_map", {}))
    return _emotion_motion_mapper_instance

def get_emotion_motion_mapper() -> EmotionMotionMapper | None:
    return _emotion_motion_mapper_instance
```

`src/main.py` lifespan에 `initialize_emotion_motion_mapper()` 호출 추가.

---

### `yaml_files/tts_rules.yml` — 섹션 추가

```yaml
emotion_motion_map:
  joyful:        { motion: "happy_idle",     blendshape: "smile" }
  sad:           { motion: "sad_idle",       blendshape: "sad" }
  angry:         { motion: "angry_idle",     blendshape: "angry" }
  surprised:     { motion: "surprised_idle", blendshape: "surprised" }
  scared:        { motion: "scared_idle",    blendshape: "scared" }
  disgusted:     { motion: "disgusted_idle", blendshape: "disgusted" }
  confused:      { motion: "confused_idle",  blendshape: "confused" }
  curious:       { motion: "curious_idle",   blendshape: "curious" }
  worried:       { motion: "worried_idle",   blendshape: "worried" }
  satisfied:     { motion: "satisfied_idle", blendshape: "smile" }
  sarcastic:     { motion: "neutral_idle",   blendshape: "smirk" }
  laughing:      { motion: "laughing_idle",  blendshape: "laugh" }
  crying loudly: { motion: "crying_idle",    blendshape: "cry" }
  sighing:       { motion: "sigh_idle",      blendshape: "tired" }
  whispering:    { motion: "whisper_idle",   blendshape: "neutral" }
  hesitating:    { motion: "hesitate_idle",  blendshape: "nervous" }
  default:       { motion: "neutral_idle",   blendshape: "neutral" }
```

---

## 삭제 대상

- `src/models/tts.py` — `TTSRequest`, `TTSResponse` (voices API용 `VoicesResponse`만 남김)
- `docs/api/TTS_Synthesize.md` — 삭제

---

## 테스트

### 단위 테스트

**EmotionMotionMapper**:
- 등록된 emotion → 올바른 `(motion, blendshape)` 반환
- 미등록 emotion → default 반환
- `None` → default 반환

**VLLMOmniTTS.list_voices()**:
- `__init__` 시점에 스캔 → `list_voices()` Mock 불필요, 초기화 시 1회만 Mock
- `ref_audio_dir` 미존재 → `[]`
- 유효 디렉토리(mp3+lab 모두 있음) → 목록에 포함
- 불완전 디렉토리(mp3만) → 목록에서 제외

**GET /v1/tts/voices**:
- TTS 서비스 정상 → 200 + voices 목록
- TTS 서비스 미초기화 → 503

---

## 참고: CI YAML 검증

`yaml_files/tts_rules.yml` 런타임 파싱 에러로 서버가 죽는 것을 방지하기 위해, CI 파이프라인에서 앱 기동 전 yaml lint 단계 추가를 별도 작업으로 고려할 것. (T2 구현 범위 외)
