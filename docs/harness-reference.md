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
  sprint-builder:
    common-module-writer (공통 영역 먼저 확정)
        ↓
    [state-writer(페이지A) + state-writer(페이지B) + ...] 병렬
    [plan-writer(페이지A)  + plan-writer(페이지B)  + ...] 병렬
        ↓
    [implementer(parallel_safe:true 묶음)] 병렬
    [implementer(parallel_safe:false 순차)]
        ↓
    code-reviewer ──→ [NEEDS_WORK → implementer (최대 2회 루프)]
                   ──→ [LGTM → smoke → status: implemented]
        ↓ (hook: check-smoke.sh)
    evaluator ──→ evaluation-report (pass/fail)
        ↓ fail → integration-fixer 또는 수정 sprint
    reviewer ──→ review-notes.md (Critical/Major → 개선 우선순위, Minor → Backlog 후보)
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

| 에이전트 | 모델 | maxTurns | 특이 설정 | 역할 | 흡수한 스킬 | 금지 |
|---|---|---|---|---|---|---|
| **requirement-writer** | sonnet | 30 | — | 사용자 인터뷰→docs/requirement.md 작성. 단계별 명확화 질문, 대안 탐색, 사용자 승인 게이트 포함 | `brainstorming` | 설계·구현, 스택 임의 결정, 섹션 건너뜀, 승인 없이 완료 처리 |
| **planner** | sonnet | 40 | — | 요구사항→설계 문서+sprint-contract 초안. prd/userflow 병렬, dataflow/usecase 병렬. feature-list.json에 parallel_safe 필드 포함. 기존 코드베이스 있으면 수정 대상 패턴 전체 탐색 후 sprint 범위 확정 | `writing-plans` | 구현, 승인 없이 sprint-builder 실행, TBD/TODO 포함 산출물 |
| **sprint-builder** | sonnet | 80 | `permissionMode: acceptEdits` | 승인된 범위만 구현. common-module 먼저 확정 후 state/plan-writer 병렬, parallel_safe 기준으로 implementer 병렬/순차 분리. code-reviewer 루프(최대 2회) 포함 | `executing-plans` | 범위 초과, 검증 없이 done 선언, 블로커 임의 우회 |
| **code-reviewer** | sonnet | 20 | — | sprint 내부 코드 리뷰. major 이상만 피드백. LGTM 또는 NEEDS_WORK 반환. 수정 패턴과 동일한 패턴의 잔존 여부 grep 확인 포함. minor 언급 금지 | — | minor 지적, 리팩터링 제안, 범위 확장 요구 |
| **evaluator** | haiku | 40 | Playwright MCP | pass/fail 판정만. 브라우저 실동작 검증 포함. evaluation-report.md 작성. 완료 후 browser_close·스크린샷 삭제·cleanup 기록. sprint-contract.md 수정 금지 | — | 개선 제안, reviewer 역할, sprint-contract 수정 |
| **reviewer** | opus | 40 | — | 품질 비평·개선 제안. Critical/Major → 통합 개선 우선순위. Minor → Backlog 후보 섹션에만 기록 | — | pass/fail 판정, evaluator 역할, minor를 개선 우선순위에 포함 |
| **integration-fixer** | sonnet | 50 | `isolation: worktree`, Playwright MCP | evaluation-report fail 시 진입. 환경/의존성/broken state 복구. 6단계 조사 절차 (5단계 기록 + 6단계 레거시 정리). 완료 후 browser_close·스크린샷 삭제·cleanup 기록 | `systematic-debugging` | 기능 추가, 범위 확장, 근본 원인 미확인 수정 |
| **retrospective** | haiku | 20 | — | review-notes reviewed 시 진입. 지표 수집, learnings 누적 | — | learnings.md·metrics.json 외 파일 수정 |
| **policy-updater** | sonnet | 30 | — | learnings 존재 시 진입. learnings 기반 에이전트/정책 개정안 생성 | — | 승인 없이 파일 수정 |
| **implementer** | sonnet | 60 | — | plan.md 존재 시 진입. 구현 계획 기반 TDD 구현. 테스트 먼저, 구현 코드 나중 | `test-driven-development` | 테스트 없이 구현 코드 작성, TDD 사이클 위반 |
| **common-module-writer** | sonnet | 30 | — | 공통 모듈 계획 작성 및 TDD 구현 | `test-driven-development` | 테스트 없이 구현 코드 작성, 문서 근거 없는 모듈 설계 |

### sub-agents (planner/sprint-builder가 내부적으로 호출)

| 에이전트 | maxTurns | memory | 산출물 |
|---|---|---|---|
| **prd-writer** | 20 | project | `docs/prd.md` |
| **userflow-writer** | 20 | project | `docs/userflow.md` (prd 완료 후) |
| **dataflow-writer** | 20 | project | `docs/database.md` ← usecase-writer와 병렬 실행 (prd+userflow 완료 후) |
| **usecase-writer** | 20 | project | `docs/usecases/` ← dataflow-writer와 병렬 실행 (prd+userflow 완료 후) |
| **common-module-writer** | 30 | — | `docs/common-modules.md` + 구현 |
| **state-writer** | 25 | — | `docs/pages/{page}/state.md` |
| **plan-writer** | 25 | — | `docs/pages/{page}/plan.md` |
| **implementer** | 60 | — | 구현 코드 (plan.md 존재 시 진입) |

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
| `review-notes.md` | reviewer | `status: reviewed` (이 값이 retrospective 트리거 조건), Critical/Important/Suggestions |
| `learnings.md` | retrospective | `status: active/reviewed`, `improve_needed: true/false`, sprint별 요약 |
| `metrics.json` | retrospective | sprints[], summary (pass_rate, avg_blockers 등) |
| `harness-version.md` | 자동 (하네스 구조 변경 시) | 하네스 버전, 변경 이력, 구성 요소 |
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

스택별 스크립트 위치: `profiles/<stack>/scripts/{smoke,unit,e2e}` (planner가 sprint 시작 시 생성)

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
2. **리뷰 완료 후**: 다음 sprint 범위 제안 → 진행 여부 확인
3. **policy-updater 완료 후**: 개정안 diff 제시 → 승인 후에만 파일 적용

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

**일반 편집 모드**: Superpowers 스킬을 정상적으로 사용한다.

**하네스 루프 모드** (`/harness` 실행 후): Superpowers 스킬을 사용하지 않는다. 하네스 에이전트가 각 스킬 역할을 완전히 대체하기 때문이다.

| Superpowers 스킬 | 대체 에이전트 |
|---|---|
| `brainstorming` | `requirement-writer` |
| `writing-plans` | `planner`, `plan-writer` |
| `executing-plans` | `sprint-builder` |
| `systematic-debugging` | `integration-fixer` |
| `test-driven-development` | `implementer`, `common-module-writer` |

CLAUDE.md 섹션 0에 최우선 규칙으로 선언되어 있다. 각 에이전트 파일에도 `**어떤 외부 스킬도 호출하지 않는다**` 지시가 명시되어 있다.

---

## Playwright MCP 브라우저 검증

디버깅 및 평가 단계에서 실제 브라우저 동작을 확인하기 위해 Playwright MCP를 사용한다.

### 사용 에이전트

| 에이전트 | 사용 시점 | 주요 확인 항목 |
|---|---|---|
| **evaluator** | acceptance criteria 검증 시 | 앱 접속, 핵심 user flow 실행, 콘솔 에러 |
| **integration-fixer** | 복구 후 검증 시 | 오류 재현 여부, 콘솔 에러 소멸, 복구 경로 동작 |

### 기본 검증 흐름

```
1. browser_navigate  → 앱 URL 접속
2. browser_snapshot  → 화면 상태 확인
3. browser_click / browser_fill_form  → 핵심 시나리오 실행
4. browser_console_messages  → 콘솔 에러 잔존 여부 확인
5. browser_take_screenshot  → 결과 기록 (report에 포함)
6. browser_close  → 브라우저 세션 닫기
7. (임시 파일 정리)  → 검증 중 생성된 스크린샷(*.png, *.jpg) 삭제
8. (완료 기록)  → report/progress에 cleanup: done 추가
```

### SKIP 조건

앱 서버가 실행 중이지 않으면 Playwright MCP 검증을 SKIP하고 그 사유를 report에 명시한다. SKIP 자체가 fail 판정 사유가 되지는 않는다.

---

## 커스텀 커맨드 (`/.claude/commands/`)

| 커맨드 | 역할 |
|---|---|
| `/improve` | learnings 기반 policy-updater 실행 → 에이전트/정책 개정안 생성 |
| `/edit-harness` | 하네스 루프 비활성화. 템플릿 자체를 수정할 때 사용. 세션 재시작 시 자동 해제 |
| `/exit-edit-harness` | 하네스 모드 복귀. 상태 파일 재확인 후 다음 단계 안내 |
| `/commit` | 변경사항 확인 → 커밋 메시지 초안 제시 → 사용자 확인 후 커밋 + 푸시 |

> 이 저장소는 하네스 템플릿 자체이므로, 에이전트/설정 수정 시 `/edit-harness`로 먼저 전환한다.

---

## 세션 시작 체크리스트

1. `session-start.sh` 출력(additionalContext)에서 현재 단계 확인
2. 위 **단계 전환 조건 표**로 다음 액션 결정
3. 해당 에이전트 실행 또는 사용자 승인 요청

---

## Playwright MCP 서브에이전트 설정

evaluator·integration-fixer 에이전트가 `mcp__plugin_playwright_*` 도구를 사용하려면 프로젝트 루트의 `.mcp.json`에 서버가 등록되어 있어야 한다. 플러그인 MCP는 메인 세션에만 자동 주입되며 서브에이전트에는 상속되지 않는다.

현재 설정:
- `.mcp.json` — playwright MCP 서버 정의 (`npx @playwright/mcp@latest`)
- `.claude/settings.json` — `enabledMcpjsonServers: ["playwright"]` 로 자동 승인

---

## Windows 환경 주의사항

`.claude/settings.json`의 훅 명령은 `bash`를 직접 호출한다. Windows에서는 **Git Bash** 또는 **WSL**이 설치되어 있어야 훅이 정상 동작한다. 없으면 `SessionStart`, `SubagentStop` 훅이 모두 실패한다.

`session-start.sh`는 `CONTEXT` 변수 조립 시 리터럴 `\n`과 파일 줄바꿈이 섞이는 문제를 Python 전처리(`replace('\\n', '\n')`)로 정규화한다.
