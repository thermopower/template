# Harness Version

version: 1.0
updated: 2026-04-05

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2026-04-05 | state-writer 제거. plan-writer를 페이지 단위 → feature 단위로 재설계. 상태 설계(source of truth, 전역/로컬 구분, cross-page 공유 상태) plan.md 안에 통합. 산출물 경로 `docs/pages/{page}/` → `docs/features/{feature_id}/` |
| 1.0 | 2026-04-05 | planner: AC를 정상/경계/에러 케이스로 분리 작성 강제. 요구사항에 없는 케이스도 planner가 직접 채우도록 명시 |
| 1.0 | 2026-04-05 | common-module-writer: docs/usecases/ 전체 읽고 반복 패턴 미리 추출하는 단계 추가. plan-writer: 필요한 공통 모듈 누락 시 중단 후 보완 요청 경로 추가 |
| 1.0 | 2026-04-05 | planner: 범주형·파생 필드 AC 명시 규칙 추가 (저장→변환→레이어). reviewer: 1-A 요구사항↔구현 직접 비교 단계 추가 (AC 완결성 검증) |
| 1.0 | 2026-04-04 | smoke에 lint 추가, evaluation-gate에 npm audit(high 이상) 추가, planner smoke 템플릿 업데이트 |
| 1.0 | 2026-04-01 | Playwright MCP 브라우저 검증 통합, session-start.sh \n 정규화 버그 수정, 설계문서 실구현 동기화 완료 |
| 1.0 | 2026-04-01 | profiles/nextjs-supabase 예시 제거 (planner가 sprint마다 생성), collect-metrics.sh BLOCKER_COUNT 버그 수정 |

## 구성 요소

| 파일/폴더 | 역할 |
|-----------|------|
| `CLAUDE.md` | 하네스 운영 규칙 |
| `.ruler/AGENTS.md` | 코딩 원칙 |
| `.claude/agents/` | AI 에이전트 정의 (15개) |
| `.claude/hooks/` | SessionStart·SubagentStop 훅 스크립트 |
| `.claude/commands/` | 커스텀 커맨드 (/harness, /improve, /edit-harness, /exit-edit-harness) |
| `.claude/settings.json` | 훅 연결 설정 |
| `.claude-state/` | sprint 상태, 진행상황, 학습 누적 |
| `scripts/` | smoke·unit·e2e·evaluation-gate·collect-metrics·check-thresholds |
| `profiles/<stack>/scripts/` | 스택별 smoke·unit·e2e 스크립트 |
| `docs/` | 설계 문서 (planner가 생성, harness-reference.md 포함) |
