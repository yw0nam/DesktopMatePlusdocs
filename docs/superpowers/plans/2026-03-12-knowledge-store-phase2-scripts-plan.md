# Knowledge Store Phase 2: 코어 스크립트 구현 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 컨테이너 에이전트가 노트를 저장한 뒤 호출하는 두 스크립트(`generate_indexes.ts`, `sync_knowledge.sh`)를 작성하고, NanoClaw skill 브랜치에 포함될 수 있도록 준비한다.

**Architecture:** 스크립트는 `nanoclaw/container/scripts/`에 위치한다. Phase 3에서 skill 브랜치에 포함되어 컨테이너 내부 `/scripts/`로 마운트된다. knowledge_base GDrive repo에는 스크립트를 넣지 않는다 (rclone symlink 제약).

**Tech Stack:** Node.js 22, TypeScript, `js-yaml`, bash

---

## Chunk 1: `generate_indexes.ts` 구현

**Files:**

- Create: `nanoclaw/container/scripts/generate_indexes.ts`

> **선행 조건**: Phase 1 완료. NanoClaw 레포(`nanoclaw/`)에서 작업.

### Task 1: 스캔 + frontmatter 파싱

- [ ] `nanoclaw/container/scripts/` 디렉터리 생성

  ```bash
  mkdir -p nanoclaw/container/scripts
  ```

- [ ] 로컬 테스트용 패키지 세팅

  ```bash
  cd nanoclaw/container/scripts
  npm init -y
  npm install typescript ts-node js-yaml @types/js-yaml @types/node
  ```

- [ ] `generate_indexes.ts` 파일 작성. 스캔 함수 구현:

  ```typescript
  const EXCLUDE_DIRS = ['scripts', 'moc', '.git'];
  const EXCLUDE_FILES = ['INDEX.md'];

  async function getFiles(dir: string): Promise<string[]>
  ```

- [ ] frontmatter 파싱 함수 구현. 다음 규칙 적용:
  - frontmatter 없음 또는 YAML 에러 → skip, `WARN: skipping {file}: {reason}` → stderr, `process.exitCode = 1`
  - `title` 없음 → filename stem
  - `tags` scalar string → 배열로 normalize (e.g. `tags: nanoclaw` → `['nanoclaw']`)
  - `created_at` 없음 → file mtime fallback, `WARN` → stderr
  - tags 없음/빈 배열 → untagged (INDEX 포함, moc 제외)

  ```typescript
  async function parseNote(filePath: string): Promise<NoteEntry | null>
  ```

- [ ] 로컬 테스트용 샘플 md 생성 및 실행 확인

  ```bash
  mkdir -p /tmp/kb-test/2026-03
  cat > /tmp/kb-test/2026-03/20260312-test-note.md << 'EOF'
  ---
  title: 테스트 노트
  created_at: 2026-03-12T10:00:00Z
  tags: [test, nanoclaw]
  ---
  첫 번째 요약 라인입니다.
  EOF

  KNOWLEDGE_BASE_PATH=/tmp/kb-test npx ts-node generate_indexes.ts
  ```

  Expected: 에러 없이 종료 (exit code 0)

### Task 2: INDEX / MOC 생성

- [ ] 월별 INDEX 생성 로직 구현

  링크 경로는 반드시 **`{YYYY-MM}/INDEX.md` 기준 상대경로** 사용:

  ```typescript
  const monthDir = path.join(KB_PATH, month);
  const relPath = path.relative(monthDir, note.path);
  // → "./20260312-test-note.md"
  ```

  `tagsStr` = `note.tags.length ? ' #' + note.tags.join(' #') : ''`

- [ ] 최상위 INDEX.md 생성 로직 구현 (월별 디렉터리 링크, 내림차순)

- [ ] MOC 생성 로직 구현

  링크 경로: `path.relative(path.join(KB_PATH, 'moc'), note.path)` → `../2026-03/20260312-test-note.md`

- [ ] 출력 내용 확인

  ```bash
  KNOWLEDGE_BASE_PATH=/tmp/kb-test npx ts-node generate_indexes.ts
  cat /tmp/kb-test/INDEX.md
  cat /tmp/kb-test/2026-03/INDEX.md
  cat /tmp/kb-test/moc/test-MOC.md
  ```

  Expected:
  - `INDEX.md`: `- [2026-03](./2026-03/INDEX.md)` 항목
  - `2026-03/INDEX.md`: `- [테스트 노트](./20260312-test-note.md) — 첫 번째 요약 라인입니다. #test #nanoclaw`
  - `moc/test-MOC.md`: 링크 `../2026-03/20260312-test-note.md`

### Task 3: 에러 핸들링 + idempotency 검증

- [ ] malformed frontmatter → non-zero exit 확인

  ```bash
  echo "no frontmatter" > /tmp/kb-test/2026-03/20260312-bad.md
  KNOWLEDGE_BASE_PATH=/tmp/kb-test npx ts-node generate_indexes.ts
  echo "exit: $?"
  ```

  Expected: `WARN: skipping ...` stderr, exit code 1

- [ ] 멱등성 확인 (2회 실행 후 diff 없음)

  ```bash
  KNOWLEDGE_BASE_PATH=/tmp/kb-test npx ts-node generate_indexes.ts
  KNOWLEDGE_BASE_PATH=/tmp/kb-test npx ts-node generate_indexes.ts
  # no diff
  ```

- [ ] 테스트용 파일 정리

  ```bash
  rm /tmp/kb-test/2026-03/20260312-bad.md
  ```

- [ ] `scripts/` 자체가 INDEX에 포함되지 않음 확인

---

## Chunk 2: `sync_knowledge.sh` 구현

**Files:**

- Create: `nanoclaw/container/scripts/sync_knowledge.sh`

### Task 4: 스크립트 작성 및 기본 동작 확인

- [ ] `sync_knowledge.sh` 작성 후 `chmod +x`

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  COMMIT_MSG="${1:-knowledge: auto-sync}"
  cd "$KNOWLEDGE_BASE_PATH"

  git add .
  git commit -m "$COMMIT_MSG" || { echo "nothing to commit"; exit 0; }

  if ! git pull --rebase origin main; then
    git rebase --abort
    git reset --soft HEAD~1
    echo "SYNC_CONFLICT: rebase failed — manual resolution required" >&2
    exit 1
  fi

  git push origin main
  ```

- [ ] 정상 흐름 테스트

  ```bash
  export KNOWLEDGE_BASE_PATH=/home/spow12/data/knowledge_base
  bash nanoclaw/container/scripts/sync_knowledge.sh "test: sync script"
  ```

  Expected: `git push` 성공, exit 0

- [ ] 커밋할 내용 없을 때 테스트 (재실행)

  Expected: `nothing to commit`, exit 0

### Task 5: 충돌 복구 시나리오 테스트

- [ ] 충돌 시뮬레이션

  ```bash
  # 원격에 직접 커밋 (다른 머신 시뮬레이션)
  git clone git@github.com:yw0nam/knowledge_base.git /tmp/kb-clone
  mkdir -p /tmp/kb-clone/2026-03
  echo "remote change" >> /tmp/kb-clone/2026-03/20260312-test-note.md
  cd /tmp/kb-clone && git add . && git commit -m "remote: conflict" && git push

  # 로컬에도 같은 파일 변경
  echo "local change" >> $KNOWLEDGE_BASE_PATH/2026-03/20260312-test-note.md
  bash nanoclaw/container/scripts/sync_knowledge.sh "local: conflict test"
  ```

  Expected: `SYNC_CONFLICT: rebase failed...` → stderr, exit 1, 변경사항 staged 유지

---

## 완료 체크리스트

- [ ] `nanoclaw/container/scripts/generate_indexes.ts` 작성 완료
  - [ ] tags scalar normalize 확인
  - [ ] 월별 INDEX 링크 `path.relative(monthDir, notePath)` 기준 확인
  - [ ] tags 빈 배열 시 `#` 단독 출력 없음 확인
  - [ ] non-fatal 파싱 에러 `process.exitCode = 1` + 계속 실행 확인
  - [ ] 멱등성 확인
- [ ] `nanoclaw/container/scripts/sync_knowledge.sh` 작성 완료
  - [ ] `chmod +x` 확인
  - [ ] 정상 push 확인
  - [ ] 충돌 복구 확인
- [ ] `nanoclaw/container/scripts/node_modules/` → nanoclaw `.gitignore`에 추가
- [ ] git commit은 Phase 3 skill 브랜치에서 진행 — 여기서는 파일만 준비
