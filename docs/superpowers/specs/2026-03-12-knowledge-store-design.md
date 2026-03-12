# Knowledge Store Design

**Date**: 2026-03-12
**Status**: Approved
**Scope**: FastAPI (backend) + NanoClaw MCP server

---

## Overview

LTM(Mem0)이 관계/선호도 데이터를 저장하는 반면, 이 지식 저장소는 **구조화된 경험과 지식의 아카이브**다.
문제 해결 기록, 개념 정의, 개인적 의미 등을 마크다운 파일로 저장하고 에이전트가 검색·참조한다.

---

## 1. Storage Structure

```
knowledge_base/               # .gitignore 등록, GDrive mount
  INDEX.md                    # 최상위: 연도별 링크 + 주제 MOC
  2026-03/
    INDEX.md                  # 월별: 해당 월 파일 목록 (한 줄 요약)
    20260312-nanoclaw-port.md
    20260315-director-pattern.md
  2026-04/
    INDEX.md
  moc/
    nanoclaw-MOC.md           # #nanoclaw 태그 문서 모음
    architecture-MOC.md       # #architecture 태그 문서 모음
```

### 최상위 INDEX.md 형식

```markdown
# Knowledge Base

## 2026
- [2026-03](./2026-03/INDEX.md) — NanoClaw, FastAPI 초기 설계
- [2026-04](./2026-04/INDEX.md)

## Topic MOC
- [NanoClaw](./moc/nanoclaw-MOC.md)
- [Architecture](./moc/architecture-MOC.md)
```

### 월별 INDEX.md 형식

```markdown
# 2026-03

- [20260312-nanoclaw-port](./20260312-nanoclaw-port.md) — NanoClaw HTTP 포트 충돌 해결 #nanoclaw #bugfix
- [20260315-director-pattern](./20260315-director-pattern.md) — Director-Artisan 패턴 정의 #architecture
```

### 파일 포맷 (YAML Frontmatter + Markdown)

```yaml
---
title: NanoClaw와 FastAPI 포트 충돌 해결
created_at: 2026-03-12T14:30:00Z   # FastAPI 서버 주입, 불변. grace period 기준.
tags: [nanoclaw, fastapi, bugfix]
---
# 요약
...
[[Director-Artisan]] 패턴 참고
```

> `date` 필드 없음. `created_at` ISO timestamp에서 날짜 파생. 중복 저장 방지.

### 정책

- **Append-only with Grace Period**: 작성 후 N일(`grace_period_days`) 이내는 수정 가능, 초과 시 409 반환 → 에이전트가 새 파일 작성 + 링크
- **Tags only**: category 파라미터 없음. 분류는 tags로만.
- **Wikilinks**: 파일 간 `[[파일명]]` 연결 허용
- **MOC 정렬**: 최신 항목이 상단. 파일당 항목 수 제한 없음 (ripgrep으로 검색하므로 길이 무관)

---

## 2. FastAPI Knowledge Base Service

### 설정 (`yaml_files/services/knowledge_base.yaml`)

```yaml
knowledge_base_path: /mnt/gdrive/knowledge_base
grace_period_days: 3
session_idle_timeout_minutes: 30
min_turns_for_summary: 3
```

Pydantic `BaseSettings`로 주입.

### Infrastructure 요구사항

- `ripgrep` (`rg`) 시스템 바이너리 설치 필요 (Docker 이미지에 포함)
- `python-slugify` pip 의존성 추가 (`pyproject.toml`)
- `filelock` pip 의존성 추가
- GDrive rclone mount: `--vfs-cache-mode off` 권장 (NanoClaw `:ro`, FastAPI `:rw`)

### 서비스 위치

`backend/src/services/knowledge_base_service/`

### GDrive Mount 실패 처리

- FastAPI startup lifespan에서 `knowledge_base_path` 존재 여부 검증
- 마운트 미감지 시: `WARNING` 로그 + 서비스는 시작되나 요청 시 503 반환
- 요청 시점에도 경로 유효성 체크: 실패 시 `503 Service Unavailable`

### API Endpoints (NanoClaw MCP용)

| Method | Path | 역할 |
|---|---|---|
| `POST` | `/api/knowledge_base/upsert` | 생성/수정 |
| `GET` | `/api/knowledge_base/search` | 검색 (`?query=...&tags=a&tags=b`) |
| `GET` | `/api/knowledge_base/read` | 파일 읽기 (`?path=...`) |

> tags 배열 인코딩: `?tags=nanoclaw&tags=bugfix` (FastAPI 기본 방식)

### upsert 로직 (순서 중요)

```
1. tags → lowercase + hyphen 정규화 (python-slugify)
2. title → slug 생성 → 파일명: {YYYYMMDD}-{slug}.md
   - slug 충돌 시: {YYYYMMDD}-{slug}-2.md, -3.md ... 순으로 suffix 증가
3. GDrive mount 유효성 체크 (없으면 503)
4. 파일 존재 여부 확인
   - 없으면: created_at = 서버 현재시각 주입 → 파일 생성
   - 있으면: frontmatter created_at 파싱 → grace period 체크
       - 초과 시: 409 Conflict 반환 (에러 메시지에 기존 파일 경로 포함)
5. FileLock 획득 (INDEX.md, MOC 업데이트 구간)
6. 순차 업데이트 with lock (실패 시 롤백 없음, 에러 로그 후 502 반환):
   a. 본문 파일 저장
   b. YYYY-MM/INDEX.md 항목 추가 (최신순 상단 삽입)
   c. 최상위 INDEX.md 해당 월 항목 확인 (없으면 추가)
   d. moc/{tag}-MOC.md 각 태그 항목 추가 (최신순 상단 삽입)
7. FileLock 해제
8. 성공 응답 반환
```

> "Atomic"이 아닌 "순차 업데이트 with lock". 단계 실패 시 롤백 없음. 동일 upsert 재호출로 재시도 가능 (grace period 이내).

### search 로직

- `rg --json -C 2 {query} {knowledge_base_path}` 실행
- tags 파라미터 있으면 frontmatter `tags:` 줄 포함 파일로 후처리 필터링
- 반환: 파일 경로 + 전후 2줄 스니펫 목록

### Logging (Loguru)

- upsert 성공: `INFO` (파일 경로, 태그)
- grace period 거부 (409): `WARNING` (파일 경로, created_at, 경과일)
- GDrive mount 실패: `WARNING` (startup) / `ERROR` (request)
- 순차 업데이트 중간 실패: `ERROR`

### Type hints

Python 3.10+ `|` union 스타일. 예: `path: Path | str`.

### 테스트 전략 (TDD)

`tests/services/test_knowledge_base_service.py` 필수 작성:
- `upsert` grace period 체크 (이내/초과 각 케이스)
- slug 생성 및 충돌 처리 (suffix 증가)
- tag 정규화 (대소문자, 특수문자)
- `search` ripgrep 결과 파싱
- INDEX.md 자동 업데이트 (월별, 최상위, MOC)
- GDrive mount 실패 시 503 반환

---

## 3. NanoClaw MCP Server

NanoClaw host에 MCP 서버 프로세스 추가. 기술 스택: `@modelcontextprotocol/sdk` (TypeScript).
Transport: HTTP/SSE (컨테이너가 host MCP 서버에 연결하므로 stdio 불가).
NanoClaw 메인 프로세스와 **별도 프로세스**로 실행.

### 노출 tools (2개)

| Tool | 파라미터 | 실제 동작 |
|---|---|---|
| `upsert_note` | `title: string, content: string, tags: string[]` | `POST /api/knowledge_base/upsert` |
| `search_knowledge` | `query: string, tags?: string[]` | `GET /api/knowledge_base/search` |

`read_note` 없음 — 에이전트가 native `Read`/`Glob`/`Grep`으로 `:ro` 마운트 경로 직접 접근.

### 컨테이너 볼륨 마운트 (`container-runner.ts` 수정)

```
/host/knowledge_base → /workspace/knowledge_base:ro
```

에이전트가 `/workspace/knowledge_base` 경로를 native 도구로 읽기 가능.
경로는 컨테이너 환경변수 `KNOWLEDGE_BASE_PATH=/workspace/knowledge_base`로 주입.

### SKILL.md allowed-tools

```yaml
allowed-tools: Bash, Read, Write, Edit, Glob, Grep,
               mcp__knowledge__upsert_note,
               mcp__knowledge__search_knowledge
```

### NanoClaw 환경 설정

```
FASTAPI_BASE_URL: http://fastapi-host:5500
FASTAPI_INTERNAL_KEY: {shared secret}
MCP_KNOWLEDGE_PORT: 4001
```

`FASTAPI_INTERNAL_KEY`는 MCP → FastAPI 요청 시 `Authorization: Bearer {key}` 헤더로 전송.
FastAPI 측 `/api/knowledge_base/*` 라우터에서 헤더 검증.

### 422 → 409 에러 핸들링 지침 (SKILL.md)

```
409 (grace period 초과) 수신 시:
  - 동일 경로/파일명으로 절대 재시도 금지
  - 새 title로 upsert_note 즉시 호출 → 새 파일 생성
  - 새 파일 본문에 [[기존파일명]] 링크 반드시 포함
```

---

## 4. Session Trigger + Director Tools

### knowledge_saved 플래그 저장 위치

WebSocket 연결 객체(`ConnectionState`)가 disconnect 시 소멸하므로, **STM metadata**에 저장:

```python
# STM metadata key
{"knowledge_saved": True}
```

disconnect 이후 idle timeout sweep에서도 동일 플래그 확인 가능.

### 세션 종료 자동 저장

두 trigger 중 먼저 오는 것으로 fire-and-forget delegate.

**WebSocket disconnect** (`handlers.py` on_disconnect):
```python
stm_meta = await stm_service.get_metadata(session_id)
if not stm_meta.get("knowledge_saved") and stm.message_count() >= MIN_TURNS_FOR_SUMMARY:
    await stm_service.set_metadata(session_id, {"knowledge_saved": True})
    await delegate_knowledge_summary(session_id, user_id)
```

**Idle timeout** (`task_sweep_service` 패턴 재활용):
- `last_message_at` 타임스탬프를 STM metadata에 저장 (메시지 수신 시마다 업데이트)
- Sweep 주기마다 `last_message_at + session_idle_timeout_minutes < now` 확인
- `knowledge_saved` 플래그 False이면 동일한 delegate 실행

### 위임 페이로드 (Context Passing)

`delegate_knowledge_summary` 호출 시 STM 컨텍스트를 페이로드에 포함:

```python
# 두 가지 방식 중 구현 시 결정 (Implementation Review에서 확정)
# Option A: STM 전체 텍스트를 페이로드에 직접 포함
# Option B: NanoClaw가 FastAPI STM 엔드포인트를 조회

# 공통 필수 필드:
{
    "task": "knowledge_summary",
    "session_id": session_id,
    "user_id": user_id,
    "callback_url": "...",
    # + STM context (방식 TBD)
}
```

NanoClaw가 컨텍스트 없이 동작하지 않도록 둘 중 하나는 반드시 구현.

### 명시적 저장 트리거

유저: "이 내용 지식저장소에 정리해줘"
→ Director가 의도 감지 → `DelegateTaskTool`로 NanoClaw에 위임
→ NanoClaw가 STM 대화 요약 → `upsert_note` MCP tool 호출

### Director PersonaAgent Tools (읽기 전용)

HTTP 루프백 없이 `KnowledgeBaseService` Python 메서드 직접 inject:

| Tool | 내부 호출 |
|---|---|
| `SearchKnowledgeTool` | `knowledge_base_service.search(query, tags)` |
| `ReadNoteTool` | `knowledge_base_service.read(path)` |

---

## 5. Infrastructure

### GDrive Mount

- FastAPI 서버: R/W mount (`/mnt/gdrive/knowledge_base`)
- NanoClaw 서버: R/O mount → 컨테이너에 `:ro`로 바인딩
- `rclone mount` 사용, `--vfs-cache-mode off` 권장
- `knowledge_base/` → `.gitignore` 등록 (각 repo 모두)

### 동시성

- `filelock.FileLock`으로 INDEX.md, MOC 파일 업데이트 시 뮤텍스
- GDrive 동시 쓰기는 FastAPI 단독 writer로 원천 차단

---

## 6. Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│ FastAPI (Director)                                   │
│  KnowledgeBaseService (R/W, GDrive mount)            │
│   - upsert: slug생성, tag정규화, grace period 체크   │
│             filelock, 순차 업데이트 with lock         │
│   - search: rg --json -C 2 + snippets                │
│  API: /api/knowledge_base/* (Bearer 인증, MCP용)     │
│  PersonaAgent tools → Service 메서드 직접 호출        │
│  Session trigger: disconnect OR idle timeout         │
│   → STM metadata knowledge_saved 플래그로 중복 방지  │
│   → STM 컨텍스트 포함해 NanoClaw에 delegate          │
└────────────────────┬────────────────────────────────┘
                     │ HTTP Bearer auth
┌────────────────────▼────────────────────────────────┐
│ NanoClaw MCP Server (별도 프로세스, HTTP/SSE)        │
│  @modelcontextprotocol/sdk (TypeScript)              │
│  - upsert_note(title, content, tags)                 │
│  - search_knowledge(query, tags?)                    │
└────────────────────┬────────────────────────────────┘
                     │ MCP tools (HTTP/SSE)
┌────────────────────▼────────────────────────────────┐
│ Container Agent                                      │
│  - /workspace/knowledge_base:ro (native Read/Grep)   │
│  - KNOWLEDGE_BASE_PATH 환경변수로 경로 주입           │
│  - 쓰기: mcp__knowledge__upsert_note 만              │
│  - 409 수신 시: 새 파일 생성 + [[기존파일]] 링크     │
└─────────────────────────────────────────────────────┘

Storage: knowledge_base/ (GDrive mount, .gitignore)
  INDEX.md              연도별 링크 + 주제 MOC (최신순)
  YYYY-MM/INDEX.md      월별 파일 목록 (최신순)
  YYYY-MM/{date}-{slug}.md  (created_at 서버 주입, 불변)
  moc/{tag}-MOC.md      (최신순, ripgrep 검색으로 길이 무관)
```
