# Self-Learning Harness Design

## 목표

하네스가 sprint 루프 결과를 스스로 학습하고, 정량 지표 기반으로 정책·에이전트·hook을 개선하는 자기개선 시스템을 추가한다.

---

## 핵심 원칙

- **learnings 누적·컨텍스트 주입은 자동**
- **파일 수정(CLAUDE.md, 에이전트, hooks)은 사용자 승인 필수**
- **업데이트 우선, 신규 생성 최소화** — 3회 이상 반복 패턴 + 기존 파일 커버 불가 시에만 신규 파일 생성
- **학습 범위:** 현재 저장소 + `~/.claude/projects/` cross-session memory

---

## 전체 구조

```
기존 루프:
planner → sprint-builder → evaluator → reviewer

변경 후:
planner → sprint-builder → evaluator → reviewer → retrospective
                                                        ↓
                                          (임계점 도달 or /improve)
                                                        ↓
                                              policy-updater
```

---

## 새로 추가되는 파일

| 파일 | 역할 |
|---|---|
| `.claude/agents/retrospective.md` | sprint 종료 후 자동 실행, 정량 지표 분석, learnings 누적 |
| `.claude/agents/policy-updater.md` | 기존 파일 업데이트 우선, 최소 생성, 사용자 승인 후 적용 |
| `.claude-state/learnings.md` | 누적 학습 데이터 (blocker 패턴, pass율, 턴 수) |
| `.claude-state/metrics.json` | 정량 지표 시계열 기록 |
| `scripts/collect-metrics.sh` | 지표 집계 스크립트 |
| `scripts/check-thresholds.sh` | 임계점 감지 스크립트 |
| `.claude/hooks/trigger-retrospective.sh` | reviewer 완료 시 retrospective 트리거 |

---

## 변경되는 파일

| 파일 | 변경 내용 |
|---|---|
| `CLAUDE.md` | retrospective 단계 추가, `/improve` 명령 설명 |
| `.claude/settings.json` | retrospective hook 배선, `/improve` slash command |
| `.claude/hooks/session-start.sh` | learnings를 컨텍스트에 주입 |
| `.claude/hooks/check-output.sh` | retrospective 산출물 체크 추가 |

---

## 데이터 구조

### metrics.json

```json
{
  "sprints": [
    {
      "sprint_id": "sprint-001",
      "date": "2026-03-31",
      "eval_result": "pass|fail",
      "blocker_count": 2,
      "blocker_types": ["dependency", "type_error"],
      "total_turns": 45,
      "fix_iterations": 1
    }
  ],
  "summary": {
    "total_sprints": 5,
    "pass_rate": 0.6,
    "avg_blockers_per_sprint": 2.4,
    "avg_turns": 52,
    "repeated_blocker_types": {"type_error": 3, "dependency": 2}
  }
}
```

### learnings.md 항목 구조

```markdown
## Sprint 001 — 2026-03-31
- eval: fail → pass (fix_iterations: 1)
- blocker: type_error (TypeScript any 사용)
- 개선 적용: implementer.md에 "any 금지" 강화
- 턴 수: 45 (정상)
```

---

## 임계점 정의

| 지표 | 임계점 | 트리거 |
|---|---|---|
| eval pass율 | 3회 연속 fail 또는 전체 pass율 < 50% | policy-updater 자동 제안 |
| 동일 blocker 유형 반복 | 3회 이상 | 해당 에이전트 instruction 개정 제안 |
| sprint 평균 턴 수 | 기준(60턴) 초과 3회 연속 | 범위 분해 전략 개정 제안 |

---

## 에이전트 설계

### retrospective

- **model:** haiku
- **tools:** Read, Write, Edit, Bash, Glob, Grep
- **maxTurns:** 20
- **memory:** project
- **실행 순서:** evaluation-report + sprint-contract + review-notes 읽기 → memory 참조 → metrics.json 갱신 → learnings.md 누적 → check-thresholds.sh 실행 → 임계점 도달 시 사용자에게 `/improve` 권장 알림
- **금지:** 파일 직접 수정(learnings, metrics 제외), policy-updater 자동 실행

### policy-updater

- **model:** sonnet
- **tools:** Read, Write, Edit, Glob, Grep
- **maxTurns:** 30
- **memory:** project
- **실행 순서:** learnings + metrics 읽기 → 개선 항목 목록 작성 → 업데이트 vs 신규 생성 판단 → diff 제시 → 사용자 승인 후 적용
- **신규 파일 생성 조건:** 동일 패턴 3회 이상 반복 + 기존 파일 커버 불가 + 독립 단위
- **금지:** 승인 없이 파일 수정, 조건 미충족 신규 생성, CLAUDE.md 직접 수정

---

## Hook 배선

### TeammateIdle — reviewer 완료 시

`trigger-retrospective.sh` → retrospective 에이전트 실행 안내를 additionalContext로 주입

### session-start.sh 추가

learnings.md 최근 20줄 + check-thresholds.sh 요약을 세션 컨텍스트에 주입

### /improve slash command

policy-updater 에이전트 실행 트리거
