# Knowledge Store — Phase 3: NanoClaw 컨테이너 에이전트 업데이트

**Date**: 2026-03-12
**Status**: Draft
**Part of**: Knowledge Store Design v3 (4-phase split)
**Scope**: `container-runner.ts` 수정, `SKILL.md` 프로토콜 업데이트

---

## Context

NanoClaw 컨테이너 에이전트가 knowledge base를 직접 읽고 쓸 수 있도록 볼륨 마운트와 환경 변수를 추가한다. 에이전트 행동 프로토콜(Write Flow, Search Flow)은 SKILL.md에 명세한다.

> **CLAUDE.md 정책**: NanoClaw 소스를 직접 수정하지 않는다. `container-runner.ts` 변경은 skill 브랜치로 작성 후 merge. SKILL.md 업데이트는 `container/skills/{name}/SKILL.md`에 직접 편집.

---

## 작업 목록

### 1. `container-runner.ts` 수정

> **선행 조건**: Phase 1 완료 (호스트에 SSH 키 및 known_hosts 세팅 완료)

#### Volume 마운트 변경

```text
변경 전: /host/knowledge_base → /workspace/knowledge_base  :ro
변경 후: /host/knowledge_base → /workspace/knowledge_base  :rw

추가:    /host/.ssh                   → /root/.ssh      :ro
추가:    nanoclaw/container/scripts/  → /scripts        :ro
```

> `scripts/` 마운트는 Phase 2에서 작성한 `generate_indexes.ts`, `sync_knowledge.sh`를 컨테이너에 주입한다. knowledge_base repo가 아닌 NanoClaw 소스에서 관리하므로 rclone GDrive symlink 제약을 피한다.

#### 환경 변수 추가

```text
KNOWLEDGE_BASE_PATH=/workspace/knowledge_base
GIT_AUTHOR_NAME=DesktopMate
GIT_AUTHOR_EMAIL=agent@local
GIT_COMMITTER_NAME=DesktopMate
GIT_COMMITTER_EMAIL=agent@local
KNOWLEDGE_BASE_GITHUB_REMOTE_URL=git@github.com:{user}/knowledge-base.git
```

> `GIT_COMMITTER_*`는 env var로 주입한다. `git config committer.*`는 유효하지 않은 키이므로 사용하지 않는다.

#### 컨테이너 시작 시 git config 주입

```bash
# container-runner.ts의 startup snippet에 추가
git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"
# known_hosts는 호스트에서 미리 세팅됨 — 컨테이너 시작 시 ssh-keyscan 실행 금지
```

---

### 2. `SKILL.md` 프로토콜 업데이트

#### `allowed-tools` 변경

```yaml
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
```

MCP 툴 전체 제거. Option B STM fetch는 NanoClaw host가 컨테이너 시작 전에 해결하여 주입한다 (컨테이너는 항상 full context를 받음).

#### Write Flow

에이전트가 노트를 저장할 때 따라야 할 절차:

```text
1. 파일명 생성
   - slug: title을 소문자, 하이픈, ASCII만으로 변환
   - 날짜 prefix: YYYYMMDD (현재 날짜)
   - 충돌 처리: {YYYYMMDD}-{slug}.md 경로를 정확히 확인 후,
     존재하면 {YYYYMMDD}-{slug}-2.md, -3.md, ... 순서로 시도
     (glob '*' 사용 금지 — {slug}-analysis.md 등과 false-match 가능)

2. 파일 쓰기
   frontmatter:
     - title: (원본 제목)
     - created_at: (현재 ISO timestamp, e.g. 2026-03-12T14:30:00Z)
     - tags: [tag1, tag2]
   본문 + wikilinks ([[slug]] 형식)

3. 인덱스 재생성 (결정론적 스크립트, LLM 직접 편집 금지)
   ts-node /scripts/generate_indexes.ts
   → non-zero exit 시: stderr 내용을 FastAPI callback으로 보고, sync 중단

4. Git sync (세션 종료 시)
   bash /scripts/sync_knowledge.sh "knowledge: {title} [{tags}]"
   → exit 0: 완료
   → exit 1 (SYNC_CONFLICT): "SYNC_CONFLICT" 를 FastAPI callback으로 보고, 재시도 없음
   → 기타 실패: stderr 내용 보고, 재시도 없음
```

> Grace period 없음. git이 전체 히스토리를 보존하므로 이전 버전은 언제든 `git log`로 복구 가능.

#### Search Flow

```bash
# 텍스트 검색만
rg --json -C 2 "{query}" $KNOWLEDGE_BASE_PATH

# 태그 검색만 (inline YAML 및 block-sequence 모두 대응)
rg -l "tags:.*\b{tag}\b|^\s*-\s+{tag}\b" $KNOWLEDGE_BASE_PATH

# 텍스트 + 태그 조합
rg -l "tags:.*\b{tag}\b|^\s*-\s+{tag}\b" $KNOWLEDGE_BASE_PATH | xargs rg --json -C 2 "{query}"
```

> Known limitation: block-sequence 패턴이 본문의 일반 목록 항목과 false-match할 수 있음. MVP 수준에서 허용.

#### Wikilink 해석

`ReadNoteTool`에서 `[[slug]]` 형식의 wikilink를 해석할 때:

```bash
glob("**/{slug}.md")
```

로 경로를 resolve한다. 에이전트가 wikilink를 작성할 때는 파일명에서 확장자를 뺀 stem을 사용.

---

## 완료 체크리스트

- [ ] `container-runner.ts` 수정 (skill 브랜치로 작성 후 merge)
  - [ ] `/workspace/knowledge_base` `:rw` 마운트 확인
  - [ ] `/root/.ssh` `:ro` 마운트 추가 확인
  - [ ] 환경 변수 5종 추가 확인
  - [ ] startup git config snippet 추가 확인
- [ ] `SKILL.md` 업데이트
  - [ ] `allowed-tools` MCP 제거, Bash/Read/Write/Edit/Glob/Grep 으로 변경
  - [ ] Write Flow 4단계 절차 명세
  - [ ] Search Flow rg 명령 명세
- [ ] `npm run build && npm test` 통과 확인
