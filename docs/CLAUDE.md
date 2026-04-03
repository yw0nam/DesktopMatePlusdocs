# docs/ — Workspace Documentation Index

이 디렉토리는 DesktopMatePlus 워크스페이스 전체의 설계 문서를 보관한다.
코드는 없으며, 읽기·참조 전용.

## Directory Map

| 경로 | 목적 |
|------|------|
| `data_flow/` | 주요 흐름의 Mermaid 시퀀스 다이어그램. `chat/`, `channel/`, `desktopmate-bridge/` 별 분류 |
| `faq/` | 반복 혼동 설계 결정 Q&A. 새 FAQ는 여기에 추가 후 루트 `CLAUDE.md` FAQ 섹션에 링크 |
| `feedback/` | Gemini 등 외부 AI 검토 피드백 원본. 읽기 전용 참고자료 |
| `guidelines/DOCUMENT_GUIDE.md` | 모든 문서의 작성 규칙 (200줄 한도, 표준 구조, Appendix 전략) |
| `TODO.md` | **활성 스펙 목록** — PM agent가 office-hours 후 작성. Lead가 Plans.md로 태스크화 |
| `superpowers/INDEX.md` | ~~PRD 진행 현황~~ (legacy — 신규 스펙은 TODO.md 사용) |
| `superpowers/specs/` | (legacy) 구 설계 스펙 문서 아카이브 |
| `superpowers/plans/` | (legacy) 구 구현 계획서 아카이브 |
| `superpowers/completed/` | (legacy) 완료 문서 아카이브 |
| `UI/UILayout.md` | desktopmate-bridge UI 레이아웃 참고 문서 |

## 문서 작성 규칙

→ **반드시 먼저 읽을 것:** [`guidelines/DOCUMENT_GUIDE.md`](./guidelines/DOCUMENT_GUIDE.md)

핵심 요약:
- 본문 200줄 한도
- 구조: Synopsis → Core Logic → Usage → Appendix
- 문서 수정 시 Appendix에 PatchNote(날짜 + 변경 내용) 추가 (backend docs만 적용)
- 파일명: `kebab-case` 또는 `UPPER_SNAKE_CASE`

## 아카이브 관리

- **활성 스펙**: `docs/TODO.md` — PM agent가 작성, Lead가 Plans.md로 태스크화
- **superpowers/**: legacy 아카이브. 신규 스펙 추가 금지.
- **GP-11 검증**: `scripts/garden.sh --gp GP-11` — cc:DONE 태스크의 spec-ref가 활성 디렉토리에 남아있으면 WARN.

## 자주 참조하는 문서

- [Feature TODO](./TODO.md) — 활성 스펙 및 우선순위 목록
- [NanoClaw Task Dispatch FAQ](./faq/nanoclaw-task-dispatch.md) — IPC vs HTTP Channel 혼동 시
- [Desktop Homunculus MOD 시스템 FAQ](./faq/desktop-homunculus-mod-system.md) — MOD 개발 시
- [desktopmate-bridge Config Flow](./data_flow/desktopmate-bridge/CONFIG_FLOW.md) — dm-config 신호 흐름