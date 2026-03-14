# Knowledge Store — Phase 1: 인프라 및 Git 환경 설정

**Date**: 2026-03-12
**Status**: Draft
**Part of**: Knowledge Store Design v3 (4-phase split)
**Scope**: GitHub 저장소, SSH 키, Git 초기화, rclone 필터 — 호스트 수준 일회성 작업

---

## Context

Knowledge Store는 컨테이너 에이전트가 GDrive에 마운트된 로컬 경로에 마크다운 파일을 쓰고, git으로 GitHub private 레포에 push하는 구조다. Phase 1은 이 전체 흐름이 동작하기 위한 **선행 인프라 세팅**이다.

```text
/mnt/gdrive/knowledge_base/    ← rclone GDrive mount
  .git/                        ← git repo (NOT synced to GDrive)
  INDEX.md
  2026-03/
  moc/
  scripts/
```

컨테이너는 이 경로를 `:rw`로 마운트한다 (Phase 3에서 설정). SSH 키는 컨테이너에 `:ro`로 주입된다.

---

## 작업 목록

### 1. GitHub 저장소 세팅

- [ ] GitHub에 `knowledge-base` private 저장소 생성
- [ ] SSH Deploy Key 생성 및 등록 (**쓰기 권한 포함**)
  ```bash
  ssh-keygen -t ed25519 -C "agent@local" -f ~/.ssh/id_ed25519_knowledge
  # GitHub → Settings → Deploy keys → Add deploy key → Allow write access
  ```

### 2. Host SSH 설정

- [ ] 호스트 `~/.ssh/`에 키 파일 및 `known_hosts` 세팅
  ```bash
  # known_hosts에 github.com 미리 등록 (컨테이너 시작 시 네트워크 오류 방지)
  ssh-keyscan github.com >> ~/.ssh/known_hosts
  ```
  > **왜 호스트에서?** 컨테이너 시작 시 `ssh-keyscan`을 실행하면 silent network failure 가능성 있음. 호스트에서 미리 등록된 `known_hosts`를 `:ro`로 마운트하는 것이 안전하다.

- [ ] `~/.ssh/config`에 alias 추가 (선택, 키 파일명이 기본값이 아닌 경우)
  ```
  Host github.com
    IdentityFile ~/.ssh/id_ed25519_knowledge
    StrictHostKeyChecking yes
  ```

### 3. Git 초기화

- [ ] GDrive 마운트 경로에서 git repo 초기화 및 초기 구조 생성
  ```bash
  cd /mnt/gdrive/knowledge_base
  git init -b main
  git remote add origin git@github.com:{user}/knowledge-base.git

  # 호스트 git config (컨테이너는 env var로 별도 주입됨)
  git config user.name "DesktopMate"
  git config user.email "agent@local"

  # 초기 디렉터리 구조
  mkdir -p scripts moc
  echo "# Knowledge Base" > INDEX.md

  # scripts/는 Phase 2에서 작성 후 여기에 배치
  chmod +x scripts/sync_knowledge.sh   # Phase 2 완료 후 실행

  git add INDEX.md moc/ scripts/
  git commit -m "init: knowledge base structure"
  git push -u origin main
  ```

### 4. rclone 필터 설정

- [ ] `~/.config/rclone/knowledge_base.filter` 파일 생성
  ```text
  - .git/**
  - scripts/**
  - *~
  - .DS_Store
  + **
  ```
  > `scripts/`는 GDrive에 동기화하지 않는다. 스크립트는 git에만 존재하며, 에이전트는 git clone/pull로 취득한다.

- [ ] rclone mount 명령에 필터 적용 확인
  ```bash
  rclone mount gdrive:knowledge_base /mnt/gdrive/knowledge_base \
    --filter-from ~/.config/rclone/knowledge_base.filter \
    --vfs-cache-mode off \
    --read-only   # FastAPI 마운트는 :ro
  ```

---

## 완료 체크리스트

- [ ] `git remote -v` 로 origin 확인
- [ ] `ssh -T git@github.com` 로 SSH 인증 확인
- [ ] `cat ~/.ssh/known_hosts | grep github` 로 known_hosts 등록 확인
- [ ] rclone filter 적용 상태에서 `rclone ls` 결과에 `.git/` 없는지 확인
- [ ] `git push origin main` 성공 확인

---

## Known Issues

- **rclone/git 동시성**: `git pull --rebase` 중 `.md` 파일이 잠깐 변경됨. rclone이 mid-rebase 상태를 동기화할 경우 0-byte 업로드 또는 lock contention 위험. 발생 시 git 작업 디렉터리를 rclone watch 경로와 분리하는 post-push cron copy 방식으로 대응. → MVP 이후 검토.
