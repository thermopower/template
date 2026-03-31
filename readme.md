# Claude Code App Generation Harness Roadmap

## 1. 문서 목적

이 문서는 Claude Code 기반 앱 생성 하네스를 설계, 구축, 운영, 검증, 배포하기 위한 기준 문서다.

본 하네스의 목표는 다음과 같다.

- 사용자의 짧은 요구사항으로부터 앱을 생성한다.
- 생성 과정을 계획, 구현, 평가, 리뷰, 수정 루프로 관리한다.
- 세션이 끊겨도 상태 파일을 기반으로 재개 가능해야 한다.
- 운영 자동화는 모델의 자율성에만 의존하지 않고 hook, script, state를 통해 강제한다.
- 공통 하네스는 추후 plugin으로 추출할 수 있도록 구조화한다.

본 문서는 repo template 단계부터 시작하되, 처음부터 하네스 코어를 포함한 실행형 템플릿을 전제로 한다.

---

## 2. 기본 원칙

### 2.1 하네스는 템플릿보다 우선한다
이 저장소는 단순 보일러플레이트가 아니라 Claude Code가 앱을 안정적으로 생성하도록 돕는 실행 환경이다.

### 2.2 완료 기준은 코드 작성이 아니라 검증 통과다
기능 구현은 완료가 아니다. 계약된 acceptance criteria를 충족하고, smoke, unit, e2e, QA gate를 통과해야 완료다.

### 2.3 상태는 대화가 아니라 파일에 남긴다
장기 작업 상태, 스프린트 범위, 평가 결과, 리뷰 결과, 다음 액션은 모두 상태 파일에 기록한다.

### 2.4 상시 규칙은 짧고 명확하게 유지한다
`CLAUDE.md`는 매 세션 시작 시 로드되는 상시 문맥이므로 짧고 핵심적인 규칙만 담는다. 세부 규칙은 별도 rules 또는 skill 문서로 분리한다.

### 2.5 계획, 평가, 리뷰는 반드시 분리한다
무엇을 만들지 정하는 역할, 구현 결과를 합격/불합격 판정하는 역할, 더 나은 방향을 비평하는 역할은 분리한다. 하나의 에이전트가 이 셋을 동시에 맡지 않는다.

### 2.6 운영 자동화는 deterministic하게 설계한다
반복되는 규칙 집행, 포맷, 테스트, 위험 작업 차단, 로그 기록은 hook과 script로 처리한다.

### 2.7 plugin은 시작점이 아니라 검증된 코어의 배포 방식이다
처음에는 repo template 안에서 코어를 운영하고, 반복 검증 후 공통부만 plugin으로 추출한다.

---

## 3. 목표 아키텍처

### 3.1 최상위 구조

```text
repo-template/
  CLAUDE.md
  README.md
  .claude/
    agents/
    hooks/
    rules/
    skills/
    commands/
  .claude-state/
  scripts/
  profiles/
  app/
  docs/
```

### 3.2 레이어별 책임

#### CLAUDE.md

* 상시 운영 규칙
* 작업 원칙
* 상태 파일 우선 읽기 규칙
* 구현 전후 필수 절차
* 품질 기준
* 하위 규칙 파일 import

#### .claude/agents/

* planner
* sprint-builder
* evaluator
* reviewer
* integration-fixer
* retrospective
* policy-updater
* optional specialist reviewers

#### .claude/hooks/

* SessionStart
* PreToolUse
* PostToolUse
* SubagentStop
* Stop

#### .claude/rules/

* frontend
* backend
* testing
* security
* architecture

#### .claude/skills/

* new app generation
* sprint execution
* app evaluation
* app review
* handoff packaging

#### .claude-state/

* product spec
* sprint plan
* sprint contract
* feature list
* evaluation result
* review notes
* progress
* decisions
* backlog
* learnings
* metrics

#### scripts/

* init
* dev-up
* smoke
* unit test
* e2e test
* evaluation gate
* review preparation
* context packaging
* collect-metrics
* check-thresholds

#### profiles/

* stack-specific and app-type-specific configuration
* example: nextjs-supabase, react-fastapi, electron-local
* `profiles/<stack>/scripts/smoke` — 스택별 smoke test (빌드, 타입체크, stub 검사)
* `profiles/<stack>/scripts/unit` — 단위 테스트 실행
* `profiles/<stack>/scripts/e2e` — E2E 테스트 실행
* **planner가 요구사항에서 스택을 판단해 자동 생성**한다. 이미 존재하면 덮어쓰지 않는다.
* profile 없을 때 `scripts/smoke`가 기본 빌드/syntax/stub 검사를 실행하고, unit/e2e는 SKIP 처리한다.

#### app/

* generated application code

---

## 4. 핵심 에이전트 구조

### 4.1 planner

planner는 사용자 요구사항을 실행 가능한 제품 스펙과 작업 계획으로 변환하는 역할을 맡는다.

#### subagent 설정

* `model: sonnet` — 요구사항 해석과 구조화에 충분한 수준
* `memory: project` — 요구사항 해석 패턴, 반복 실수, 범위 판단 기준 누적
* `tools: Read, Write, Edit, Glob, Grep` — 파일 읽기/쓰기만 허용, Bash 불필요
* `maxTurns: 30` — 무한 루프 방지

#### 책임

* 요구사항 해석
* 제품 목표 정의
* 핵심 사용자 플로우 정리
* 기능 분해
* 우선순위 설정
* sprint 후보 정의
* acceptance criteria 초안 작성
* `sprint-contract.md` 초안 작성 — sprint-builder가 준수할 계약의 작성 주체
* 기술 스택 판단 후 `profiles/<stack>/scripts/{smoke,unit,e2e}` 자동 생성

#### 산출물

* `product-spec.md`
* `feature-list.json`
* `sprint-plan.md`
* `sprint-contract.md`
* `decisions.md`
* `profiles/<stack>/scripts/smoke`, `unit`, `e2e`

#### 금지

* 과도한 기술 결정 고정
* 구현 세부까지 미리 확정
* 검증 불가능한 요구 정의
* 범위를 부풀리는 계획 수립

---

### 4.2 sprint-builder

sprint-builder는 승인된 sprint 범위를 구현하는 역할을 맡는다.

#### subagent 설정

* `model: sonnet` — 구현 중심 작업
* `memory: project` — 구현 중 발견한 기술 결정, blocker 패턴 누적
* `permissionMode: acceptEdits` — 파일 편집 승인 프롬프트 제거로 구현 흐름 유지
* `maxTurns: 80` — 대형 sprint 대응, 무한 루프 방지
* `SubagentStop` hook: 종료 전 smoke test + stub 잔존 여부 확인 강제 (profile 없으면 기본 빌드/syntax/stub 검사 실행)

#### 책임

* sprint contract 준수
* 기능 구현
* 필요한 테스트 추가 또는 갱신
* 상태 파일 갱신
* 구현 중 blocker 식별

#### 산출물

* 앱 코드 변경
* `sprint-contract.md` 업데이트
* 구현 메모
* 필요한 test asset

#### 금지

* 승인되지 않은 범위 확장
* 핵심 기능 stub를 완료 처리
* 검증 없이 done 선언
* unrelated refactor 수행

---

### 4.3 evaluator

evaluator는 구현 결과가 요구사항과 sprint contract를 충족하는지 판정하는 역할을 맡는다. evaluator의 본업은 비평이 아니라 합격/불합격 판정이다.

#### subagent 설정

* `model: haiku` — pass/fail 판정은 빠르고 저렴한 모델로 충분
* `memory: project` — 판정 이력, 반복되는 실패 유형 누적
* `tools: Read, Bash, Glob, Grep` — 테스트 실행 및 결과 확인, 파일 수정 불가
* `maxTurns: 40`
* `SubagentStop` hook: 종료 전 `evaluation-report.md` 갱신 여부 확인 강제

#### 책임

* acceptance criteria 기준 검증
* smoke, unit, e2e 결과 확인
* 핵심 사용자 플로우 실행
* blocker 식별
* pass/fail 판정
* regression 여부 확인

#### 산출물

* `evaluation-report.md`
* pass/fail summary
* blocker list
* regression notes

#### 금지

* 개선 아이디어 중심으로 판단 흐리기
* 미검증 상태를 pass 처리
* 디자인 비평을 합격 판정과 혼합
* “대충 동작함”을 완료로 인정

---

### 4.4 reviewer

reviewer는 구현 결과를 두 관점에서 비평하고 개선 방향을 제안하는 역할을 맡는다. reviewer는 pass/fail 심판이 아니라 개선 제안자다.

두 단계로 실행된다: 계획 정렬성 검증(superpowers code-reviewer 서브에이전트 위임) → UX·품질 비평(직접 수행).

#### subagent 설정

* `model: opus` — 깊이 있는 품질 비평과 통합 판단에 고성능 모델 사용
* `memory: project` — 누적 품질 지적, 개선 포인트 이력 관리
* `tools: Read, Write, Edit, Glob, Grep, Agent, Bash` — Write/Edit: review-notes.md 기록, Agent: 서브에이전트 위임, Bash: git log로 BASE_SHA 결정
* `maxTurns: 40`
* `SubagentStop` hook: 종료 전 `review-notes.md` 갱신 여부 확인 강제

#### 책임

**1단계 — 계획 정렬성 검증 (superpowers code-reviewer 위임)**
* sprint-contract 대비 구현 이탈 여부 확인
* 미구현 기능 탐지
* 아키텍처·패턴 표준 준수 여부

**2단계 — UX·품질 비평 (직접 수행)**
* UX 흐름의 명확성
* 기술 부채와 장기 유지보수성
* 불필요한 복잡성 식별
* cosmetic 문제와 구조 문제 구분

#### 산출물

* `review-notes.md` — 두 섹션(계획 정렬성 / UX·품질 비평) + 통합 개선 우선순위 5개 이내
* improvement recommendations (severity: critical / major / minor)

#### 금지

* pass/fail 최종 판정 수행
* 구현 범위를 임의로 늘리는 요구
* 핵심 기능 미완성을 시각적 포장으로 덮기
* evaluator 역할 수행 (테스트 재실행, criteria 판정)

---

### 4.5 integration-fixer

integration-fixer는 환경, 의존성, 런타임, 배선, migration, broken state를 복구하는 역할을 맡는다.

#### subagent 설정

* `model: sonnet`
* `memory: project` — 복구 레시피, 환경별 known issues 누적
* `isolation: worktree` — 복구 시도가 main 브랜치를 오염시키지 않도록 격리된 git worktree에서 실행
* `maxTurns: 50`

#### 책임

* dev 환경 복구
* route, API, DB wiring 수정
* migration/seed 문제 해결
* broken dependency 수정
* 재현 가능한 통합 오류 제거

#### 산출물

* 복구된 실행 환경
* fix notes
* root cause summary
* recovery instructions

#### 금지

* 새로운 기능 추가
* 스프린트 범위 확장
* unrelated cleanup 수행

---

### 4.6 specialist reviewers

reviewer는 superpowers 플러그인의 `code-reviewer` 에이전트를 서브에이전트로 호출해 계획 정렬성을 위임한다. 플러그인이 설치되어 있지 않으면 1단계를 건너뛰고 UX·품질 비평만 수행한다.

필요에 따라 추가 전문 리뷰어를 `.claude/agents/`에 둘 수 있다.

#### 예시 역할

* ux-reviewer
* security-reviewer
* performance-reviewer

---

### 4.7 retrospective

retrospective는 sprint 루프 종료 후 자동 실행되어 정량 지표를 수집하고 learnings를 누적하는 역할을 맡는다.

#### subagent 설정

* `model: haiku` — 지표 수집과 파일 기록은 경량 모델로 충분
* `memory: project` — cross-session 패턴 참조
* `tools: Read, Write, Edit, Bash, Glob, Grep`
* `maxTurns: 20`
* `SubagentStop` hook: 종료 전 learnings.md / metrics.json 갱신 여부 확인

#### 책임

* evaluation-report, sprint-contract, review-notes 읽기
* `collect-metrics.sh` 실행 → metrics.json 갱신
* learnings.md에 이번 sprint 요약 누적 (파일 하단 append, 5줄 이내)
* `check-thresholds.sh` 실행 → 임계점 도달 시 사용자에게 `/improve` 권장

#### 산출물

* `learnings.md` (누적 append)
* `metrics.json` (갱신)
* 임계점 도달 시 경고 메시지

#### 금지

* learnings.md, metrics.json 외 파일 수정
* policy-updater 자동 실행
* 개선안 직접 적용
* 기존 learnings 항목 삭제 또는 덮어쓰기

---

### 4.8 policy-updater

policy-updater는 누적된 learnings와 metrics를 분석해 에이전트·정책 파일 개정안을 생성하고, 사용자 승인 후 적용하는 역할을 맡는다.

#### subagent 설정

* `model: sonnet` — 개정안 생성에 충분한 추론 능력 필요
* `memory: project`
* `tools: Read, Write, Edit, Glob, Grep`
* `maxTurns: 30`

#### 책임

* learnings.md, metrics.json 전체 읽기
* 개선 필요 항목 목록 작성 (근거, 대상 파일, 판단 명시)
* 업데이트 우선 원칙 적용: 기존 파일로 해결 가능하면 반드시 업데이트 선택
* 개정안을 우선순위 순으로 사용자에게 제시 (5개 이내, diff 형태)
* 사용자 OK 후에만 파일에 적용

#### 신규 파일 생성 조건 (모두 충족해야 함)

* 동일 패턴이 learnings에 3회 이상 기록됨
* 기존 `.claude/agents/`, `.claude/hooks/`, `scripts/`, `CLAUDE.md` 중 어느 파일로도 커버 불가
* 생성 후 독립적으로 삭제 가능한 단위

#### 산출물

* 개정안 diff (파일 적용 전)
* 사용자 승인 후 수정된 에이전트/정책 파일

#### 금지

* 사용자 승인 없이 파일 적용
* 신규 파일 생성 조건 미충족 시 신규 생성
* CLAUDE.md 직접 수정 (diff 제안만)
* learnings 없이 추측으로 개정안 생성

---

## 5. Phase별 로드맵

### Phase 1. Core-included Repo Template 구축

#### 5.1 목표

Claude Code가 바로 앱 생성 플로우를 시작할 수 있는 실행형 repo template를 구축한다.

#### 5.2 범위

이 단계에서는 다음을 포함한다.

* `CLAUDE.md`
* planner
* sprint-builder
* evaluator
* reviewer
* integration-fixer
* core hooks
* state files
* init/test/evaluation scripts
* 최소 QA gate
* 최소 1개 profile
* app 생성 진입점

이 단계에서는 다음을 포함하지 않는다.

* 조직 전역 plugin 배포
* 다수 스택 최적화
* 복잡한 MCP 번들
* 대규모 eval 인프라

#### 5.3 주요 설계 요구사항

##### CLAUDE.md

* 200줄 이내를 목표로 유지한다.
* 항상 필요한 규칙만 포함한다.
* 세부 규칙은 import로 분리한다.
* 구현 전 상태 파일 확인을 강제한다.
* 계획, 평가, 리뷰의 역할 구분을 명시한다.

##### planner

* 사용자 요구사항을 제품 스펙과 feature backlog로 변환한다.
* 과도한 기술 결정은 피한다.
* acceptance criteria 중심으로 산출한다.

##### sprint-builder

* 한 번에 하나의 sprint만 구현한다.
* 구현 전에 sprint contract를 작성한다.
* 핵심 기능 stub를 남긴 채 완료 처리하지 않는다.

##### evaluator

* acceptance criteria와 contract를 기준으로만 판정한다.
* smoke, unit, e2e, 핵심 플로우 결과를 확인한다.
* 결과를 evaluation report에 기록한다.

##### reviewer

* 결과물이 pass여도 품질 비평을 수행한다.
* UX, 구조, 기술 부채, 유지보수성 관점에서 검토한다.
* 개선 우선순위를 제안한다.

##### hooks

* 세션 시작 시 상태 파일 요약 로드
* 위험 명령 차단
* 편집 후 자동 포맷/빠른 테스트
* 서브에이전트 종료 시 산출물 요약 저장
* 세션 종료 시 progress 기록

##### state files

* 세션 재개에 필요한 정보가 충분해야 한다.
* 사람이 읽을 수 있어야 한다.
* 다음 세션 첫 행동을 남겨야 한다.
* 평가와 리뷰 결과는 별도 파일로 분리한다.

#### 5.4 산출물

* 실행형 repo template
* 하네스 코어 문서
* 최소 1개 앱 생성 시나리오
* core scripts
* core state schema

#### 5.5 완료 기준

* 저장소 복제 후 바로 Claude Code로 앱 생성 시작 가능
* 짧은 요구사항으로 product spec 생성 가능
* 최소 1개 sprint 구현 가능
* evaluator가 최소 게이트로 pass/fail 판정 가능
* reviewer가 품질 개선 포인트를 기록 가능
* 세션 종료 후 재개 가능

---

### Phase 2. 실사용 기반 검증

#### 6.1 목표

구조의 완성도가 아니라 실제 앱 생성 성능을 검증한다.

#### 6.2 원칙

* 태스크 기반으로 평가한다.
* 실제 사용자 플로우 중심으로 본다.
* pass/fail 기준을 사전에 정의한다.
* 회귀를 추적한다.
* 수동 개입량을 함께 기록한다.
* 평가와 리뷰 결과를 혼합하지 않는다.

#### 6.3 평가 대상

* planner 품질
* sprint-builder 품질
* evaluator 판정 신뢰성
* reviewer 개선 제안 유효성
* 상태 재개 신뢰성
* 전체 반복 비용

#### 6.4 평가 절차

1. 대표 앱 생성 태스크 세트 구성
2. 각 태스크에 요구사항 입력
3. 하네스로 앱 생성 수행
4. 앱 구동 및 핵심 플로우 검증
5. evaluator가 pass/fail 기록
6. reviewer가 개선 포인트 기록
7. 실패 유형 분류
8. 개선 backlog 반영

#### 6.5 기록해야 할 지표

* 앱 생성 완료 여부
* 첫 실행 성공 여부
* 핵심 플로우 통과 여부
* stub 또는 placeholder 잔존 여부
* 수동 수정 횟수
* 평균 반복 횟수
* 실패 유형
* 회귀 발생 여부
* 리뷰 개선 포인트 반영률

#### 6.6 산출물

* golden task set
* evaluation rubric
* test result summary
* failure taxonomy
* review theme summary
* improvement backlog

#### 6.7 완료 기준

* 최소 10개 수준의 평가 과제 결과 확보
* 실패 패턴이 분류됨
* 하네스가 강한 앱 유형과 약한 앱 유형이 식별됨
* 운영성 강화 우선순위가 도출됨
* 리뷰어가 반복적으로 지적하는 품질 문제가 정리됨

---

### Phase 3. 운영성 강화

#### 7.1 목표

하네스를 지속 운영 가능한 상태로 만든다.

#### 7.2 강화 대상

* resumability
* progress logging
* failure analysis
* guardrails
* post-edit validation
* evaluation automation
* review traceability
* handoff quality

#### 7.3 핵심 설계 원칙

* 운영 상태는 파일로 남긴다.
* 자주 반복되는 절차는 hook으로 자동화한다.
* 복구 방법을 항상 기록한다.
* 세션 종료 시 다음 액션을 남긴다.
* 판단이 필요한 작업과 결정론적 작업을 분리한다.
* 평가 로그와 리뷰 로그를 분리한다.

#### 7.4 운영 훅 정책

##### SessionStart

* 상태 파일 존재 여부 확인
* 최근 progress 요약
* 현재 sprint 상태 판별
* 미해결 blocker 노출
* 이전 evaluation/review 결과 요약

##### PreToolUse

* 위험 명령 차단
* 프로젝트 루트 밖 쓰기 방지
* destructive action 검토

##### PostToolUse

* 코드 변경 후 포맷 실행
* 타입체크 또는 빠른 smoke 실행
* 실패 시 결과 기록

##### SubagentStop

* planner 산출물 요약 저장
* evaluator 판정 결과 저장 (`evaluation-report.md` 갱신 확인)
* reviewer 개선 포인트 저장 (`review-notes.md` 갱신 확인)
* retrospective learnings/metrics 갱신 확인
* reviewer 완료 시 retrospective 실행 안내
* unresolved issues 기록

##### Stop

* progress 저장
* 다음 액션 저장
* 현재 리스크 저장

#### 7.5 slash commands

* `/improve` — `.claude/commands/improve.md`에 정의. learnings가 active 상태일 때만 policy-updater 실행. 개정안은 diff 형태로 사용자 승인 후 적용.

#### 7.6 운영 문서화 항목

* incident log
* failure recovery guide
* guardrail policy
* evaluation runbook
* review runbook
* resume runbook

#### 7.7 완료 기준

* 세션 재개 성공률 향상
* 수동 점검 의존도 감소
* 위험 작업 사고 감소
* 실패 원인 추적 가능
* 장기 실행 시 상태 유실 감소
* 리뷰 결과가 누적 관리됨

---

### Phase 4. Core/Profile 분리

#### 8.1 목표

검증된 공통 하네스와 가변적인 스택/앱 유형 요소를 분리한다.

#### 8.2 분리 원칙

* 코어는 앱 유형에 독립적이어야 한다.
* profile은 stack/app-type 차이만 표현한다.
* 코어와 profile의 인터페이스를 명확히 한다.
* 공통 평가 규격은 유지하되 실행 구현은 profile별로 허용한다.
* 리뷰 체크리스트는 코어에 두고, stack 특화 체크는 profile로 둔다.

#### 8.3 코어에 남길 것

* 전역 규칙
* subagent 프레임
* hook 정책
* state schema
* sprint contract 형식
* common evaluation interface
* common review framework
* common docs

#### 8.4 profile로 분리할 것

* 프레임워크 초기화 방식
* dev server 기동 규칙
* test command 구현
* environment assumptions
* deployment scaffolding
* app-type generation guidance
* stack-specific review checklist

#### 8.5 profile 설계 기준

* 신규 profile 추가 비용이 낮아야 한다.
* profile 간 규칙 충돌을 최소화한다.
* 코어 수정 없이 profile을 교체 가능해야 한다.

#### 8.6 산출물

* harness-core specification
* profile interface specification
* supported profile list
* profile selection guide

#### 8.7 완료 기준

* 코어 변경 없이 여러 앱 유형 지원 가능
* stack 규칙 충돌 감소
* 유지보수 비용 감소
* 신규 profile 확장 가능

---

### Phase 5. Plugin 추출 및 팀 배포

#### 9.1 목표

검증된 공통 하네스를 Claude Code plugin으로 추출해 팀 단위로 배포한다.

#### 9.2 plugin 추출 기준

* 여러 저장소에서 반복 사용됨
* 프로젝트 특화 내용과 분리 가능함
* 버전 관리 가치가 있음
* 운영 안정성이 검증됨
* planner/evaluator/reviewer 역할 분리가 안정적으로 유지됨

#### 9.3 plugin에 포함할 것

* 공통 subagents
* 공통 hooks
* 공통 skills
* 공통 rules
* optional MCP integration definitions

#### 9.4 repo template에 남길 것

* 실제 앱 코드
* 프로젝트별 profile
* 환경 변수 예시
* 프로젝트 특화 smoke/e2e
* 프로젝트 특화 배포 구성

#### 9.5 배포 요구사항

* 설치 방법 문서화
* 버전 정책 수립
* 변경 이력 관리
* 호환 범위 명시
* 업그레이드 절차 정의

#### 9.6 완료 기준

* plugin 설치만으로 공통 하네스 사용 가능
* repo template 경량화
* 공통 하네스 버전 관리 가능
* 팀 재사용성 확보

---

## 6. 상태 파일 설계

### 10.1 상태 레이어 구조

상태는 두 레이어로 관리한다.

**레이어 1 — subagent persistent memory (자동 누적)**

각 subagent는 `memory: project`를 선언해 `.claude/agent-memory/<agent-name>/` 에 상태를 자동 누적한다. 에이전트가 실행될 때마다 이전 실행 결과, 발견한 패턴, 누적 인사이트가 쌓인다. 세션이 재개될 때 Claude Code가 MEMORY.md 상단 200줄을 자동으로 컨텍스트에 주입한다.

| subagent | memory 경로 | 누적 내용 |
|---|---|---|
| planner | `.claude/agent-memory/planner/` | 요구사항 해석 패턴, 반복 실수, 범위 판단 기준 |
| sprint-builder | `.claude/agent-memory/sprint-builder/` | 구현 중 발견한 기술 결정, blocker 패턴 |
| evaluator | `.claude/agent-memory/evaluator/` | 판정 이력, 반복되는 실패 유형 |
| reviewer | `.claude/agent-memory/reviewer/` | 누적 품질 지적, 개선 포인트 이력 |
| integration-fixer | `.claude/agent-memory/integration-fixer/` | 복구 레시피, 환경별 known issues |
| retrospective | `.claude/agent-memory/retrospective/` | sprint별 지표 패턴, 반복 실패 유형 |
| policy-updater | `.claude/agent-memory/policy-updater/` | 개정 이력, 적용 효과 |

**레이어 2 — `.claude-state/` 명시적 상태 파일 (사람이 읽고 편집)**

sprint 범위, 계약, 판정 결과처럼 에이전트 간 공유가 필요하고 사람이 직접 확인/편집해야 하는 상태는 `.claude-state/` 에 명시적으로 유지한다.

### 10.2 필수 상태 파일

* `product-spec.md`
* `feature-list.json`
* `sprint-plan.md`
* `sprint-contract.md` — **planner가 작성, sprint-builder가 준수, evaluator가 기준으로 사용**
* `evaluation-report.md`
* `review-notes.md`
* `decisions.md`
* `claude-progress.txt`
* `backlog.md`
* `learnings.md` — retrospective가 sprint마다 append. policy-updater의 입력
* `metrics.json` — eval pass율, blocker 유형, 평균 턴 수 등 정량 지표 누적

### 10.3 상태 파일 공통 원칙

* 한 파일은 하나의 책임만 가진다.
* 최신 상태가 파일 상단에 드러나야 한다.
* 다음 세션 시작에 필요한 정보가 포함되어야 한다.
* 사람이 직접 편집해도 이해 가능해야 한다.
* 평가 파일과 리뷰 파일은 합치지 않는다.
* subagent memory는 에이전트가 관리하고, `.claude-state/`는 사람과 에이전트가 함께 읽는다.

### 10.4 상태 파일 책임

#### product-spec.md

* 제품 목표
* 핵심 사용자
* 핵심 플로우
* 범위
* 제외 범위
* 비기능 요구사항

#### feature-list.json

* 기능 ID
* 우선순위
* 현재 상태
* 의존성
* acceptance criteria
* verification linkage — 기능과 관련 파일 경로를 매핑. 에이전트가 탐색 범위를 좁히는 데 사용

#### sprint-plan.md

* feature ordering
* sprint sequencing
* 예상 리스크
* 의존성 고려

#### sprint-contract.md

* 작성 주체: planner
* 이번 sprint 범위
* done 정의
* 제외 항목
* 검증 계획
* blocker

#### evaluation-report.md

* 실행 환경
* 검증 항목
* pass/fail
* blocker
* regression
* 판정 근거

#### review-notes.md

* UX critique
* structure critique
* maintainability concerns
* improvement recommendations
* review priority (severity / priority 구분)

#### decisions.md

* 주요 설계 선택
* 선택 이유
* 대안
* 영향 범위

#### claude-progress.txt

* 최근 수행 내용
* 현재 상태
* blocker
* 다음 액션

#### backlog.md

* 미완료 항목
* 우선순위 재조정
* 추후 고려 사항

#### learnings.md

* 작성 주체: retrospective
* sprint마다 하단 append (삭제 없음)
* 형식: `## <sprint_id> — <date>\n- eval: ...\n- blocker: ...\n- 턴 수: ...\n- 패턴: ...`
* policy-updater가 개정 근거로 사용
* `status: active` 헤더로 누적 여부 표시

#### metrics.json

* 작성 주체: collect-metrics.sh (retrospective가 호출)
* sprints 배열에 sprint별 지표 누적
* 포함 항목: sprint_id, date, eval_result, blocker_count, blocker_types, total_turns, fix_iterations
* summary 섹션: total_sprints, pass_rate, avg_blockers_per_sprint, avg_turns, repeated_blocker_types
* check-thresholds.sh가 이 파일을 읽어 임계점 판단

---

## 7. 에이전트 운영 규칙

### 11.0 Context Window 절약 원칙

앱 규모가 커질수록 전체 코드를 main context에 직접 올리면 Context Window가 빠르게 소진된다. 모든 에이전트는 다음 원칙을 따른다.

**코드 탐색은 반드시 Explore subagent를 통한다**
코드베이스 탐색이 필요할 때 main context에서 직접 파일을 읽지 않는다. Explore subagent(Haiku 모델, 읽기 전용)에 위임하면 탐색 결과가 subagent context에 격리되고 main context에는 요약만 반환된다.

**파악한 구조는 memory에 누적한다**
이전 sprint에서 파악한 파일 구조, 모듈 경계, 의존 관계는 `memory: project`에 기록한다. 다음 실행 시 재탐색 없이 memory에서 읽는다.

**탐색 범위를 좁히는 링크를 유지한다**
`feature-list.json`의 `verification linkage` 필드에 기능과 관련 파일 경로를 매핑한다. 에이전트가 특정 기능을 다룰 때 전체를 탐색하지 않고 링크를 따라 해당 파일만 읽는다.

**raw 코드를 직접 context에 올리지 않는다**
파일 전체를 읽어야 할 경우 필요한 섹션만 읽는다. 관련 없는 파일을 "혹시 몰라" 읽는 행위는 금지한다.

---

### 11.1 planner 운영 규칙

* 항상 요구사항을 먼저 해석한다.
* 제품 관점 산출물을 먼저 만든다.
* 구현 가능성과 범위를 고려한다.
* 다음 단계가 builder로 자연스럽게 이어지도록 만든다.
* `feature-list.json` 작성 시 `verification linkage`에 관련 파일 경로를 명시한다.

### 11.2 sprint-builder 운영 규칙

* contract가 없으면 큰 구현을 시작하지 않는다.
* 범위를 넘기지 않는다.
* 구현 중 발견된 리스크는 상태 파일에 남긴다.
* 완료 선언 전에 evaluator 단계로 넘긴다.
* 코드 탐색이 필요하면 Explore subagent에 위임하고 main context에 직접 읽지 않는다.
* 파악한 파일 구조와 의존 관계는 memory에 기록해 다음 sprint에서 재탐색을 방지한다.

### 11.3 evaluator 운영 규칙

* 계약된 acceptance criteria만 기준으로 판정한다.
* 명시적 pass/fail을 남긴다.
* 판정 근거를 남긴다.
* 개선 제안은 부가 메모로만 남기고 본업은 판정으로 유지한다.
* 테스트 실행 결과는 요약만 context에 올린다. 전체 로그를 직접 읽지 않는다.

### 11.4 reviewer 운영 규칙

* 구현 결과를 비평하되 심판 역할을 하지 않는다.
* 장기 유지보수성을 우선적으로 본다.
* 개선 포인트를 우선순위로 정리한다.
* cosmetic 문제와 구조 문제를 구분한다.
* 코드 탐색은 Explore subagent에 위임하고, 반환된 요약을 기반으로 비평한다.

### 11.5 integration-fixer 운영 규칙

* 기능 확대가 아니라 복구에 집중한다.
* 재현 가능한 문제를 우선 해결한다.
* 복구 후 재검증으로 이어지게 만든다.
* 복구 과정에서 파악한 환경 특이사항과 known issues는 memory에 기록한다.

---

## 8. Hook 설계 기준

### 12.1 공통 원칙

* 반복 작업은 hook으로 자동화한다.
* hook은 짧고 결정론적으로 유지한다. 판단이 필요한 로직은 `type: prompt` 또는 `type: agent` hook으로 분리한다.
* 실패 시 로그를 남기고 복구 경로를 제시한다.
* hook 타입은 목적에 맞게 선택한다: 쉘 실행은 `command`, 외부 시스템 연동은 `http`, 단순 판단은 `prompt`, 조건 검증은 `agent`.
* exit code 2는 실행 차단, exit code 0은 허용, 그 외는 non-blocking 경고다.

### 12.2 필수 hook 그룹

#### SessionStart (matcher: startup | resume)

* 상태 파일 스캔 및 최근 progress 표시
* 현재 sprint 상태 판별
* 미해결 blocker 노출
* 이전 evaluation/review 결과 요약
* `additionalContext`로 컨텍스트를 Claude에 주입

#### UserPromptSubmit

* 승인되지 않은 범위 요청 감지 및 경고
* sprint contract 밖 작업 지시 차단
* 민감 정보(비밀번호, 키) 포함 여부 검사

#### PreToolUse (matcher: Bash)

* destructive 명령 차단 (`rm -rf`, `DROP TABLE` 등) — exit code 2로 즉시 차단
* 프로젝트 루트 밖 쓰기 방지
* `permissionDecision: ask`로 고위험 명령을 사용자에게 위임

#### PostToolUse (matcher: Write | Edit)

* 변경 후 포맷 실행
* 변경 후 빠른 타입체크 또는 lint 실행
* 실패 시 `decision: block`으로 다음 단계 차단 및 오류 메시지 주입

#### PostToolUseFailure

* 도구 실패 원인 분석 메시지를 `additionalContext`로 Claude에 제공
* 반복 실패 패턴 로그 기록

#### TaskCompleted (evaluator / reviewer / retrospective subagent 전용)

* evaluator 종료 전 pass/fail 판정 파일 존재 여부 확인
* reviewer 종료 전 review-notes.md 갱신 여부 확인
* retrospective 종료 전 learnings.md / metrics.json 갱신 여부 확인
* 미충족 시 exit code 2로 완료 차단

#### TeammateIdle (sprint-builder)

* sprint-builder 종료 전 smoke test 통과 여부 확인
* 핵심 경로에 stub/placeholder 잔존 여부 스캔

#### TeammateIdle (reviewer)

* reviewer 완료 시 retrospective 에이전트 실행을 Claude에게 알림
* `additionalContext`로 "retrospective를 실행하세요" 메시지 주입
* 미통과 시 exit code 2로 종료 차단

#### SubagentStop

* planner/evaluator/reviewer 산출물 요약을 `.claude-state/`에 저장
* unresolved blocker 기록
* subagent memory 갱신 여부 확인

#### Stop

* `claude-progress.txt` 갱신 (현재 상태, blocker, 다음 액션)
* open risk 저장
* 미완료 sprint contract 항목 backlog 반영

---

## 9. 평가와 리뷰 정책

### 13.1 평가와 리뷰는 별도 단계다

평가는 합격/불합격 판정이다. 리뷰는 품질 비평과 개선 제안이다. 둘을 하나의 문서나 하나의 에이전트에 섞지 않는다.

### 13.2 평가 계층

* format
* lint/typecheck
* smoke
* unit
* e2e
* manual scenario validation when needed

### 13.3 평가 기준

* 핵심 기능 작동
* 주요 사용자 플로우 성공
* 새로 추가한 기능이 기존 기능을 깨지 않음
* 환경 재기동 시 기본 기능 유지
* placeholder나 stub가 핵심 경로에 남지 않음

### 13.4 리뷰 기준

* UX clarity
* architecture consistency
* maintainability
* technical debt
* unnecessary complexity
* future extensibility

### 13.5 운영 원칙

* evaluator 결과는 완료 여부 결정에 사용한다.
* reviewer 결과는 품질 개선 backlog에 사용한다.
* pass 이후에도 review로 추가 작업이 나올 수 있다.
* review 이슈는 severity와 priority로 관리한다.

---

## 10. MCP와 외부 도구 정책

### 14.1 기본 원칙

기본 하네스는 MCP 없이도 동작해야 한다. MCP는 품질 향상용 확장이다.

### 14.2 우선순위

1. Playwright 기반 브라우저 검증
2. Browser/Web research
3. DB inspection
4. optional deployment or design integrations

### 14.3 적용 원칙

* 평가 가치가 높은 도구부터 도입한다.
* tool 수를 무작정 늘리지 않는다.
* 사용 빈도와 검증 가치를 기준으로 채택한다.
* 평가용 MCP와 리뷰용 MCP의 목적을 구분한다.

---

## 11. 구현 우선순위

### 우선순위 1 — 하네스 코어

* `CLAUDE.md` — 상태 파일 우선 읽기, 단계 전환 규칙, 역할 구분 명시
* 각 subagent `.md` 파일 — frontmatter(model/memory/tools/maxTurns) + system prompt
* `.claude/settings.json` — hook 이벤트와 스크립트 연결
* `.claude-state/` 초기 템플릿 파일
* `scripts/evaluation-gate` — stub 잔존 검사 포함, profile 독립 구현
* `scripts/smoke`, `scripts/unit`, `scripts/e2e` — profile 미설정 시 skip 처리

### 우선순위 2 — 자동화 강화

* SessionStart hook — 상태 파일 스캔, progress 요약, 14.1 판단 규칙 실행
* TeammateIdle hook 스크립트 — sprint-builder 종료 전 smoke + stub 검사 강제
* TaskCompleted hook 스크립트 — evaluator/reviewer/retrospective 산출물 파일 갱신 확인
* PostToolUse hook 스크립트 — 포맷/lint 자동 실행
* 기본 golden tasks
* collect-metrics.sh — evaluation-report에서 지표 추출 → metrics.json 갱신
* check-thresholds.sh — 임계점 감지 (3회 연속 fail, pass율 <50%, 동일 blocker 3회, 턴 초과 3회)

### 우선순위 3 — 운영성

* e2e 강화
* failure taxonomy
* integration-fixer
* review severity 체계
* UserPromptSubmit hook — 범위 이탈 요청 감지

### 우선순위 4 — 확장

* profile 작성 가이드 기반 첫 번째 profile (사용자가 선택한 스택)
* MCP 확장
* plugin 추출

---

## 12. 성공 판정 기준

본 하네스는 다음 조건을 만족해야 성공으로 본다.

* 짧은 요구사항으로 앱 생성이 시작된다.
* 계획 → 구현 → 평가 → 리뷰 → 수정의 루프가 작동한다.
* 세션 재개가 가능하다.
* 최소 eval 세트에서 반복 가능한 결과를 낸다.
* 평가와 리뷰가 혼합되지 않는다.
* 공통부와 profile이 분리 가능하다.
* 공통부를 plugin으로 추출할 수 있는 구조를 가진다.

---

## 13. 금지사항

* `CLAUDE.md`를 지나치게 비대하게 만들지 않는다.
* sprint contract 없이 바로 큰 변경을 하지 않는다.
* 핵심 기능 stub를 완료로 처리하지 않는다.
* 상태를 대화에만 의존하지 않는다.
* evaluator와 reviewer를 같은 역할로 취급하지 않는다.
* QA 없이 완료 선언하지 않는다.
* plugin을 너무 이른 시점에 도입하지 않는다.
* 코어와 profile을 섞지 않는다.

---

## 14. 단계 전환 규칙

각 단계의 전환은 상태 파일을 기준으로 판단한다. Claude Code는 매 세션 시작 시 아래 규칙을 순서대로 적용해 현재 위치를 판단하고 다음 단계를 자동으로 결정한다. 사용자가 명시적으로 다른 지시를 하지 않는 한 이 규칙을 따른다.

### 14.1 상태 판단 규칙

| 조건 | 다음 단계 |
|---|---|
| `product-spec.md` 없음 | planner 실행 |
| `sprint-contract.md` 없음 또는 status: draft | planner → sprint contract 작성 후 사용자 승인 요청 |
| `sprint-contract.md` status: approved, `evaluation-report.md` 없음 | sprint-builder 실행 |
| `evaluation-report.md` status: pending | evaluator 실행 |
| `evaluation-report.md` status: fail | blocker 확인 → integration-fixer 또는 수정 sprint |
| `evaluation-report.md` status: pass, `review-notes.md` 없음 | reviewer 실행 |
| `review-notes.md` 작성 완료 | retrospective 에이전트 실행 |
| retrospective 완료, 임계점 미도달 | 사용자에게 다음 sprint 진행 여부 확인 |
| retrospective 완료, 임계점 도달 | 사용자에게 `/improve` 실행 권장 후 다음 sprint 진행 여부 확인 |
| `/improve` 명령 | policy-updater 실행 → 개정안 제시 → 사용자 승인 → 적용 |

### 14.2 사용자 승인이 필요한 전환

자동 전환 중 다음 세 시점에서는 반드시 멈추고 사용자 확인을 받는다.

* **planner 완료 후**: sprint-contract 초안을 사용자에게 제시하고 범위 승인을 받는다. 승인 없이 sprint-builder를 시작하지 않는다.
* **리뷰 완료 후**: retrospective를 실행하고 다음 sprint 범위를 제안하며 진행 여부를 확인한다. 자동으로 다음 sprint를 시작하지 않는다.
* **policy-updater 개정안 제시 후**: 개정안 diff를 사용자에게 제시하고 OK를 받는다. 승인 없이 파일에 적용하지 않는다.

### 14.3 실행 순서

1. `CLAUDE.md`와 `.claude-state/`를 읽고 14.1 규칙으로 현재 위치를 판단한다.
2. 상태가 없으면 planner → product spec, feature backlog, sprint plan, sprint contract 초안 작성.
3. sprint contract를 사용자에게 제시하고 승인을 받는다.
4. sprint-builder가 승인된 sprint 범위를 구현한다.
5. `scripts/smoke`를 실행하고 결과를 `evaluation-report.md`에 기록한다.
6. evaluator가 acceptance criteria와 contract 기준으로 pass/fail을 판정한다.
7. reviewer가 품질 비평과 개선 제안을 `review-notes.md`에 기록한다.
8. retrospective 에이전트가 지표를 수집하고 `learnings.md` / `metrics.json`을 갱신한다.
9. `check-thresholds.sh`로 임계점 도달 여부를 확인한다. 도달 시 사용자에게 `/improve` 권장.
10. `claude-progress.txt`에 현재 상태와 다음 액션을 남긴다.
11. blocker가 있으면 integration-fixer 또는 다음 수정 sprint로 진행한다.
12. 사용자에게 다음 sprint 진행 여부를 확인한다.

---

## 15. 평가 자동화 설계

evaluator가 "테스트를 확인한다"는 원칙만으로는 실제 검증이 보장되지 않는다. 평가는 스크립트가 실행되어야 완성된다.

### 15.1 profile 독립 원칙

하네스 코어는 profile 없이도 구조적으로 완결된다. `scripts/`의 각 스크립트는 **인터페이스만 정의**하고, 실제 명령어는 profile이 채운다. profile이 없으면 스크립트는 "profile이 설정되지 않았음"을 출력하고 exit 0으로 종료한다(차단하지 않음). 이를 통해 범용 템플릿으로서의 성격을 유지하면서 평가 구조는 강제한다.

profile 스크립트는 **planner가 요구사항에서 스택을 판단해 자동 생성**한다. 사람이 수동으로 작성할 수도 있으며, 이미 존재하는 파일은 덮어쓰지 않는다.

```
scripts/
  smoke         ← profile이 구현, 없으면 skip
  unit          ← profile이 구현, 없으면 skip
  e2e           ← profile이 구현, 없으면 skip
  evaluation-gate  ← 코어가 구현, 위 결과를 종합해 pass/fail 판정
  dev-up        ← profile이 구현, 없으면 안내 메시지 출력
```

### 15.2 evaluation-gate 동작

`scripts/evaluation-gate`는 코어가 구현하는 유일한 평가 스크립트다. smoke/unit/e2e 결과 파일을 읽어 종합 pass/fail을 판정하고 `evaluation-report.md`에 기록한다. profile 의존성이 없다.

```
evaluation-gate 실행 흐름:
  1. scripts/smoke 실행 → 결과 저장
  2. scripts/unit 실행 → 결과 저장
  3. 결과 파일 읽기
  4. acceptance criteria 대조
  5. evaluation-report.md 기록 (status: pass | fail)
  6. blocker 목록 출력
```

### 15.3 stub 잔존 검사

profile 유무와 관계없이 코어가 직접 실행할 수 있는 검사다. `scripts/evaluation-gate`에 포함된다.

* 핵심 경로 파일에서 `TODO`, `FIXME`, `stub`, `placeholder`, `not implemented` 패턴 탐색
* 발견 시 evaluation-report에 blocker로 기록
* sprint contract의 scope에 명시된 파일만 검사 대상으로 한정

### 15.4 profile 작성 가이드

profile을 추가하는 사용자는 다음 인터페이스를 구현한다.

```
profiles/<stack-name>/
  scripts/
    smoke     ← 앱이 기동하는지 확인 (exit 0 = pass, exit 1 = fail)
    unit      ← 단위 테스트 실행 (exit 0 = pass, exit 1 = fail)
    e2e       ← e2e 테스트 실행 (exit 0 = pass, exit 1 = fail)
    dev-up    ← 개발 서버 기동
  profile.md  ← 스택 설명, 환경 요구사항, 특이사항
```

exit code만 맞추면 어떤 스택도 코어와 연결된다.

---

## 16. 자기개선 루프

### 16.1 루프 구조

기존 루프가 `planner → sprint-builder → evaluator → reviewer`였다면, 현재 루프는 다음과 같다.

```
planner → sprint-builder → evaluator → reviewer
                                          ↓
                                    retrospective
                                          ↓
                              check-thresholds (자동)
                                    ↓            ↓
                              임계점 도달    임계점 미도달
                                    ↓            ↓
                           /improve 권장   다음 sprint
                                    ↓
                            policy-updater
                                    ↓
                      개정안 제시 → 사용자 승인 → 적용
```

### 16.2 임계점 정의

| 지표 | 임계점 |
|---|---|
| eval pass율 | 3회 연속 fail 또는 전체 pass율 < 50% (최소 4회 이상) |
| 동일 blocker 유형 | 3회 이상 반복 |
| sprint 평균 턴 수 | 60턴 초과 3회 연속 |

### 16.3 자기개선 정책

* **자동**: 루프 종료 → retrospective → 지표 누적 → 임계점 감지. 사람 개입 없이 실행.
* **알림**: 임계점 도달 시 "[WARNING] /improve 실행 권장" 메시지만 출력. 자동 적용하지 않는다.
* **승인 필수**: policy-updater가 개정안 diff를 제시하고, 사용자 OK 후에만 파일에 적용한다.
* **업데이트 우선**: 기존 파일 수정으로 해결 가능하면 신규 파일을 만들지 않는다.
* **신규 파일 최소**: 동일 패턴 3회 이상 + 기존 파일 커버 불가 + 독립 삭제 가능 단위 — 세 조건 모두 충족 시에만 신규 생성.

### 16.4 스크립트

| 스크립트 | 역할 |
|---|---|
| `scripts/collect-metrics.sh <sprint_id>` | evaluation-report에서 지표 추출 → metrics.json 갱신 |
| `scripts/check-thresholds.sh` | metrics.json 읽어 임계점 판단. exit 1이면 임계점 도달 |
| `scripts/check-thresholds.sh --summary` | 한 줄 요약 출력 (session-start에서 컨텍스트 주입용) |

### 16.5 learnings 형식

```
## <sprint_id> — <date>
- eval: pass | fail
- blocker: <유형>
- 턴 수: <수>
- 패턴: <관찰>
```

항목당 5줄 이내. 파일 하단에만 append. 기존 항목을 삭제하거나 덮어쓰지 않는다.

---
