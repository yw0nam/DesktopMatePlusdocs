# Knowledge Store Phase 1: 인프라 및 Git 환경 설정 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GitHub private 저장소 + SSH Deploy Key + GDrive 마운트 경로의 git repo + rclone 필터를 세팅하여 컨테이너 에이전트가 GDrive에 마크다운을 쓰고 GitHub에 push할 수 있는 인프라를 준비한다.

**Architecture:** 컨테이너는 `/home/spow12/data/knowledge_base`를 `:rw`로 마운트하고, 호스트의 `~/.ssh/`를 `:ro`로 주입받는다. `.git/`과 `scripts/`는 rclone 필터로 GDrive 동기화 대상에서 제외된다.

**Tech Stack:** git, ssh-keygen, GitHub Deploy Keys, rclone, bash

---

## Chunk 1: GitHub 저장소 + SSH Deploy Key

**Files:**

- Create: `~/.ssh/id_ed25519_knowledge` (SSH private key)
- Create: `~/.ssh/id_ed25519_knowledge.pub` (SSH public key)
- Modify: `~/.ssh/config` (IdentityFile alias 추가)

- [ ] GitHub에서 `knowledge-base` private 저장소 생성 (UI에서 직접)

- [ ] SSH Deploy Key 생성

  ```bash
  ssh-keygen -t ed25519 -C "agent@local" -f ~/.ssh/id_ed25519_knowledge -N ""
  ```

- [ ] 공개키 내용 확인

  ```bash
  cat ~/.ssh/id_ed25519_knowledge.pub
  ```

- [ ] GitHub 저장소 → Settings → Deploy keys → Add deploy key
  - Title: `DesktopMate Agent`
  - Key: 위 공개키 붙여넣기
  - **Allow write access** 체크

- [ ] `~/.ssh/config`에 alias 추가 (기본 키 파일명이 아닌 경우)

  ```text
  Host github.com
    IdentityFile ~/.ssh/id_ed25519_knowledge
    StrictHostKeyChecking yes
  ```

- [ ] SSH 인증 테스트

  ```bash
  ssh -T git@github.com
  ```

  Expected: `Hi {user}/knowledge-base! You've successfully authenticated...`

---

## Chunk 2: Host known_hosts 사전 등록

**Files:**

- Modify: `~/.ssh/known_hosts`

> 컨테이너 시작 시 `ssh-keyscan`을 실행하면 silent network failure 가능성이 있다. 반드시 호스트에서 미리 등록한다.

- [ ] `github.com` fingerprint 등록

  ```bash
  ssh-keyscan github.com >> ~/.ssh/known_hosts
  ```

- [ ] 등록 확인

  ```bash
  grep github ~/.ssh/known_hosts | head -3
  ```

  Expected: `github.com ssh-ed25519 ...` 등 1줄 이상 출력

---

## Chunk 3: GDrive 마운트 경로에 git 초기화

> **선행 조건**: rclone으로 GDrive가 `/home/spow12/data/knowledge_base`에 이미 마운트되어 있어야 한다.

**Files (knowledge_base repo):**

- Create: `knowledge_base/INDEX.md`
- Create: `knowledge_base/moc/.gitkeep`

- [ ] 마운트 경로 진입 및 git 초기화

  ```bash
  cd /home/spow12/data/knowledge_base
  git init -b main
  git remote add origin git@github.com:{user}/knowledge-base.git
  git config user.name "DesktopMate"
  git config user.email "agent@local"
  ```

- [ ] 초기 디렉터리 구조 생성

  ```bash
  mkdir -p scripts moc
  echo "# Knowledge Base" > INDEX.md
  touch moc/.gitkeep scripts/.gitkeep
  ```

- [ ] 초기 커밋 및 push

  ```bash
  git add .
  git commit -m "init: knowledge base structure"
  git push -u origin main
  ```

- [ ] push 성공 확인

  ```bash
  git remote -v
  git log --oneline -3
  ```

  Expected: remote에 `origin` 표시, commit 1개

---

## Chunk 4: rclone 필터 설정

**Files:**

- Create: `~/.config/rclone/knowledge_base.filter`

- [ ] 필터 파일 생성

  ```bash
  mkdir -p ~/.config/rclone
  cat > ~/.config/rclone/knowledge_base.filter << 'EOF'
  - .git/**
  - scripts/**
  - *~
  - .DS_Store
  + **
  EOF
  ```

- [ ] 필터 적용한 rclone ls로 `.git/` 제외 확인

  ```bash
  rclone ls gdrive:LLM/knowledge_base --filter-from ~/.config/rclone/knowledge_base.filter
  ```

  Expected: `.git/` 하위 항목 없음, `INDEX.md`, `moc/` 만 출력

- [ ] rclone mount 명령 참고 (실제 mount는 환경에 따라 다름)

  ```bash
  # FastAPI용 :ro 마운트
  rclone mount gdrive:LLM/knowledge_base /home/spow12/data/knowledge_base \
    --filter-from ~/.config/rclone/knowledge_base.filter \
    --vfs-cache-mode off \
    --read-only
  ```

---

## 완료 검증

- [ ] `ssh -T git@github.com` → 인증 성공
- [ ] `cat ~/.ssh/known_hosts | grep github` → fingerprint 등록 확인
- [ ] `git remote -v` → origin = `git@github.com:{user}/knowledge-base.git`
- [ ] `git push origin main` → 재실행해도 성공 (already up to date)
- [ ] rclone ls에 `.git/` 없음 확인
