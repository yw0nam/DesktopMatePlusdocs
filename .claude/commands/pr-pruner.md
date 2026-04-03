# /pr-pruner — Stale PR Pruner

14일 이상 활동이 없는 오래된 PR을 탐색하고 정리한다.

## 대상 레포

- yw0nam/DesktopMatePlusdocs
- yw0nam/DesktopMatePlus
- yw0nam/desktop-homunculus

## 실행 순서

### 1. 오픈 PR 수집 및 staleness 판단

```bash
gh pr list --repo <repo> --state open --json number,title,createdAt,updatedAt,author,reviewDecision --limit 50
```

기준:
- `updatedAt` 기준 14일 이상 경과: **stale**
- `updatedAt` 기준 7~13일 경과: **warning** (코멘트만)
- 14일 미만: 스킵

### 2. Warning PR — 코멘트 남기기

```bash
gh pr comment <number> --repo <repo> --body "⚠️ This PR has had no activity for 7+ days. It will be closed automatically if no action is taken within 7 more days."
```

### 3. Stale PR — 닫기

먼저 확인 코멘트를 남기고 close:
```bash
gh pr comment <number> --repo <repo> --body "Closing this PR due to 14+ days of inactivity. Feel free to reopen if still relevant."
gh pr close <number> --repo <repo>
```

예외:
- Draft PR: 스킵 (개발 중으로 간주)
- `keep-open` 라벨이 있는 PR: 스킵

### 4. 결과 요약

경고 코멘트 남긴 PR, 닫은 PR, 스킵한 PR 목록을 출력.
