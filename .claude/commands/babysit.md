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

### 4. 미승인 PR → 자동 리뷰 후 승인

`reviewDecision: ""` (미승인) PR에 대해 `reviewer` 에이전트를 스폰하여 `/review` + `/cso`를 실행한다.

- **Pass**: GitHub API로 APPROVE 후 Step 5로 진행
- **Fail**: 이슈 목록 코멘트 남기고 대기 (머지 안 함)

```bash
# reviewer 에이전트가 /review + /cso 실행 후 pass 판정 시:
gh api repos/<repo>/pulls/<number>/reviews \
  -X POST \
  -f body="Automated review passed (/review + /cso). Auto-approving." \
  -f event="APPROVE"
```

### 5. APPROVED + CI 통과 PR → 머지

/document-release를 실행:
- CHANGELOG.md, README, docs/ 관련 파일을 PR diff 기준으로 업데이트
- 변경 사항이 있으면 별도 커밋으로 master에 push
- 변경 사항이 없으면 스킵

머지된 PR이 없으면 이 단계는 생략.
```bash
gh pr merge <number> --repo <repo> --merge --auto
```
`reviewDecision: APPROVED` 이고 CI checks 통과한 PR은 즉시 머지.

### 6. 결과 요약

처리한 PR 목록과 액션(코멘트 응답 / 리베이스 / 자동 리뷰+승인 / 머지 / document-release / 스킵)을 출력.
