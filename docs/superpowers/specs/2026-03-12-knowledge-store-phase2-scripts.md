# Knowledge Store — Phase 2: 코어 스크립트 구현

**Date**: 2026-03-12
**Status**: Draft
**Part of**: Knowledge Store Design v3 (4-phase split)
**Scope**: `scripts/generate_indexes.ts`, `scripts/sync_knowledge.sh` — 에이전트가 직접 호출하는 스크립트

---

## Context

컨테이너 에이전트는 마크다운 파일을 쓴 뒤 두 스크립트를 순서대로 호출한다:

1. `generate_indexes.ts` — INDEX.md, 월별 INDEX.md, MOC 파일 자동 생성
2. `sync_knowledge.sh` — git add/commit/pull rebase/push

두 스크립트는 **NanoClaw skill 브랜치**에 포함되어 컨테이너 내부에 `/scripts/`로 마운트된다 (Phase 3에서 설정). 에이전트는 `Bash` 툴로 직접 실행한다. **LLM이 직접 INDEX를 편집하지 않는다.**

> **왜 knowledge_base repo가 아닌 skill?** rclone GDrive 마운트는 symlink를 지원하지 않아 `npm install`이 불가. NanoClaw 컨테이너에는 ts-node + js-yaml이 이미 있으므로 skill로 관리하는 것이 자연스럽다.

### 파일 구조

```text
nanoclaw/
  container/
    scripts/
      generate_indexes.ts   # ← Phase 2 작성 대상 (skill 브랜치 포함)
      sync_knowledge.sh     # ← Phase 2 작성 대상 (skill 브랜치 포함)

# 컨테이너 내부:
/scripts/generate_indexes.ts   # container-runner.ts가 마운트
/scripts/sync_knowledge.sh
```

knowledge_base repo의 `scripts/` 디렉터리는 Phase 1에서 생성된 `.gitkeep`만 유지하며 실제 스크립트를 포함하지 않는다.

### 파일 포맷 (마크다운 frontmatter)

```yaml
---
title: NanoClaw와 FastAPI 포트 충돌 해결
created_at: 2026-03-12T14:30:00Z
tags: [nanoclaw, fastapi, bugfix]
---
# 요약
...
```

---

## 작업 목록

### 1. `generate_indexes.ts` 작성

#### 입력

`$KNOWLEDGE_BASE_PATH`의 `*.md` 파일 전체를 스캔 (단, 아래 경로는 제외):

- `INDEX.md` (최상위 및 월별)
- `moc/**`
- `scripts/**`

#### YAML frontmatter 파싱 규칙

| 상황 | 처리 |
|---|---|
| frontmatter 없음 또는 YAML 파싱 에러 | 파일 skip, stderr에 `WARN: skipping {file}: {reason}` 출력, **실행 계속** |
| `title` 없음 | 파일명 stem을 title로 사용 |
| `tags` 없음 또는 빈 배열 | untagged 처리 — INDEX에는 포함, `moc/`에는 제외 |
| `created_at` 없음 또는 파싱 불가 | file mtime을 정렬 기준으로 fallback, stderr에 `WARN` 출력 |

> **중요**: 하나 이상의 파일 파싱 실패 시 스크립트는 **non-zero exit code** 를 반환해야 한다. `sync_knowledge.sh` 가 이를 감지하여 에러를 caller에게 전달한다.

#### 출력 (매 실행 시 완전 재생성 — idempotent)

- `{YYYY-MM}/INDEX.md` — 해당 월의 파일 목록, `created_at` 내림차순 정렬
- `INDEX.md` (최상위) — 월별 디렉터리 목록, 내림차순 정렬
- `moc/{tag}-MOC.md` — 해당 태그를 가진 파일 목록, `created_at` 내림차순 정렬

#### 엔트리 포맷 (INDEX/MOC 모두 동일)

```markdown
- [{title}]({relative-path}) — {one-line summary from first non-heading line} #{tags}
```

- 링크 경로는 **출력 파일 위치 기준 상대경로** (`path.relative(outputDir, note.path)`)
- tags가 빈 배열이면 `#{tags}` 부분 생략

#### 구현 시 주의

- **월별 INDEX 링크**: 링크 경로는 `{YYYY-MM}/INDEX.md` 기준 상대경로여야 한다. `createdAt` 기준 그루핑이므로 파일의 물리적 위치와 월이 다를 수 있음.
- **tags 타입 방어**: YAML에 `tags: nanoclaw`처럼 scalar string으로 작성된 경우 배열로 normalize한다.
- **tags 빈 배열**: 엔트리 끝에 `#` 단독 출력이 생기지 않도록 tags가 없으면 해당 부분 생략한다.
- 완전 재생성 방식이므로 삭제된 파일의 stale entry는 자동 제거됨
- 멱등성 보장 필수: 동일 입력에 대해 항상 동일 출력
- `scripts/` 자체 제외 필수 (재귀 포함 방지)

---

### 2. `sync_knowledge.sh` 작성

```bash
#!/usr/bin/env bash
set -euo pipefail
COMMIT_MSG="${1:-knowledge: auto-sync}"
cd "$KNOWLEDGE_BASE_PATH"

git add .
git commit -m "$COMMIT_MSG" || { echo "nothing to commit"; exit 0; }

if ! git pull --rebase origin main; then
  # 충돌 또는 rebase 실패: 워킹 트리 복구
  git rebase --abort
  # 로컬 커밋을 un-commit (staged 상태로 되돌려 다음 세션에 재시도 가능)
  git reset --soft HEAD~1
  echo "SYNC_CONFLICT: rebase failed — manual resolution required" >&2
  exit 1
fi

git push origin main
```

#### 에러 처리 전략

| 상황 | 처리 |
|---|---|
| 커밋할 내용 없음 | `exit 0` (정상 종료) |
| `git pull --rebase` 충돌 | `rebase --abort` + `reset --soft HEAD~1` 로 복구 → `exit 1` |
| 기타 실패 (`push` 실패 등) | `set -e`에 의해 non-zero exit, stderr에 git 오류 메시지 |

> **왜 `reset --soft HEAD~1`?** rebase 실패 후 로컬 커밋이 남아 있으면 다음 실행 시 중복 커밋 위험. soft reset으로 변경사항은 staged 상태로 유지하고 커밋만 취소.
>
> **왜 LLM merge 없음?** NanoClaw는 정상 운영 시 단독 writer이므로 충돌은 사용자가 다른 머신에서 직접 커밋한 경우에만 발생. 이 경우 자동화보다 수동 해결이 정확하다.

---

## 에이전트 호출 순서 (참고 — Phase 3 SKILL.md에서 명세)

```bash
# 1. 파일 쓰기 후 인덱스 재생성
# 스크립트는 /scripts/ 로 마운트됨 (container-runner.ts, Phase 3)
ts-node /scripts/generate_indexes.ts
# non-zero exit 시: stderr 내용을 FastAPI callback으로 보고 후 sync 중단

# 2. 세션 종료 시 git sync
bash /scripts/sync_knowledge.sh "knowledge: {title} [{tags}]"
# exit 1 (SYNC_CONFLICT): "SYNC_CONFLICT" 를 FastAPI callback으로 보고, 재시도 없음
# 기타 실패: stderr 내용 보고, 재시도 없음
```

---

## 완료 체크리스트

- [ ] `generate_indexes.ts` 작성 완료
  - [ ] frontmatter 파싱 (`js-yaml` 기반)
  - [ ] tags scalar → array normalize 처리 확인
  - [ ] 월별 INDEX 링크가 `path.relative(monthDir, e.path)` 기준인지 확인
  - [ ] tags 빈 배열일 때 `#` 단독 출력 없는지 확인
  - [ ] 파싱 실패 skip + warning + non-zero exit 동작 확인
  - [ ] INDEX.md, 월별 INDEX.md, moc/ 모두 생성 확인
  - [ ] 멱등성 확인 (2회 연속 실행 후 diff 없음)
- [ ] `sync_knowledge.sh` 작성 완료
  - [ ] `chmod +x scripts/sync_knowledge.sh`
  - [ ] 정상 push 확인
  - [ ] 충돌 시뮬레이션: `rebase --abort` + `reset --soft` 동작 확인
- [ ] 두 스크립트 모두 git commit 및 push 완료
