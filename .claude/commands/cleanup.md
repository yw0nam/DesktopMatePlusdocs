# Phase Cleanup

Phase 완료 후 팀 종료 및 워크트리 정리 체크리스트.

## 1. Teammate 종료
모든 teammate에게 shutdown_request 전송 후 terminated 확인.

## 2. TeamDelete
팀 삭제:
```
TeamDelete()
```

## 3. 워크트리 정리
```bash
git worktree list
# 각 repo 확인:
git -C backend worktree list
git -C nanoclaw worktree list
git -C desktop-homunculus worktree list
```
머지 완료된 브랜치의 워크트리는 `--force` 제거:
```bash
git worktree remove --force <path>
```

## 4. Plans.md 확인
해당 Phase의 모든 태스크가 cc:DONE인지 확인.
