# Knowledge Store — Phase 4: FastAPI 백엔드 리팩토링

**Date**: 2026-03-12
**Status**: Draft
**Part of**: Knowledge Store Design v3 (4-phase split)
**Scope**: FastAPI Director — 쓰기 역할 에이전트 위임, 읽기/검색 경량화, 세션 트리거 구현

---

## Context

Phase 4 이후에는 **쓰기는 NanoClaw 컨테이너 에이전트**가, **읽기/검색은 FastAPI**가 담당하는 구조로 분리된다.

```text
FastAPI (Director)
  KnowledgeBaseService (read-only, rg 기반)
  PersonaAgent tools → service 직접 참조 (HTTP loopback 없음)
  Session trigger: on_disconnect → DelegateTaskTool → NanoClaw
  GDrive mount: knowledge_base/ :ro
```

---

## 작업 목록

### 1. `KnowledgeBaseService` 읽기 및 검색 기능 구현

#### 클래스 인터페이스

```python
class KnowledgeBaseService:
    def search(self, query: str, tags: list[str]) -> list[SearchResult]: ...
    def read(self, path: str) -> str: ...
```

쓰기 메서드 전체 제거. 내부적으로 `rg` 서브프로세스를 호출한다.

#### rg 호출 패턴

```python
# 텍스트 검색
rg --json -C 2 "{query}" {KNOWLEDGE_BASE_PATH}

# 태그 필터 + 텍스트 검색
rg -l "tags:.*\b{tag}\b|^\s*-\s+{tag}\b" {KNOWLEDGE_BASE_PATH} \
  | xargs rg --json -C 2 "{query}"
```

#### Tool 연결 변경

- `SearchKnowledgeTool`, `ReadNoteTool` → HTTP 통신 없이 `KnowledgeBaseService`를 **직접 참조**하도록 구현
- PersonaAgent 초기화 시 서비스 인스턴스를 주입

---

### 2. Session Trigger 및 STM 로직 구현

#### `on_disconnect` 트리거 (`handlers.py`)

```python
# on_disconnect in handlers.py
stm_meta = await stm_service.get_metadata(session_id)
if (
    not stm_meta.get("knowledge_saved")
    and stm.human_message_count() >= MIN_TURNS_FOR_SUMMARY
):
    await stm_service.set_metadata(session_id, {"knowledge_saved": True})
    await delegate_knowledge_summary(session_id, user_id)
```

`MIN_TURNS_FOR_SUMMARY`는 `yaml_files/services/knowledge_base.yaml`에 설정 (기본값: `3`).

#### STM 컨텍스트 전달 전략 (Option A / B 분기)

세션 대화 턴 수에 따라 페이로드 구조를 분기한다.

| 조건 | 방식 | 설명 |
|---|---|---|
| `human_message_count < 30` | **Option A (inline)** | FastAPI가 STM 메시지를 payload에 직렬화하여 전달 |
| `human_message_count >= 30` | **Option B (host-side fetch)** | NanoClaw host가 컨테이너 시작 전 STM endpoint에서 직접 fetch |

`stm_inline_max_turns: 30`은 `yaml_files/services/knowledge_base.yaml`에 설정.

#### Option A 페이로드 (기본)

```json
{
  "task": "knowledge_summary",
  "session_id": "<str>",
  "user_id": "<str>",
  "callback_url": "http://fastapi-host:5500/v1/callback/nanoclaw/<session_id>",
  "stm_messages": [
    {"role": "human|ai", "content": "<str>"}
  ]
}
```

#### Option B 페이로드 (30턴 초과)

```json
{
  "task": "knowledge_summary",
  "session_id": "<str>",
  "user_id": "<str>",
  "callback_url": "http://fastapi-host:5500/v1/callback/nanoclaw/<session_id>",
  "stm_fetch_url": "http://fastapi-host:5500/v1/stm/{session_id}/messages"
}
```

NanoClaw host가 `stm_fetch_url`로 GET 요청하여 full context를 취득 후 컨테이너에 주입. **컨테이너 에이전트는 항상 full context를 받는다** — Option A/B 분기를 인식하지 않는다.

#### yaml 설정 파일 (`yaml_files/services/knowledge_base.yaml`)

```yaml
knowledge_base:
  path: /home/spow12/data/knowledge_base
  min_turns_for_summary: 3
  stm_inline_max_turns: 30
```

---

## 완료 체크리스트

- [ ] `/api/knowledge_base/*` 라우터 및 엔드포인트 삭제
- [ ] Bearer Auth 미들웨어 제거 (knowledge base 전용 부분)
- [ ] Node.js MCP 서버 구동 로직 제거
- [ ] `filelock`, `python-slugify` 패키지 삭제 후 `uv run pytest` 통과
- [ ] `KnowledgeBaseService` 쓰기 메서드 제거, `rg` 기반 search/read 구현
- [ ] `SearchKnowledgeTool`, `ReadNoteTool` → 서비스 직접 참조로 변경
- [ ] `handlers.py` on_disconnect 트리거 구현
- [ ] Option A/B 페이로드 분기 구현
- [ ] `yaml_files/services/knowledge_base.yaml` 설정 파일 추가
- [ ] `uv run pytest` 전체 통과
- [ ] `sh scripts/lint.sh` 통과
