# Harness 참조 문서

> 매 세션 전체를 읽지 말고 이 문서만 참조하세요.  
> 상세 내용이 필요할 때만 해당 파일을 직접 읽으세요.

---

## 전체 흐름

```
requirement.md 비어있음
        ↓
requirement-writer (사용자 인터뷰 → 파일 작성)
        ↓
    planner ──→ sprint-contract (draft) ──→ [사용자 승인]
        ↓
  sprint-builder ──→ status: implemented
        ↓ (hook: check-smoke.sh)
    evaluator ──→ evaluation-report (pass/fail)
        ↓ fail → integration-fixer 또는 수정 sprint
    reviewer ──→ review-notes.md
        ↓ (hook: trigger-retrospective.sh)
  retrospective ──→ learnings.md (improve_needed: true/false) + metrics.json
        ↓ improve_needed: true 일 때만
  /improve → policy-updater ──→ 에이전트/정책 개정안 [사용자 승인 후 적용]
```

---

## 단계 전환 조건 (빠른 판단)

| requirement.md | sprint-contract status | evaluation-report | review-notes | learnings.md | → 다음 액션 |
|---|---|---|---|---|---|
| 비어있음 | - | - | - | - | requirement-writer 실행 |
| 있음 | none | - | - | - | planner 실행 |
| 있음 | draft | - | - | - | 사용자에게 승인 요청 |
| 있음 | approved | - | - | - | sprint-builder 실행 |
| 있음 | implemented | none/없음 | - | - | evaluator 실행 |
| 있음 | implemented | fail | - | - | integration-fixer 또는 수정 sprint |
| 있음 | implemented | pass | 없음 | - | reviewer 실행 |
| 있음 | implemented | pass | reviewed | none/없음 | retrospective 실행 |
| 있음 | implemented | pass | reviewed | active, improve_needed: true | /improve 실행 권장 |
| 있음 | implemented | pass | reviewed | active, improve_needed: false | 다음 sprint 진행 여부 확인 |

---

## 에이전트 역할 요약

| 에이전트 | 모델 | 역할 | 흡수한 스킬 | 금지 |
|---|---|---|---|---|
| **requirement-writer** | sonnet | 사용자 인터뷰→docs/requirement.md 작성. 단계별 명확화 질문, 대안 탐색, 사용자 승인 게이트 포함 | `brainstorming` | 설계·구현, 스택 임의 결정, 섹션 건너뜀, 승인 없이 완료 처리 |
| **planner** | sonnet | 요구사항→설계 문서+sprint-contract 초안. 플레이스홀더 금지, 검증 가능한 criteria, TDD 사이클 포함 계획 작성 | `writing-plans` | 구현, 승인 없이 sprint-builder 실행, TBD/TODO 포함 산출물 |
| **sprint-builder** | sonnet | 승인된 범위만 구현. 계획 비판적 검토, 블로커 즉시 중단·보고 | `executing-plans` | 범위 초과, 검증 없이 done 선언, 블로커 임의 우회 |
| **evaluator** | haiku | pass/fail 판정만 | — | 개선 제안, reviewer 역할 |
| **reviewer** | opus | 품질 비평·개선 제안 | — | pass/fail 판정, evaluator 역할 |
| **integration-fixer** | sonnet | 환경/의존성/broken state 복구. 근본 원인 없이 수정 금지, 4단계 조사 절차 | `systematic-debugging` | 기능 추가, 범위 확장, 근본 원인 미확인 수정 |
| **retrospective** | haiku | 지표 수집, learnings 누적 | — | learnings.md·metrics.json 외 파일 수정 |
| **policy-updater** | sonnet | learnings 기반 에이전트/정책 개정안 생성 | — | 승인 없이 파일 수정 |
| **implementer** | sonnet | 구현 계획 기반 TDD 구현. 테스트 먼저, 구현 코드 나중 | `test-driven-development` | 테스트 없이 구현 코드 작성, TDD 사이클 위반 |
| **common-module-writer** | sonnet | 공통 모듈 계획 작성 및 TDD 구현 | `test-driven-development` | 테스트 없이 구현 코드 작성, 문서 근거 없는 모듈 설계 |

### sub-agents (planner/sprint-builder가 내부적으로 호출)
- **prd-writer** → `docs/prd.md`
- **userflow-writer** → `docs/userflow.md`
- **dataflow-writer** → `docs/database.md`
- **usecase-writer** → `docs/usecases/`
- **common-module-writer** → 공통 모듈 작업 계획 및 구현
- **state-writer** → 상태관리 설계
- **plan-writer** → 페이지/기능별 구현 계획
- **implementer** → 구현 계획 실행

---

## 상태 파일 (`/.claude-state/`)

| 파일 | 작성자 | 핵심 필드 |
|---|---|---|
| `claude-progress.txt` | 모든 에이전트 | 현재 상태, blocker, 다음 액션 |
| `sprint-contract.md` | planner | `status: none/draft/approved/implemented` |
| `product-spec.md` | planner | 제품 목표, 핵심 플로우, 범위 |
| `feature-list.json` | planner | id, priority, status, acceptance_criteria, verification_linkage |
| `sprint-plan.md` | planner | feature 순서, 예상 리스크 |
| `evaluation-report.md` | evaluator | `status: pass/fail`, blocker 목록, total_turns |
| `review-notes.md` | reviewer | `status: reviewed`, Critical/Important/Suggestions |
| `learnings.md` | retrospective | `status: active/reviewed`, `improve_needed: true/false`, sprint별 요약 |
| `metrics.json` | retrospective | sprints[], summary (pass_rate, avg_blockers 등) |
| `harness-version.md` | 수동 | 하네스 버전, 변경 이력, 구성 요소 |
| `decisions.md` | 수동 | 아키텍처 결정 기록 |
| `backlog.md` | 수동 | 다음 sprint 후보 |

---

## Hooks (`/.claude/settings.json`)

| 이벤트 | 조건 | 스크립트 | 역할 |
|---|---|---|---|
| SessionStart | 항상 | `session-start.sh` | 상태 스캔 → additionalContext 주입 |
| SubagentStop | sprint-builder | `check-smoke.sh` | smoke + stub 검사, 실패 시 exit 2로 차단 |
| SubagentStop | reviewer | `trigger-retrospective.sh` | retrospective 트리거 |
| SubagentStop | evaluator·reviewer·retrospective | `check-output.sh` | 출력 결과 검증 |

---

## 검증 스크립트 (`/scripts/`)

| 스크립트 | 역할 | 호출 시점 |
|---|---|---|
| `smoke` | 빌드 + 타입체크 | sprint-builder 완료 시, check-smoke hook |
| `unit` | 단위 테스트 (없으면 SKIP) | evaluator |
| `e2e` | E2E 테스트 (없으면 SKIP) | evaluator |
| `evaluation-gate` | 전체 평가 게이트 | evaluator |
| `collect-metrics.sh <sprint_id>` | metrics.json 갱신 | retrospective |
| `check-thresholds.sh [--summary]` | 임계점 판정 | retrospective, session-start |

스택별 스크립트 위치: `profiles/<stack>/scripts/{smoke,unit,e2e}`

---

## 임계점 (policy-updater 권장 트리거)

| 조건 | 내용 |
|---|---|
| 3회 연속 eval fail | 에이전트 정책 개선 필요 |
| pass율 < 50% (4회 이상) | 전반적 품질 문제 |
| 동일 blocker 유형 3회 이상 | 특정 패턴 반복 |
| 평균 턴 수 60 초과 3회 연속 | 효율 저하 |

---

## 사용자 승인 필수 시점

1. **planner 완료 후**: sprint-contract 초안 제시 → 승인 후에만 sprint-builder 시작
2. **policy-updater**: 개정안 diff 제시 → 승인 후에만 파일 적용

---

## 스택 판단 기준 (planner가 프로필 스크립트 생성 시)

| 요구사항 키워드 | profile 이름 | 빌드 도구 | 단위 테스트 | E2E | src/ 레이어 구조 |
|---|---|---|---|---|---|
| Next.js + Supabase | nextjs-supabase | npm run build + tsc | vitest | playwright | app/(P), lib/(A), domain/(D), server/+lib/db/(I) |
| Next.js (단독) | nextjs | npm run build + tsc | vitest | playwright | app/(P), lib/(A), domain/(D), server/(I) |
| React + Vite | react-vite | npm run build | vitest | playwright | pages/+components/(P), hooks/+services/(A), domain/(D), api/+lib/(I) |
| Python FastAPI | fastapi | py_compile + pytest | pytest | httpx | routers/+schemas/(P), services/(A), domain/(D), repositories/+db/(I) |
| 판단 불가 | generic | npm run build (있으면) | SKIP | SKIP | planner가 직접 확정 |

P=Presentation, A=Application, D=Domain, I=Infrastructure

---

## Superpowers 스킬 억제 정책

이 저장소에서는 Superpowers 스킬을 사용하지 않는다. 하네스 에이전트가 각 스킬 역할을 완전히 대체한다.

| Superpowers 스킬 | 대체 에이전트 |
|---|---|
| `brainstorming` | `requirement-writer` |
| `writing-plans` | `planner`, `plan-writer` |
| `executing-plans` | `sprint-builder` |
| `systematic-debugging` | `integration-fixer` |
| `test-driven-development` | `implementer`, `common-module-writer` |

CLAUDE.md 섹션 0에 최우선 규칙으로 선언되어 있다. 각 에이전트 파일에도 `**어떤 외부 스킬도 호출하지 않는다**` 지시가 명시되어 있다.

---

## 커스텀 커맨드 (`/.claude/commands/`)

| 커맨드 | 역할 |
|---|---|
| `/improve` | learnings 기반 policy-updater 실행 → 에이전트/정책 개정안 생성 |
| `/edit-harness` | 하네스 루프 비활성화. 템플릿 자체를 수정할 때 사용. 세션 재시작 시 자동 해제 |
| `/exit-edit-harness` | 하네스 모드 복귀. 상태 파일 재확인 후 다음 단계 안내 |

> 이 저장소는 하네스 템플릿 자체이므로, 에이전트/설정 수정 시 `/edit-harness`로 먼저 전환한다.

---

## 세션 시작 체크리스트

1. `session-start.sh` 출력(additionalContext)에서 현재 단계 확인
2. 위 **단계 전환 조건 표**로 다음 액션 결정
3. 해당 에이전트 실행 또는 사용자 승인 요청
