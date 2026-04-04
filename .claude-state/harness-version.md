# Harness Version

version: 1.0
updated: 2026-04-05

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2026-04-05 | common-module-writer: Domain 포트/인터페이스 우선 확정 책임 추가. plan-writer: 포트 누락 시 중단 후 common-modules.md 보완 요청 경로 추가 |
| 1.0 | 2026-04-05 | planner: 범주형·파생 필드 AC 명시 규칙 추가 (저장→변환→레이어). reviewer: 1-A 요구사항↔구현 직접 비교 단계 추가 (AC 완결성 검증) |
| 1.0 | 2026-04-04 | smoke에 lint 추가, evaluation-gate에 npm audit(high 이상) 추가, planner smoke 템플릿 업데이트 |
| 1.0 | 2026-04-01 | Playwright MCP 브라우저 검증 통합, session-start.sh \n 정규화 버그 수정, 설계문서 실구현 동기화 완료 |
| 1.0 | 2026-04-01 | profiles/nextjs-supabase 예시 제거 (planner가 sprint마다 생성), collect-metrics.sh BLOCKER_COUNT 버그 수정 |

## 구성 요소

| 파일/폴더 | 역할 |
|-----------|------|
| `CLAUDE.md` | 하네스 운영 규칙 |
| `.ruler/AGENTS.md` | 코딩 원칙 |
| `.claude/agents/` | AI 에이전트 정의 (16개) |
| `.claude/hooks/` | SessionStart·SubagentStop 훅 스크립트 |
| `.claude/commands/` | 커스텀 커맨드 (/harness, /improve, /edit-harness, /exit-edit-harness) |
| `.claude/settings.json` | 훅 연결 설정 |
| `.claude-state/` | sprint 상태, 진행상황, 학습 누적 |
| `scripts/` | smoke·unit·e2e·evaluation-gate·collect-metrics·check-thresholds |
| `profiles/<stack>/scripts/` | 스택별 smoke·unit·e2e 스크립트 |
| `docs/` | 설계 문서 (planner가 생성, harness-reference.md 포함) |
