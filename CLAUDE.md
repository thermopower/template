# 하네스 운영 규칙

이 저장소는 Claude Code 기반 앱 생성 하네스다.
요구사항을 직접 작성하거나, requirement-writer와 대화해 `docs/requirement.md`를 작성하면 planner → sprint-builder → evaluator → reviewer → retrospective 루프로 앱을 생성하고 스스로 학습한다.

---

## 0. Superpowers 스킬 사용 금지 (최우선 규칙)

**이 저장소에서는 Superpowers 스킬을 사용하지 않는다.**

하네스 에이전트가 각 스킬의 역할을 완전히 대체한다:

| Superpowers 스킬 | 대체 에이전트 |
|---|---|
| `brainstorming` | `requirement-writer` |
| `writing-plans` | `planner`, `plan-writer` |
| `executing-plans` | `sprint-builder` |
| `systematic-debugging` | `integration-fixer` |
| `test-driven-development` | `implementer`, `common-module-writer` |

사용자가 어떤 요청을 하더라도 위 에이전트를 통해 처리한다. Skill 도구를 호출하지 않는다.

---

## 1. 세션 시작 시 필수 절차

1. `.claude-state/claude-progress.txt`를 먼저 읽는다.
2. `.claude-state/sprint-contract.md`의 status를 확인한다.
3. 아래 단계 전환 규칙으로 현재 위치를 판단한다.

## 2. 단계 전환 규칙

| 조건 | 다음 단계 |
|---|---|
| `docs/requirement.md` 내용 없음 | requirement-writer 실행 (사용자와 대화로 요구사항 수집) |
| `.claude-state/sprint-contract.md` status: none | planner 실행 |
| status: draft | 사용자에게 sprint-contract 내용 제시 후 승인 요청 |
| status: approved | sprint-builder 실행 |
| status: implemented, `evaluation-report.md` status: none | evaluator 실행 |
| `evaluation-report.md` status: fail | blocker 확인 → integration-fixer 또는 수정 sprint |
| `evaluation-report.md` status: pass, `review-notes.md` 없음 | reviewer 실행 |
| `review-notes.md` 작성 완료, `learnings.md` status: none | retrospective 실행 |
| retrospective 완료 (`learnings.md` status: active), `improve_needed: true` | 사용자에게 `/improve` 실행 권장 |
| retrospective 완료 (`learnings.md` status: active), `improve_needed: false` | 사용자에게 다음 sprint 진행 여부 확인 |
| `/improve` 명령 | policy-updater 실행 |

## 3. 사용자 승인이 필요한 두 시점

**반드시 멈추고 사용자 확인을 받는다:**
- planner 완료 후: sprint-contract 초안을 제시하고 범위 승인을 받는다. 승인 없이 sprint-builder를 시작하지 않는다.
- 리뷰 완료 후: 다음 sprint 범위를 제안하고 진행 여부를 확인한다.

## 4. 역할 구분

- **requirement-writer**: 사용자와 대화해 요구사항 수집 → docs/requirement.md 작성. 설계·구현하지 않는다.
- **planner**: 요구사항 → 설계 문서 + sprint-contract 초안. 구현하지 않는다.
- **sprint-builder**: 승인된 sprint-contract 범위만 구현. 범위를 넘지 않는다.
- **evaluator**: pass/fail 판정만 한다. 개선 제안을 하지 않는다.
- **reviewer**: 품질 비평과 개선 제안만 한다. pass/fail 판정을 하지 않는다.
- **integration-fixer**: 환경/의존성 복구만 한다. 기능을 추가하지 않는다.
- **retrospective**: sprint 지표 수집 및 learnings 누적. 파일 수정은 learnings.md/metrics.json만 허용.
- **policy-updater**: learnings 기반 개정안 생성. 업데이트 우선, 신규 최소. 승인 후 적용.

evaluator와 reviewer는 다른 역할이다. 절대 혼용하지 않는다.

## 5. Context Window 절약 원칙

- 코드 탐색은 Explore subagent에 위임한다. main context에서 직접 파일을 통째로 읽지 않는다.
- 이전에 파악한 파일 구조와 의존 관계는 subagent memory에 기록해 재탐색을 방지한다.
- `feature-list.json`의 `verification linkage`로 탐색 범위를 파일 단위로 좁힌다.

## 6. 품질 기준

- stub, placeholder, TODO가 핵심 경로에 남아 있으면 완료가 아니다.
- smoke test를 통과하지 않으면 sprint-builder를 완료로 처리하지 않는다.
- QA 없이 done 선언하지 않는다.

## 7. 상태 파일 원칙

- 상태는 대화가 아니라 `.claude-state/` 파일에 남긴다.
- 세션이 끊겨도 상태 파일을 기반으로 재개한다.
- `claude-progress.txt`에는 항상 현재 상태, blocker, 다음 액션을 기록한다.

## 8. 자기개선 명령

- `/improve`: 누적된 learnings 기반으로 policy-updater를 실행해 에이전트·정책 개정안을 생성한다.
  - 개정안은 diff 형태로 제시되며 사용자 승인 후 적용된다.
  - learnings가 없으면 실행하지 않는다.

## 9. 코딩 원칙

@.ruler/AGENTS.md
