# NanoClaw Changes via Skills Only

**NanoClaw 소스를 직접 수정하지 말 것.** 스킬은 **Git 브랜치 기반**으로 관리된다 — 스킬을 적용한다는 것은 해당 브랜치를 현재 브랜치에 `git merge`하는 것이다. 직접 수정하면 다음 merge 시 충돌 발생.

**새 커스텀 스킬 작성:**

```bash
# 1. skill 브랜치 생성 (main 기반, 스킬 코드만 포함)
git checkout -b skill/{name} main
# 스킬 파일만 추가 후 커밋
git push origin skill/{name}

# 2. SKILL.md 작성: .claude/skills/{name}/SKILL.md
#    Phase 1: pre-flight check
#    Phase 2: git fetch + merge
#    Phase 3: env/setup
#    Phase 4: verify (+ Removal 섹션)

# 3. 적용 (target 브랜치에서)
git fetch origin skill/{name}
git merge origin/skill/{name}

# 4. 검증
npm run build && npm test
```

**스킬 종류별 적용 방법:**

- **업스트림 공식 스킬**: `git remote add {name} https://github.com/qwibitai/nanoclaw-{name}.git` 후 `git fetch {name} main && git merge {name}/main`
- **커스텀 스킬** (이 repo): `git fetch origin skill/{name} && git merge origin/skill/{name}`

**SKILL.md 작성 전 반드시**: 기존 스킬(예: `nanoclaw/.claude/skills/add-slack`)의 SKILL.md를 먼저 읽고 패턴을 파악할 것. NanoClaw는 독특한 개발 패턴을 사용하므로 참고 없이 작성하면 구조가 어긋난다.
