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
| `plans/` | 초기 구현 계획서 (구버전). 신규 계획은 `superpowers/plans/`에 작성 |
| `prds/feature/INDEX.md` | **PRD 진행 현황** — 기능별 P0/P1/P2 우선순위 + TODO/DONE/VERIFY 상태 |
| `superpowers/plans/` | Claude Code 세션용 구현 계획서 (YYYY-MM-DD 접두사) |
| `superpowers/specs/` | 구현 전 설계 스펙 문서 (계획서의 원본 요구사항) |
| `UI/UILayout.md` | desktopmate-bridge UI 레이아웃 참고 문서 |

## 문서 작성 규칙

→ **반드시 먼저 읽을 것:** [`guidelines/DOCUMENT_GUIDE.md`](./guidelines/DOCUMENT_GUIDE.md)

핵심 요약:
- 본문 200줄 한도
- 구조: Synopsis → Core Logic → Usage → Appendix
- 문서 수정 시 Appendix에 PatchNote(날짜 + 변경 내용) 추가 (backend docs만 적용)
- 파일명: `kebab-case` 또는 `UPPER_SNAKE_CASE`

## 자주 참조하는 문서

- [PRD Index](./prds/feature/INDEX.md) — 현재 구현 현황 한눈에
- [NanoClaw Task Dispatch FAQ](./faq/nanoclaw-task-dispatch.md) — IPC vs HTTP Channel 혼동 시
- [Desktop Homunculus MOD 시스템 FAQ](./faq/desktop-homunculus-mod-system.md) — MOD 개발 시
- [desktopmate-bridge Config Flow](./data_flow/desktopmate-bridge/CONFIG_FLOW.md) — dm-config 신호 흐름