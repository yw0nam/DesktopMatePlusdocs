# Upstream Fork에서 학습을 어디에 기록하는가

## 문제

`nanoclaw/`와 `desktop-homunculus/`는 upstream fork 레포지토리다. Subagent가 작업 중 발견한 패턴이나 설계 결정을 `CLAUDE.md`에 기록하면, 다음 번 `git merge upstream/main` 시 충돌이 발생한다.

## 잘못된 접근

```
# ❌ upstream이 소유한 파일 수정
nanoclaw/CLAUDE.md  →  upstream sync 시 충돌
desktop-homunculus/CLAUDE.md  →  upstream sync 시 충돌
```

## 올바른 접근

`.claude/rules/team-local.md`를 사용한다.

```
# ✅ gitignore된 로컬 전용 파일
nanoclaw/.claude/rules/team-local.md
desktop-homunculus/.claude/rules/team-local.md
```

- `.git/info/exclude`에 등록되어 있어 upstream에 push되지 않음
- Claude Code는 `.claude/rules/` 하위 파일을 자동으로 로드함 — 별도 import 불필요
- 크로스레포 설계 결정(왜 X 대신 Y)은 루트 `docs/faq/`에 기록

## 판단 기준

| 기록 내용 | 기록 위치 |
|---------|---------|
| 이 레포 고유 패턴/gotcha | `.claude/rules/team-local.md` |
| "왜 X 대신 Y인가" 아키텍처 결정 | `docs/faq/` (DesktopMatePlus 루트) |
| upstream과 공유할 기여 | upstream PR (CLAUDE.md 직접 수정은 여전히 금지) |

## backend는 예외

`backend/`는 fork가 아닌 완전히 소유한 레포이므로 `backend/CLAUDE.md`를 직접 수정해도 된다.
