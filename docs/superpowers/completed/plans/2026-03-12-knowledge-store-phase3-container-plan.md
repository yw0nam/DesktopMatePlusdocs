# Knowledge Store Phase 3: NanoClaw 컨테이너 에이전트 업데이트 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** NanoClaw 컨테이너가 knowledge base를 `:rw`로 마운트하고 SSH push할 수 있도록 `container-runner.ts`를 수정하고, 에이전트의 Write/Search 행동 프로토콜을 `SKILL.md`에 업데이트한다.

**Architecture:** `container-runner.ts`는 skill 브랜치로 작성 후 merge(직접 수정 금지). `SKILL.md`는 `nanoclaw/container/skills/{name}/SKILL.md`에 직접 편집.

**Tech Stack:** Node.js/TypeScript (NanoClaw), Docker volume mounts, git skill-branch workflow

---

## Chunk 1: `container-runner.ts` — skill 브랜치 작성

> **CRITICAL**: NanoClaw 소스를 직접 수정하지 않는다. skill 브랜치 워크플로우를 따른다.

**Files (nanoclaw repo):**
- Modify via skill branch: `nanoclaw/src/container-runner.ts` (또는 실제 경로 확인 필요)

### Task 1: 현재 container-runner.ts 위치 및 volume mount 코드 확인

- [ ] container-runner.ts 위치 확인

  ```bash
  find nanoclaw/src -name "*.ts" | grep -i container
  ```

- [ ] 현재 volume mount 및 env var 설정 코드 확인

  ```bash
  grep -n "knowledge_base\|rw\|ro\|volume\|mount" nanoclaw/src/container-runner.ts
  ```

### Task 2: skill 브랜치 생성 및 변경 적용

- [ ] skill 브랜치 생성 (nanoclaw repo 기준 main에서)

  ```bash
  cd nanoclaw
  git checkout -b skill/knowledge-base-volume main
  ```

- [ ] `container-runner.ts` 수정:
  - `/workspace/knowledge_base` 마운트를 `:ro` → `:rw` 변경
  - `/root/.ssh` `:ro` 마운트 추가
  - `nanoclaw/container/scripts/` → `/scripts` `:ro` 마운트 추가 (Phase 2 스크립트 주입)
  - 환경 변수 5종 추가:
    ```text
    KNOWLEDGE_BASE_PATH=/workspace/knowledge_base
    GIT_AUTHOR_NAME=DesktopMate
    GIT_AUTHOR_EMAIL=agent@local
    GIT_COMMITTER_NAME=DesktopMate
    GIT_COMMITTER_EMAIL=agent@local
    ```
  - startup snippet 추가 (`git config --global user.name/email` 주입)

  > `GIT_COMMITTER_*`는 env var로만 처리. `git config committer.*`는 유효하지 않은 git 키임.

- [ ] 빌드 통과 확인

  ```bash
  npm run build
  ```

  Expected: 에러 없음

- [ ] 테스트 통과 확인

  ```bash
  npm test
  ```

  Expected: 전체 PASS

- [ ] skill 브랜치 커밋 및 push

  ```bash
  git add src/container-runner.ts
  git commit -m "feat: add knowledge base rw mount and ssh injection"
  git push origin skill/knowledge-base-volume
  ```

### Task 3: skill 브랜치 적용 (develop/main에 merge)

- [ ] 작업 브랜치로 복귀

  ```bash
  git checkout develop   # 또는 현재 작업 브랜치
  ```

- [ ] skill 브랜치 fetch + merge

  ```bash
  git fetch origin skill/knowledge-base-volume
  git merge origin/skill/knowledge-base-volume
  ```

- [ ] merge 후 빌드 + 테스트 재확인

  ```bash
  npm run build && npm test
  ```

---

## Chunk 2: `SKILL.md` 프로토콜 업데이트

**Files (nanoclaw repo):**
- Modify: `nanoclaw/container/skills/{name}/SKILL.md`

> SKILL.md는 skill 브랜치가 아닌 직접 편집 가능 (코드가 아닌 프로토콜 문서)

### Task 4: allowed-tools 변경

- [ ] 현재 SKILL.md의 `allowed-tools` 확인

  ```bash
  grep -n "allowed-tools\|mcp" nanoclaw/container/skills/*/SKILL.md
  ```

- [ ] `allowed-tools`를 아래로 변경:

  ```yaml
  allowed-tools: Bash, Read, Write, Edit, Glob, Grep
  ```

  MCP 툴 전체 제거. Option B STM fetch는 NanoClaw host가 컨테이너 시작 전 해결하여 주입.

### Task 5: Write Flow 절차 추가

- [ ] SKILL.md에 Write Flow 섹션 추가:

  ```text
  ## Write Flow

  노트 저장 시 아래 절차를 따른다:

  1. 파일명 생성
     - slug: title → lowercase, hyphens, ASCII only
     - 날짜 prefix: YYYYMMDD
     - 충돌 처리: {YYYYMMDD}-{slug}.md 정확히 확인 후 존재하면 -2.md, -3.md 순서
       (glob '*' 사용 금지 — false-match 위험)

  2. 파일 쓰기
     frontmatter: title, created_at (ISO timestamp), tags: [...]
     본문 + wikilinks ([[slug]] 형식)

  3. 인덱스 재생성
     ts-node /scripts/generate_indexes.ts
     → non-zero exit: stderr 내용 FastAPI callback 보고 후 sync 중단

  4. Git sync (세션 종료 시)
     bash /scripts/sync_knowledge.sh "knowledge: {title} [{tags}]"
     → exit 1 (SYNC_CONFLICT): FastAPI callback에 "SYNC_CONFLICT" 보고, 재시도 없음
     → 기타 실패: stderr 내용 보고, 재시도 없음
  ```

### Task 6: Search Flow 절차 추가

- [ ] SKILL.md에 Search Flow 섹션 추가:

  ```text
  ## Search Flow

  # 텍스트 검색
  rg --json -C 2 "{query}" $KNOWLEDGE_BASE_PATH

  # 태그 검색 (inline YAML + block-sequence 대응)
  rg -l "tags:.*\b{tag}\b|^\s*-\s+{tag}\b" $KNOWLEDGE_BASE_PATH

  # 텍스트 + 태그 조합
  rg -l "tags:.*\b{tag}\b|^\s*-\s+{tag}\b" $KNOWLEDGE_BASE_PATH | xargs rg --json -C 2 "{query}"

  # wikilink 해석
  glob("**/{slug}.md")
  ```

- [ ] SKILL.md 변경 커밋

  ```bash
  cd nanoclaw
  git add container/skills/
  git commit -m "feat: update SKILL.md with knowledge base write/search flow"
  ```

---

## 완료 검증

- [ ] `npm run build && npm test` 통과
- [ ] container-runner.ts에 `:rw`, `/root/.ssh :ro`, `/scripts :ro`, env 5종, git config snippet 포함 확인
- [ ] SKILL.md에 `allowed-tools: Bash, Read, Write, Edit, Glob, Grep` 확인
- [ ] SKILL.md에 Write Flow 4단계, Search Flow rg 명령 확인
