# Phase Cleanup

Phase 완료 후 팀 종료 및 워크트리 정리 체크리스트.

## 1. Worker Lead Shutdown

Worker Lead에게 shutdown_request 전송.
Worker Lead는 내부에서 Coder + Reviewer를 먼저 shutdown한 뒤 자신도 종료.

> Worker Lead가 이미 내부 정리를 완료한 경우 (최종 보고 시 "shutdown 준비 완료" 포함),
> Main Lead는 Worker Lead에게만 shutdown_request를 보내면 됨.

## 2. 기타 Teammate 종료

pm-agent, reviewer (spec review) 등 남은 teammate에게 shutdown_request 전송 후 terminated 확인.

## 3. TeamDelete

팀 삭제:
```
TeamDelete()
```

## 4. 워크트리 정리

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

## 5. Plans.md 확인

해당 Phase의 모든 태스크가 cc:DONE인지 확인.
