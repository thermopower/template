# Harness Version

version: 1.0
updated: 2026-04-01

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2026-04-01 | 정식 출시. Playwright MCP 브라우저 검증 통합, session-start.sh \n 정규화 버그 수정, 설계문서 실구현 동기화 완료 |
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
