# /babysit — PR Lifecycle Manager

오픈 PR 전수 점검. 코드 리뷰 대응, 자동 리베이스, 프로덕션 머지까지 관리.

## 대상 레포

- yw0nam/DesktopMatePlusdocs
- yw0nam/DesktopMatePlus
- yw0nam/desktop-homunculus

## 실행 순서

### 1. 오픈 PR 수집

각 레포의 오픈 PR 목록을 가져온다:
```bash
gh pr list --repo yw0nam/DesktopMatePlusdocs --json number,title,reviewDecision,mergeable,baseRefName,headRefName,reviews,comments --state open
gh pr list --repo yw0nam/DesktopMatePlus --json number,title,reviewDecision,mergeable,baseRefName,headRefName,reviews,comments --state open
gh pr list --repo yw0nam/desktop-homunculus --json number,title,reviewDecision,mergeable,baseRefName,headRefName,reviews,comments --state open
```

### 2. REQUEST_CHANGES 또는 미처리 코멘트가 있는 PR

각 PR의 리뷰 코멘트를 읽고:
- **GitHub Bot Reviewer** (Copilot, Gemini 등) 코멘트: false positive 판단 시 답변 처리. valid 이슈면 코드 수정 후 push.
- **GitHub Human Reviewer** 코멘트: 수정하거나, 동의하면 답변 후 처리.
- 모든 코멘트 처리 후 re-request review.

### 3. 리베이스가 필요한 PR (base branch 뒤처짐)

```bash
gh pr view <number> --repo <repo> --json mergeable
```
`mergeable: CONFLICTING` 또는 base branch 뒤처진 PR: 해당 레포 로컬에서 rebase 후 force push.

### 4. APPROVED + CI 통과 PR → 머지

```bash
gh pr merge <number> --repo <repo> --merge --auto
```
`reviewDecision: APPROVED` 이고 CI checks 통과한 PR은 즉시 머지.

### 5. 결과 요약

처리한 PR 목록과 액션(코멘트 응답 / 리베이스 / 머지 / 스킵)을 출력.
