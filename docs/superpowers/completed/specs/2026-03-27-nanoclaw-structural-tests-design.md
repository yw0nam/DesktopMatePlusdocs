# NanoClaw Structural Tests — Design Spec

**Date**: 2026-03-27
**Status**: Approved
**Target repo**: `nanoclaw/`

## Overview

NanoClaw 아키텍처 불변성을 자동으로 검증하는 구조적 테스트 스위트.
Backend의 `tests/structural/test_architecture.py` (9개 테스트)와 대칭을 이루며, NanoClaw 고유 패턴(Channel self-registration, skill-as-branch)을 감지한다.

## 파일 위치

```
nanoclaw/src/structural/architecture.test.ts  (신규)
```

vitest 기존 설정(`src/**/*.test.ts`)에 자동 포함. 설정 변경 불필요.

## 테스트 그룹

### 1. TestChannelSelfRegistration

Channel self-registration 패턴 위반 감지.

**T1-1**: `src/channels/` 내 모든 `.ts` 파일(`registry.ts`, `index.ts` 제외)이 `registerChannel(` 호출을 포함해야 한다.

```typescript
const files = readdirSync(CHANNELS_DIR)
  .filter(f => f.endsWith('.ts') && !['registry.ts', 'index.ts'].includes(f));
const violators = files.filter(f => !readFileSync(join(CHANNELS_DIR, f), 'utf8').includes('registerChannel('));
expect(violators).toEqual([]);
```

**T1-2**: `channels/index.ts`가 채널 파일 전부를 import해야 한다.

```typescript
const indexSrc = readFileSync(join(CHANNELS_DIR, 'index.ts'), 'utf8');
const missing = channelFiles.filter(f => {
  const stem = f.replace('.ts', '');
  return !indexSrc.includes(`'./${stem}.js'`) && !indexSrc.includes(`'./${stem}'`);
});
expect(missing).toEqual([]);
```

**초기 상태**: `http.ts` 1개 → 양쪽 그린. 새 채널 추가 시 T1-2가 누락을 즉시 감지.

---

### 2. TestSkillAsBranchEnforcement

`src/` 에 미승인 파일 추가(skill 코드 직접 커밋) 감지.

**T2**: `KNOWN_SRC_FILES` 화이트리스트에 없는 파일이 `src/` 에 존재하면 실패.

```typescript
const KNOWN_SRC_FILES = new Set([
  // channels/
  'channels/http.ts',
  'channels/http.test.ts',
  'channels/index.ts',
  'channels/registry.ts',
  'channels/registry.test.ts',
  // root src/
  'claw-skill.test.ts',
  'config.ts',
  'container-runner.ts',
  'container-runner.test.ts',
  'container-runtime.ts',
  'container-runtime.test.ts',
  'db.ts',
  'db.test.ts',
  'db-migration.test.ts',
  'env.ts',
  'formatting.test.ts',
  'group-folder.ts',
  'group-folder.test.ts',
  'group-queue.ts',
  'group-queue.test.ts',
  'index.ts',
  'ipc.ts',
  'ipc-auth.test.ts',
  'logger.ts',
  'mount-security.ts',
  'remote-control.ts',
  'remote-control.test.ts',
  'router.ts',
  'routing.test.ts',
  'sender-allowlist.ts',
  'sender-allowlist.test.ts',
  'task-scheduler.ts',
  'task-scheduler.test.ts',
  // structural (this file)
  'structural/architecture.test.ts',
]);
```

**위반 시나리오**: skill 코드를 `src/`에 직접 커밋 → 새 파일이 whitelist 없음 → 실패.
**정당한 파일 추가**: PR에서 `KNOWN_SRC_FILES`에 명시적으로 등록 필요 → 리뷰어 확인 강제.

---

### 3. TestFileSizeLimits

파일 비대화 방지.

**T3**: `src/**/*.ts` 파일이 LOC 상한 이내여야 한다. (`.test.ts` 제외)

```typescript
const FILE_SIZE_LIMITS: Record<string, number> = {
  'index.ts': 800,   // 오케스트레이터 (현재 720줄)
};
const DEFAULT_LOC_LIMIT = 400;

// 기존 debt 등록 (초기엔 비어있음)
const KNOWN_LARGE_FILES = new Set<string>([]);
```

오케스트레이터(`index.ts`)만 800줄 특례, 나머지 400줄 상한.

---

### 4. TestCodeConventions

`console.log` 직접 사용 금지 — Pino logger 강제.

**T4**: `src/**/*.ts` (`*.test.ts`, `*.d.ts` 제외)에 `console.(log|warn|error|debug|info)` 미존재.

```typescript
const CONSOLE_PATTERN = /^\s*console\.(log|warn|error|debug|info)\s*\(/m;

// 기존 debt (초기 실행 후 확인하여 등록)
const _KNOWN_CONSOLE_FILES = new Set<string>([]);
```

---

## 기술 스택

| 항목 | 선택 | 이유 |
|------|------|------|
| 파일 열거 | `fs.readdirSync` + `tinyglobby` | 이미 의존성 존재 |
| 텍스트 분석 | 문자열 grep (정규표현식) | AST(ts-morph) 불필요 — 충분하고 빠름 |
| `__dirname` 상당 | `import.meta.dirname` | ESM 환경 (vitest) |
| git 연동 | 사용 안 함 | KNOWN_SRC_FILES로 대체 |

## 구현 순서

```
1. T4 (console.log)         — 가장 단순, debt 없음 예상
2. T3 (파일 LOC)            — KNOWN_LARGE_FILES 초기값 확정
3. T1 (self-registration)   — http 채널로 그린 확인
4. T2 (skill-as-branch)     — KNOWN_SRC_FILES 초기값 확정
```

## 완료 기준

- `npm test` 에서 4개 그룹 전체 통과
- `npm run build` 타입 에러 없음
- Backend `tests/structural/`과 대칭 구조 달성
