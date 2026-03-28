# Backend Agent Run Environment — Design Spec

**Date**: 2026-03-28
**Status**: Approved
**Target repo**: `backend/`

## Overview

Developer/Reviewer Agent가 worktree 내에서 Backend 앱을 독립 실행하고, examples 시나리오와 로그로 동작을 검증할 수 있는 환경을 제공한다.

## 파일 구조

```
backend/scripts/
├── run.sh          # worktree-aware 앱 실행기 (신규)
├── verify.sh       # 검증 하네스 — health + examples + 로그 (신규)
├── logs.sh         # 로그 쿼리 thin wrapper (신규)
├── log_query.py    # 구조화 로그 파싱 + 요약 (신규)
└── lint.sh         # 기존 (변경 없음)
```

## 포트 결정 규칙

- main/develop 브랜치 직접 실행: `5500` (기존 유지)
- worktree: `5500 + (cksum(worktree_basename) % 100)` → 5501~5599 범위
- 결정론적 — 같은 worktree 이름은 항상 같은 포트

```bash
# 포트 계산 예시
BASENAME=$(basename "$PWD")
PORT=$(( 5500 + $(echo "$BASENAME" | cksum | cut -d' ' -f1) % 100 ))
```

## `scripts/run.sh` — 실행기

### 인터페이스

```bash
scripts/run.sh              # 포그라운드 실행
scripts/run.sh --bg         # 백그라운드 실행 (PID → .run.pid)
scripts/run.sh --stop       # .run.pid 로 프로세스 종료
scripts/run.sh --port       # 현재 worktree 포트만 출력 (스크립트 간 연동용)
```

### 동작 순서

1. `pwd` 기반 worktree basename 감지 → 포트 계산
2. **외부 서비스 체크** — `yaml_files/` 에서 MongoDB URI, Qdrant URL 읽어 연결 시도
   - 연결 실패 시: 메시지 출력 후 사용자 Enter 대기
   ```
   [run.sh] MongoDB에 연결할 수 없습니다 (mongodb://localhost:27017).
            서비스를 실행한 후 Enter 키를 누르세요...
   ```
3. `LOG_DIR=logs/worktree-{basename}` 설정 → worktree별 로그 격리
4. `.run.logdir` 파일에 LOG_DIR 경로 기록 (logs.sh 자동 감지용)
5. `uv run uvicorn src.main:app --port {PORT} --reload` 실행

### 생성 파일

백엔드 루트(`pyproject.toml` 위치)에 생성됨.

| 파일 | 내용 |
|------|------|
| `.run.pid` | 백그라운드 프로세스 PID |
| `.run.logdir` | 현재 worktree의 LOG_DIR 절대 경로 |

## `scripts/verify.sh` — 검증 하네스

### 인터페이스

```bash
scripts/verify.sh           # 전체 검증 (health + examples + 로그)
scripts/verify.sh --health  # 헬스체크만
scripts/verify.sh --examples # examples만
scripts/verify.sh --logs    # 로그 클린 체크만
```

### 검증 순서

**1. Health check**
- `GET http://localhost:{PORT}/health` → 200 OK
- 실패 시 최대 30초 retry (1초 간격)

**2. Examples 실행**
```bash
uv run python examples/stm_api_demo.py
uv run python examples/realtime_tts_streaming_demo.py
```
- 각각 exit code 0 → PASS

**3. 로그 클린 체크**
- 검증 시작 시각 기준 `ERROR` / `CRITICAL` 0건 → PASS

**4. 결과 요약**
```
✓ health     OK
✓ stm_api    OK
✓ tts_demo   OK
✗ log clean  2 ERRORs found
→ overall: FAILED
```

- 전체 PASS 시 exit 0, 하나라도 실패 시 exit 1

## `scripts/logs.sh` + `scripts/log_query.py` — 로그 쿼리

### 인터페이스

```bash
scripts/logs.sh --level ERROR              # 레벨 필터
scripts/logs.sh --last 50                  # 최근 N줄
scripts/logs.sh --since "10:30:00"         # 특정 시각 이후
scripts/logs.sh --summary                  # 카운트 + 타임라인 요약
scripts/logs.sh --level ERROR --summary    # 옵션 조합 가능
```

### 로그 파일 자동 감지

1. `LOG_DIR` env var 우선
2. 없으면 `.run.logdir` 파일에서 경로 읽기
3. 없으면 `logs/` 디렉토리의 오늘 날짜 파일

에이전트가 경로를 외울 필요 없음.

### 파싱 대상 포맷 (Loguru)

```
10:30:01.234 | ERROR    | src.services.agent:42 | [req-123] - message
```

### `--summary` 출력 예시

```
=== Log Summary (logs/worktree-feat-obs/app_2026-03-28.log) ===
Total lines : 1842
ERROR       : 3
CRITICAL    : 0

Recent errors:
  10:31:02  src.services.agent:42   Connection timeout
  10:31:45  src.services.tts:88     TTS chunk failed
```

## 에이전트 검증 흐름 요약

```bash
# 1. 앱 기동
scripts/run.sh --bg

# 2. 검증 실행
scripts/verify.sh
# → exit 0: 검증 성공
# → exit 1: 실패 내용 확인

# 3. 에러 조회 (실패 시)
scripts/logs.sh --level ERROR --summary

# 4. 앱 종료
scripts/run.sh --stop
```

## 완료 기준 (DoD)

- `scripts/run.sh --bg` 로 앱 기동 → 포트 자동 결정, LOG_DIR 격리
- `scripts/verify.sh` → health + both examples PASS + 로그 클린 → exit 0
- `scripts/logs.sh --summary` → 레벨별 카운트 + 최근 에러 출력
- 외부 서비스 미기동 시 사용자 안내 메시지 + Enter 대기
- 기존 `scripts/lint.sh` 동작 영향 없음
