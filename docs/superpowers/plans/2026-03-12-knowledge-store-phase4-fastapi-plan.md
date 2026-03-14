# Knowledge Store Phase 4: FastAPI 백엔드 리팩토링 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 knowledge base HTTP 엔드포인트/MCP 서버를 제거하고, `KnowledgeBaseService`를 rg 기반 읽기 전용으로 교체하며, 세션 종료 시 NanoClaw에 knowledge summary를 위임하는 트리거를 구현한다.

**Architecture:** `KnowledgeBaseService`는 `rg` subprocess로 search/read만 제공. `SearchKnowledgeTool`/`ReadNoteTool`은 서비스를 직접 참조(HTTP loopback 없음). `on_disconnect`에서 STM 턴 수 기준으로 Option A(inline) / Option B(fetch URL) 페이로드를 분기하여 NanoClaw에 delegate.

**Tech Stack:** Python 3.13, FastAPI, uv, pytest, rg(ripgrep), Pydantic V2, LangGraph

---


## Chunk 1: `KnowledgeBaseService` 읽기 전용 구현

**Files:**
- Create: `backend/src/services/knowledge_base_service/__init__.py`
- Create: `backend/src/services/knowledge_base_service/service.py`
- Create: `backend/tests/services/test_knowledge_base_service.py`
- Create: `backend/yaml_files/services/knowledge_base.yaml`

### Task 1: yaml 설정 파일 추가

- [ ] `backend/yaml_files/services/knowledge_base.yaml` 생성

  ```yaml
  knowledge_base:
    path: /home/spow12/data/knowledge_base
    min_turns_for_summary: 3
    stm_inline_max_turns: 30
  ```

### Task 2: TDD — SearchResult 모델 + search 메서드

- [ ] 실패 테스트 작성

  ```python
  # backend/tests/services/test_knowledge_base_service.py
  def test_search_returns_results(tmp_path):
      # tmp_path에 샘플 md 파일 생성
      note = tmp_path / "20260312-test.md"
      note.write_text("---\ntitle: Test\ntags: [test]\n---\ntest content here")

      svc = KnowledgeBaseService(kb_path=str(tmp_path))
      results = svc.search(query="test content", tags=[])
      assert len(results) > 0
      assert "test content" in results[0].content
  ```

- [ ] 테스트 실패 확인

  ```bash
  uv run pytest tests/services/test_knowledge_base_service.py -v
  ```

  Expected: FAIL (ImportError)

- [ ] `KnowledgeBaseService` 구현

  ```python
  # backend/src/services/knowledge_base_service/service.py
  import subprocess
  from dataclasses import dataclass

  @dataclass
  class SearchResult:
      path: str
      content: str

  class KnowledgeBaseService:
      def __init__(self, kb_path: str) -> None:
          self.kb_path = kb_path

      def search(self, query: str, tags: list[str]) -> list[SearchResult]: ...
      def read(self, path: str) -> str: ...
  ```

- [ ] 테스트 통과 확인

  ```bash
  uv run pytest tests/services/test_knowledge_base_service.py -v
  ```

  Expected: PASS

### Task 3: TDD — read 메서드

- [ ] 실패 테스트 작성

  ```python
  def test_read_returns_file_content(tmp_path):
      note = tmp_path / "20260312-test.md"
      note.write_text("---\ntitle: Test\n---\ncontent")

      svc = KnowledgeBaseService(kb_path=str(tmp_path))
      content = svc.read(str(note))
      assert "content" in content
  ```

- [ ] 테스트 통과 확인 (구현 후)

  ```bash
  uv run pytest tests/services/test_knowledge_base_service.py -v
  ```

- [ ] 커밋

  ```bash
  git add backend/src/services/knowledge_base_service/ \
          backend/tests/services/test_knowledge_base_service.py \
          backend/yaml_files/services/knowledge_base.yaml
  git commit -m "feat: add KnowledgeBaseService read-only (rg-based)"
  ```

---

## Chunk 2: Tool 연결 변경

**Files:**
- Create: `backend/src/services/agent_service/tools/knowledge/search_knowledge.py`
- Create: `backend/src/services/agent_service/tools/knowledge/read_note.py`
- Create: `backend/src/services/agent_service/tools/knowledge/__init__.py`
- Create: `backend/tests/services/agent_service/tools/test_knowledge_tools.py`

### Task 4: TDD — SearchKnowledgeTool

- [ ] 실패 테스트 작성

  ```python
  # tests/services/agent_service/tools/test_knowledge_tools.py
  def test_search_knowledge_tool_calls_service(tmp_path):
      svc = KnowledgeBaseService(kb_path=str(tmp_path))
      tool = SearchKnowledgeTool(service=svc)
      result = tool.run({"query": "hello", "tags": []})
      assert isinstance(result, list)
  ```

- [ ] 테스트 실패 확인, 구현, 통과 확인

  ```bash
  uv run pytest tests/services/agent_service/tools/test_knowledge_tools.py -v
  ```

- [ ] ReadNoteTool 동일 패턴으로 구현 + 테스트

- [ ] PersonaAgent 초기화 시 서비스 인스턴스 주입 확인 (기존 agent_factory.py 수정)

- [ ] 커밋

  ```bash
  git add backend/src/services/agent_service/tools/knowledge/ \
          backend/tests/services/agent_service/tools/test_knowledge_tools.py
  git commit -m "feat: wire SearchKnowledgeTool and ReadNoteTool to service directly"
  ```

---

## Chunk 3: Session Trigger + STM Option A/B 분기

**Files:**
- Modify: `backend/src/services/websocket_service/manager/handlers.py`
- Create: `backend/tests/services/websocket_service/test_knowledge_trigger.py`

### Task 5: TDD — on_disconnect 트리거 조건

- [ ] 실패 테스트 작성

  ```python
  # tests/services/websocket_service/test_knowledge_trigger.py
  async def test_trigger_fires_when_conditions_met(mock_stm, mock_delegate):
      # knowledge_saved=False, human_message_count=5 (>= MIN_TURNS=3)
      mock_stm.get_metadata.return_value = {"knowledge_saved": False}
      mock_stm.human_message_count.return_value = 5

      await on_disconnect_handler(session_id="s1", user_id="u1",
                                   stm_service=mock_stm, delegate=mock_delegate)

      mock_delegate.assert_called_once()

  async def test_trigger_skips_when_already_saved(mock_stm, mock_delegate):
      mock_stm.get_metadata.return_value = {"knowledge_saved": True}
      await on_disconnect_handler(...)
      mock_delegate.assert_not_called()

  async def test_trigger_skips_when_insufficient_turns(mock_stm, mock_delegate):
      mock_stm.get_metadata.return_value = {"knowledge_saved": False}
      mock_stm.human_message_count.return_value = 1  # < MIN_TURNS=3
      await on_disconnect_handler(...)
      mock_delegate.assert_not_called()
  ```

- [ ] 테스트 실패 확인, 구현, 통과 확인

  ```bash
  uv run pytest tests/services/websocket_service/test_knowledge_trigger.py -v
  ```

### Task 6: TDD — Option A / B 페이로드 분기

- [ ] 실패 테스트 작성

  ```python
  async def test_option_a_payload_when_turns_below_threshold(mock_stm):
      mock_stm.human_message_count.return_value = 5   # < 30
      mock_stm.get_messages.return_value = [{"role": "human", "content": "hi"}]

      payload = build_delegate_payload(session_id="s1", user_id="u1", stm=mock_stm)

      assert "stm_messages" in payload
      assert "stm_fetch_url" not in payload

  async def test_option_b_payload_when_turns_above_threshold(mock_stm):
      mock_stm.human_message_count.return_value = 35  # >= 30

      payload = build_delegate_payload(session_id="s1", user_id="u1", stm=mock_stm)

      assert "stm_fetch_url" in payload
      assert "stm_messages" not in payload
  ```

- [ ] 테스트 실패 확인, 구현, 통과 확인

  ```bash
  uv run pytest tests/services/websocket_service/test_knowledge_trigger.py -v
  ```

- [ ] handlers.py에 트리거 로직 통합

- [ ] 커밋

  ```bash
  git add backend/src/services/websocket_service/manager/handlers.py \
          backend/tests/services/websocket_service/test_knowledge_trigger.py
  git commit -m "feat: add on_disconnect knowledge summary trigger with Option A/B STM branching"
  ```

---

## 완료 검증

- [ ] `uv run pytest` 전체 PASS

  ```bash
  cd backend && uv run pytest
  ```

- [ ] lint 통과

  ```bash
  sh scripts/lint.sh
  ```

- [ ] knowledge_base 관련 엔드포인트 없음 확인

  ```bash
  grep -rn "knowledge_base" backend/src/api/ --include="*.py"
  ```

  Expected: 없음 (또는 import 없음)
