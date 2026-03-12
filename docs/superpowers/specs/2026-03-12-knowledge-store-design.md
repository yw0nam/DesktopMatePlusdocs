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
created_at: 2026-03-12T14:30:00Z   # FastAPI 서버 주입, 불변
date: 2026-03-12
tags: [nanoclaw, fastapi, bugfix]
---
# 요약
...
[[Director-Artisan]] 패턴 참고
```

### 정책

- **Append-only with Grace Period**: 작성 후 N일(`grace_period_days`) 이내는 수정 가능, 초과 시 새 파일 작성 + 링크
- **Wikilinks**: 파일 간 `[[파일명]]` 연결 허용
- **Tags only**: category 파라미터 없음. 분류는 tags로만.

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

### 서비스 위치

`backend/src/services/knowledge_base_service/`

### API Endpoints (NanoClaw MCP용)

| Method | Path | 역할 |
|---|---|---|
| `POST` | `/api/knowledge_base/upsert` | 생성/수정 |
| `GET` | `/api/knowledge_base/search` | 검색 |
| `GET` | `/api/knowledge_base/read` | 파일 읽기 |

### upsert 로직 (순서 중요)

```
1. tags → lowercase + hyphen 정규화 (python-slugify)
2. title → slug 생성 → 파일명: {YYYYMMDD}-{slug}.md
3. 파일 존재 여부 확인
   - 없으면: created_at 서버 주입 → 파일 생성
   - 있으면: created_at 읽어서 grace period 체크
       - 초과 시: 422 반환 (에러 메시지에 기존 파일 경로 포함)
4. FileLock 획득
5. Atomic 업데이트 (try/except, 순서 고정):
   a. 본문 파일 저장
   b. YYYY-MM/INDEX.md 항목 추가/갱신
   c. 최상위 INDEX.md 해당 월 항목 확인 (없으면 추가)
   d. moc/{tag}-MOC.md 각 태그 항목 추가
6. FileLock 해제
7. 성공 응답 반환
```

### search 로직

- `ripgrep --json -C 2` 로 키워드 검색
- tags 파라미터 있으면 frontmatter tag 필터 적용
- 반환: 파일 경로 + 전후 2줄 스니펫 목록

### Logging (Loguru)

- upsert 성공: `INFO` (파일 경로, 태그)
- grace period 거부: `WARNING` (파일 경로, 작성일, 경과일)
- atomic 업데이트 실패: `ERROR`

### Type hints

Python 3.10+ `|` union 스타일. 예: `path: Path | str`.

---

## 3. NanoClaw MCP Server

NanoClaw host에 경량 MCP 서버 프로세스 추가.

### 노출 tools (2개)

| Tool | 파라미터 | 실제 동작 |
|---|---|---|
| `upsert_note` | `title: str, content: str, tags: list[str]` | `POST /api/knowledge_base/upsert` |
| `search_knowledge` | `query: str, tags: list[str] \| None` | `GET /api/knowledge_base/search` |

`read_note` 없음 — 에이전트가 native `Read`/`Glob`/`Grep`으로 직접 접근.

### 컨테이너 볼륨 마운트

```
/host/knowledge_base → /workspace/knowledge_base:ro
```

에이전트가 native 도구로 파일 읽기 가능. 쓰기는 MCP tool만.

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
```

### 422 에러 핸들링 지침 (SKILL.md)

```
422 (grace period 초과) 수신 시:
  - 동일 경로/파일명으로 절대 재시도 금지
  - 새 title로 upsert_note 즉시 호출 → 새 파일 생성
  - 새 파일 본문에 [[기존파일명]] 링크 반드시 포함
```

---

## 4. Session Trigger + Director Tools

### 세션 종료 자동 저장

두 trigger 중 먼저 오는 것으로 fire-and-forget delegate. `knowledge_saved` 플래그로 중복 방지.

**WebSocket disconnect** (`handlers.py` on_disconnect):
```python
if not session.knowledge_saved and stm.message_count() >= MIN_TURNS_FOR_SUMMARY:
    session.knowledge_saved = True
    await delegate_knowledge_summary(session_id, user_id, stm_context)
```

**Idle timeout** (기존 `task_sweep_service` 패턴 재활용):
- 마지막 메시지 후 `session_idle_timeout_minutes` 초과
- `knowledge_saved` 플래그 확인 후 동일한 delegate 실행

### 위임 페이로드

`delegate_knowledge_summary` 호출 시 STM 컨텍스트 포함:
- STM 직접 조회 vs 페이로드 직접 포함 방식은 추후 Review에서 결정
- NanoClaw가 컨텍스트 없이 동작하지 않도록 보장

### 명시적 저장 트리거

유저: "이 내용 지식저장소에 정리해줘"
→ Director가 의도 감지 → `DelegateTaskTool`로 NanoClaw에 위임
→ NanoClaw가 STM 대화 요약 → `upsert_note` MCP tool 호출

### Director PersonaAgent Tools (읽기 전용)

HTTP 루프백 없이 `KnowledgeBaseService` Python 메서드 직접 호출:

| Tool | 내부 호출 |
|---|---|
| `SearchKnowledgeTool` | `knowledge_base_service.search(query, tags)` |
| `ReadNoteTool` | `knowledge_base_service.read(path)` |

---

## 5. Infrastructure

### GDrive Mount

- FastAPI 서버: R/W mount (`/mnt/gdrive/knowledge_base`)
- NanoClaw 서버: R/O mount (컨테이너에 `:ro`로 바인딩)
- 두 서버 모두 `rclone mount` 사용, `--vfs-cache-mode off` 권장
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
│             filelock, atomic 3곳 업데이트             │
│   - search: ripgrep --json -C 2 + snippets           │
│  API: /api/knowledge_base/* (NanoClaw MCP용)         │
│  PersonaAgent tools → Service 직접 호출              │
│  Session trigger: disconnect OR idle timeout         │
│   → knowledge_saved 플래그로 중복 방지               │
│   → STM 컨텍스트 포함해 NanoClaw에 delegate          │
└────────────────────┬────────────────────────────────┘
                     │ HTTP (internal key)
┌────────────────────▼────────────────────────────────┐
│ NanoClaw MCP Server                                  │
│  - upsert_note(title, content, tags)                 │
│  - search_knowledge(query, tags?)                    │
└────────────────────┬────────────────────────────────┘
                     │ MCP tools
┌────────────────────▼────────────────────────────────┐
│ Container Agent                                      │
│  - knowledge_base :ro mount (native Read/Glob/Grep)  │
│  - 쓰기: mcp__knowledge__upsert_note 만              │
│  - 422 수신 시: 새 파일 생성 + [[기존파일]] 링크     │
└─────────────────────────────────────────────────────┘

Storage: knowledge_base/ (GDrive mount, .gitignore)
  INDEX.md            연도별 링크 + 주제 MOC
  YYYY-MM/INDEX.md    월별 파일 목록
  YYYY-MM/{date}-{slug}.md
  moc/{tag}-MOC.md
```
