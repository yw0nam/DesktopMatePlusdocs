# /post-merge-sweeper — Post-Merge Comment Sweeper

최근 머지된 PR에서 미처리 리뷰 코멘트를 탐색하고, 필요하면 후속 fix PR을 생성한다.

## 대상 레포

- yw0nam/DesktopMatePlusdocs
- yw0nam/DesktopMatePlus
- yw0nam/desktop-homunculus

## 실행 순서

### 1. 최근 24시간 내 머지된 PR 수집

```bash
gh pr list --repo yw0nam/DesktopMatePlusdocs --state merged --json number,title,mergedAt,reviews,comments --limit 20
gh pr list --repo yw0nam/DesktopMatePlus --state merged --json number,title,mergedAt,reviews,comments --limit 20
gh pr list --repo yw0nam/desktop-homunculus --state merged --json number,title,mergedAt,reviews,comments --limit 20
```

mergedAt이 현재 시각 기준 24시간 이내인 PR만 처리.

### 2. 미처리 리뷰 코멘트 탐색

각 PR의 리뷰 코멘트 중:
- resolved되지 않은 코멘트
- 답변이 없는 코멘트

를 탐색. 파일/라인 위치 포함 수집.

### 3. 유효한 이슈 분류

- **false positive**: 해당 PR 코멘트에 "Addressed: false positive — [이유]" 답변 후 종료.
- **valid fix**: 코드 수정 필요. 수정 후 새 브랜치(`fix/sweep-{date}`)에서 PR 생성.

### 4. 결과 요약

처리한 PR 수, 발견된 미처리 코멘트 수, 생성된 fix PR 수를 출력.
