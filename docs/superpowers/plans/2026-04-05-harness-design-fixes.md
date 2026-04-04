# Harness Design Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 하네스의 13개 설계 결함(CRITICAL 4건, MAJOR 6건, MINOR 3건)을 수정하여 의존성 체인, 상태 추적, 훅 안정성을 보강한다.

**Architecture:** 각 수정은 독립적으로 에이전트 파일(.claude/agents/*.md), 훅 스크립트(.claude/hooks/*.sh), 상태 파일 규약, harness-reference.md에 가해진다. 코드 생성 없이 에이전트 지시문과 쉘 스크립트만 수정한다.

**Tech Stack:** Bash, Python(인라인), Markdown 에이전트 정의

---

## 수정 대상 파일 맵

| 문제 # | 파일 | 변경 유형 |
|--------|------|---------|
| #1 병렬 git 충돌 | `.claude/agents/sprint-builder.md` | 병렬 그룹 커밋 규칙 추가 |
| #2 루프 카운터 없음 | `.claude/agents/sprint-builder.md` | fix_attempt 기록 규칙 추가 |
| #3 common-module 실패 경로 | `.claude/agents/sprint-builder.md`, `common-module-writer.md` | 실패 처리 분기 추가 |
| #4 remaining_sprints 판독 위치 | `.claude/hooks/session-start.sh`, `.claude/agents/retrospective.md` | 판독 위치를 feature-list.json으로 변경 |
| #5 check-output 에이전트 판별 | `.claude/hooks/check-output.sh` | 에이전트 이름 판별 강화 |
| #6 이중 트리거 방지 | `.claude/agents/reviewer.md` | retrospective 직접 호출 금지 명시 |
| #7 stub 검사 오탐 | `.claude/hooks/check-smoke.sh` | 테스트 파일 제외, 주석 제외 필터 추가 |
| #8 fix_attempt 기록 위치 | `.claude/agents/sprint-builder.md`, `integration-fixer.md` | sprint-contract.md에 fix_attempt 필드 명시 |
| #9 feature_id 동기화 | `.claude/agents/usecase-writer.md`, `planner.md` | planner 먼저 feature-list.json 생성 후 usecase-writer 실행 순서 명시 |
| #10 policy-updater 자동 트리거 | `.claude/agents/retrospective.md` | improve_needed:true 시 policy-updater 직접 실행 규칙 추가 |
| #11 스크립트 이중 관리 | `.claude/agents/planner.md` | 복사 대신 symlink 또는 참조 경로 통일 |
| #12 .claude-state 초기화 | `.claude/agents/planner.md` | 디렉토리 생성 명시 |
| #13 dataflow/usecase 병렬 안전성 | `.claude/agents/planner.md`, `harness-reference.md` | 순서 명시 (dataflow 완료 후 usecase 실행) |

---

## Task 1: 병렬 implementer 실행 시 git 충돌 방지 (#1)

**Files:**
- Modify: `.claude/agents/sprint-builder.md` — 병렬 그룹별 커밋 규칙 추가

- [ ] **Step 1: sprint-builder.md의 병렬 실행 섹션 읽기**

  파일을 열어 `parallel_safe` 처리 로직 위치 파악.

- [ ] **Step 2: 병렬 그룹 커밋 규칙 삽입**

  `parallel_safe: true` implementer를 실행하는 단계 바로 뒤에 다음 규칙을 추가:

  ```
  - 병렬로 실행된 각 implementer는 자신이 수정한 파일만 `git add` 하고 feature 단위로 커밋한다.
    커밋 메시지 형식: `feat(<feature_id>): implement <feature_name>`
  - 모든 병렬 implementer가 완료된 후, sprint-builder는 `git status`로 uncommitted 파일이
    없는지 확인한다. 남은 파일이 있으면 BLOCKER 처리한다.
  - code-reviewer는 병렬 그룹 전체가 커밋된 이후에만 실행한다.
    `git diff HEAD~<N>..HEAD` (N = 병렬 그룹 feature 수)로 전체 변경을 검토한다.
  ```

- [ ] **Step 3: harness-reference.md 흐름도 업데이트**

  흐름도의 implementer(병렬) 단계 설명에 "(각 feature 완료 시 즉시 커밋)" 주석 추가.

---

## Task 2: code-reviewer 루프 카운터 추적 (#2)

**Files:**
- Modify: `.claude/agents/sprint-builder.md` — fix_attempt 카운터 기록 규칙
- Modify: `docs/harness-reference.md` — 상태 파일 목록에 fix_attempt 필드 추가

- [ ] **Step 1: sprint-builder.md의 code-reviewer 루프 섹션 읽기**

  "2회 루프" 관련 문장 위치를 파악한다.

- [ ] **Step 2: 루프 카운터 기록 규칙 추가**

  code-reviewer 루프 단계를 아래와 같이 교체:

  ```
  5. code-reviewer 에이전트를 실행해 major 이상 문제를 확인한다.
     - 첫 실행 전, `.claude-state/sprint-contract.md`에 `code_review_attempt: 0` 필드가
       없으면 추가한다.
     - **NEEDS_WORK**: `code_review_attempt` 값을 1 증가시키고 sprint-contract.md에 기록한다.
       `code_review_attempt < 2`이면 implementer를 재실행해 지적 항목만 수정한다.
       이후 code-reviewer를 한 번 더 실행한다.
     - `code_review_attempt >= 2`에도 NEEDS_WORK이면 즉시 중단하고 사용자에게 보고한다.
     - **LGTM**: 다음 단계로 진행한다.
  ```

- [ ] **Step 3: harness-reference.md 상태 파일 표 업데이트**

  `sprint-contract.md` 행의 핵심 필드 컬럼에 `code_review_attempt` 추가:

  ```
  | `sprint-contract.md` | planner | `status: none/draft/approved/implemented`, `fix_attempt`, `code_review_attempt` |
  ```

---

## Task 3: common-module-writer 실패 처리 경로 (#3)

**Files:**
- Modify: `.claude/agents/sprint-builder.md` — common-module-writer 실패 분기 추가
- Modify: `.claude/agents/common-module-writer.md` — 실패 시 반환 규약 추가
- Modify: `.claude/agents/implementer.md` — 공통 모듈 재요청 절차 명시

- [ ] **Step 1: 세 파일 현재 상태 읽기**

  각 파일에서 common-module-writer 관련 단계를 찾는다.

- [ ] **Step 2: common-module-writer.md에 실패 반환 규약 추가**

  에이전트 설명 상단(또는 완료 조건 섹션)에 추가:

  ```
  ## 완료 / 실패 반환 규약

  - **성공**: `docs/common-modules.md`에 모든 포트·인터페이스가 기술되고 구현 코드가 작성된 경우.
    `claude-progress.txt`에 `common_module_status: done` 기록.
  - **실패**: 요구사항 불명확, 의존성 설치 불가, 테스트 반복 실패 등으로 완료 불가 시.
    `claude-progress.txt`에 `common_module_status: failed\ncommon_module_error: <사유>` 기록 후 중단.
  ```

- [ ] **Step 3: sprint-builder.md에 실패 감지 분기 추가**

  common-module-writer 호출 직후 단계에:

  ```
  - common-module-writer 완료 후 `claude-progress.txt`의 `common_module_status` 값을 확인한다.
    - `done`: 다음 단계(plan-writer 병렬 실행)로 진행.
    - `failed`: 즉시 중단. `common_module_error` 내용을 사용자에게 보고하고 수동 개입을 요청.
    - 필드 없음: `done`으로 간주하고 진행 (이전 버전 호환).
  ```

- [ ] **Step 4: implementer.md에 공통 모듈 재요청 절차 명시**

  "공통 모듈 수정이 필요하면 즉시 중단" 문장을 다음과 같이 구체화:

  ```
  공통 모듈 수정이 필요한 경우:
  1. 구현을 중단한다.
  2. `claude-progress.txt`에 다음을 기록한다:
     ```
     implementer_blocked: true
     implementer_blocked_reason: common-module 보완 필요 — <구체적 포트/인터페이스명>
     ```
  3. sprint-builder에 "common-module-writer 재실행 후 이 feature implementer를 재시작해달라"고 메시지를 남기고 종료한다.
  sprint-builder는 이 블로커를 감지하면 common-module-writer를 재실행한 뒤 해당 implementer를 재시작한다.
  ```

---

## Task 4: remaining_sprints 판독 위치 수정 (#4)

**Files:**
- Modify: `.claude/hooks/session-start.sh` — `feature-list.json`에서 remaining_sprints 판독
- Modify: `.claude/agents/retrospective.md` — `claude-progress.txt`에 remaining_sprints 기록 규칙 추가

- [ ] **Step 1: session-start.sh의 현재 판독 로직 확인**

  라인 70 근방의 `remaining_sprints` grep 위치 확인.

- [ ] **Step 2: session-start.sh 판독 로직 수정**

  기존:
  ```bash
  REMAINING=$(grep '^remaining_sprints:' ".claude-state/claude-progress.txt" 2>/dev/null | awk '{print $2}')
  ```

  교체:
  ```bash
  # remaining_sprints: feature-list.json의 미완료 feature 수로 판단
  REMAINING="false"
  if [ -f ".claude-state/feature-list.json" ]; then
    PENDING=$("$PYTHON" -c "
  import json, sys
  try:
    data = json.load(open('.claude-state/feature-list.json'))
    features = data if isinstance(data, list) else data.get('features', [])
    pending = [f for f in features if f.get('status','') not in ('done','skipped')]
    print('true' if pending else 'false')
  except:
    print('false')
  " 2>/dev/null || echo "false")
    REMAINING="$PENDING"
  fi
  ```

  단, `claude-progress.txt`에 `remaining_sprints:` 필드가 있으면 그것을 우선 사용하는 fallback도 유지:
  ```bash
  # fallback: claude-progress.txt에 명시된 경우 우선
  PROGRESS_REMAINING=$(grep '^remaining_sprints:' ".claude-state/claude-progress.txt" 2>/dev/null | awk '{print $2}')
  [ -n "$PROGRESS_REMAINING" ] && REMAINING="$PROGRESS_REMAINING"
  ```

- [ ] **Step 3: retrospective.md에 remaining_sprints 기록 규칙 추가**

  retrospective 완료 조건 섹션에:

  ```
  ## 완료 시 기록

  `claude-progress.txt`에 다음 필드를 기록(갱신)한다:
  - `remaining_sprints: true` (미완료 feature가 있는 경우) 또는 `remaining_sprints: false`
  - `improve_needed: true/false` (learnings.md의 값과 동기화)
  ```

---

## Task 5: check-output.sh 에이전트 이름 판별 강화 (#5)

**Files:**
- Modify: `.claude/hooks/check-output.sh` — fallback 로직 단순화, 오판 방지

- [ ] **Step 1: check-output.sh 전체 읽기**

  현재 fallback 로직(라인 86-148)의 흐름을 파악한다.

- [ ] **Step 2: fallback 로직 단순화**

  에이전트 이름 판별 실패 시 기존의 복잡한 휴리스틱을 제거하고 다음으로 교체:

  ```bash
  *)
    # 에이전트 이름 판별 불가 — 안전하게 통과 처리 (오판으로 인한 과차단 방지)
    # check-output.sh는 이름이 명확한 경우에만 차단한다.
    echo "[check-output] 에이전트 이름 판별 불가 (raw: '${AGENT_NAME}'). 검사 건너뜀."
    ;;
  ```

  이유: SubagentStop JSON 스펙이 불안정하므로, 이름 판별 실패 시 통과 처리가 오차단보다 안전하다.
  각 에이전트는 자신의 산출물을 직접 작성하며, check-output은 이중 보호 수단이므로 통과 처리가 허용된다.

- [ ] **Step 3: 에이전트 이름 추출 로직에 `description` 필드 추가**

  기존 필드 우선순위 목록에 `description` 추가 (에이전트 파일의 `description` frontmatter가 포함될 수 있으므로):

  ```python
  for key in ('subagent_name', 'agent_name', 'name', 'agent_type', 'description'):
      val = d.get(key, '')
      if val:
          print(val)
          sys.exit(0)
  ```

---

## Task 6: reviewer → retrospective 이중 트리거 방지 (#6)

**Files:**
- Modify: `.claude/agents/reviewer.md` — retrospective 직접 호출 금지 명시

- [ ] **Step 1: reviewer.md 읽기**

  retrospective 관련 언급이 있는지, 완료 후 동작 섹션을 파악한다.

- [ ] **Step 2: 금지 규칙 추가**

  reviewer.md의 금지 섹션(또는 완료 조건 섹션)에:

  ```
  ## 완료 후 동작

  - `review-notes.md`에 `status: reviewed`를 기록하고 종료한다.
  - **retrospective 에이전트를 직접 호출하지 않는다.**
    retrospective 트리거는 `SubagentStop` 훅(`trigger-retrospective.sh`)이 단독으로 담당한다.
    reviewer가 직접 호출하면 이중 실행이 발생한다.
  ```

---

## Task 7: check-smoke.sh stub 검사 오탐 수정 (#7)

**Files:**
- Modify: `.claude/hooks/check-smoke.sh` — 테스트 파일·주석 제외 필터 추가

- [ ] **Step 1: check-smoke.sh 현재 stub 검사 로직 확인**

  라인 22-31 확인.

- [ ] **Step 2: 테스트 파일 및 주석 제외 필터 추가**

  기존:
  ```bash
  STUB_HITS=$(grep -rn "TODO\|FIXME\|stub\|placeholder\|not implemented\|NotImplemented" $SEARCH_DIRS 2>/dev/null || true)
  ```

  교체:
  ```bash
  # 테스트 파일(__tests__, *.test.*, *.spec.*, test_*.py)과 순수 주석 행 제외
  # 실제 코드 경로에만 존재하는 stub/placeholder만 감지
  STUB_HITS=$(grep -rn \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
    --include="*.py" --include="*.go" \
    --exclude-dir="__tests__" --exclude-dir="node_modules" --exclude-dir=".next" \
    --exclude="*.test.*" --exclude="*.spec.*" --exclude="test_*.py" \
    "TODO\|FIXME\|stub\|placeholder\|not implemented\|NotImplemented" \
    $SEARCH_DIRS 2>/dev/null \
    | grep -v "^\s*//" \
    | grep -v "^\s*#" \
    | grep -v "^\s*\*" \
    || true)
  ```

  이렇게 하면:
  - 테스트 파일 내 TODO는 무시
  - 주석 전용 행(// # *)은 무시
  - 실제 구현 코드 내 stub만 차단

---

## Task 8: fix_attempt 카운터 기록 위치 명시 (#8)

**Files:**
- Modify: `.claude/agents/sprint-builder.md` — integration-fixer 호출 시 fix_attempt 증가 규칙
- Modify: `.claude/agents/integration-fixer.md` — fix_attempt 증가 및 기록 규칙
- Modify: `docs/harness-reference.md` — sprint-contract.md 핵심 필드 표 업데이트

- [ ] **Step 1: 두 파일 읽기**

  sprint-builder.md에서 integration-fixer 호출 부분, integration-fixer.md 시작 부분 확인.

- [ ] **Step 2: integration-fixer.md에 fix_attempt 기록 규칙 추가**

  "실행 전 확인" 섹션 바로 다음에:

  ```
  ## fix_attempt 추적

  진입 시:
  1. `.claude-state/sprint-contract.md`에서 `fix_attempt` 필드를 읽는다.
     없으면 `0`으로 간주한다.
  2. `fix_attempt + 1` 값을 `sprint-contract.md`에 기록한다.
  3. 복구 완료 또는 실패 시 `evaluation-report.md`의 `fix_attempt` 필드도 동기화한다.

  fix_attempt 값은 CLAUDE.md 섹션 2의 차단 조건(`fix_attempt >= 2`)에 사용된다.
  ```

- [ ] **Step 3: sprint-builder.md에 fix_attempt 차단 조건 참조 추가**

  evaluator fail 후 처리 단계에:

  ```
  - evaluation-report.md status가 fail인 경우:
    1. `sprint-contract.md`의 `fix_attempt` 값을 확인한다.
    2. `fix_attempt < 2`: integration-fixer 또는 수정 sprint를 자동 실행한다.
    3. `fix_attempt >= 2`: [BLOCKER] 사용자에게 보고하고 중단한다.
  ```

- [ ] **Step 4: harness-reference.md 상태 파일 표 업데이트**

  Task 2에서 추가한 내용과 합산하여 sprint-contract.md 행 업데이트:

  ```
  | `sprint-contract.md` | planner | `status`, `fix_attempt`, `code_review_attempt` |
  ```

---

## Task 9: feature_id 동기화 순서 명시 (#9)

**Files:**
- Modify: `.claude/agents/planner.md` — usecase-writer 호출 전 feature-list.json 생성 완료 보장
- Modify: `.claude/agents/usecase-writer.md` — feature-list.json 없을 때 임의 번호 부여 금지
- Modify: `docs/harness-reference.md` — sub-agents 병렬 실행 주의사항 추가

- [ ] **Step 1: planner.md에서 usecase-writer 호출 순서 확인**

  dataflow-writer + usecase-writer 병렬 실행 단계 위치 파악.

- [ ] **Step 2: planner.md 실행 순서 수정**

  기존 "dataflow-writer + usecase-writer 병렬" 지시를 다음으로 교체:

  ```
  실행 순서:
  1. prd-writer 실행 → docs/prd.md 완료 대기
  2. userflow-writer 실행 → docs/userflow.md 완료 대기
  3. **feature-list.json 초안 생성**: `.claude-state/feature-list.json`을 먼저 작성한다.
     (이 시점의 feature-list.json은 ID와 이름만 포함. 나머지 필드는 4단계 후 보완)
  4. dataflow-writer + usecase-writer **병렬** 실행
     - usecase-writer는 3단계에서 생성된 feature-list.json의 feature_id를 사용한다.
  5. feature-list.json 나머지 필드(parallel_safe, depends_on, acceptance_criteria, verification_linkage) 보완
  ```

- [ ] **Step 3: usecase-writer.md의 임의 번호 부여 조건 제거**

  기존:
  ```
  feature-list.json이 아직 없으면 userflow의 기능 순서를 기준으로 feature-001 형식으로 번호를 매기고...
  ```

  교체:
  ```
  feature-list.json이 없으면 즉시 중단하고 planner에게 feature-list.json 초안 생성 후
  재실행을 요청한다. feature_id를 임의로 생성하지 않는다.
  ```

- [ ] **Step 4: harness-reference.md sub-agents 표 주석 추가**

  dataflow-writer + usecase-writer 행에:

  ```
  | **dataflow-writer** | 20 | project | `docs/database.md` ← usecase-writer와 병렬 실행 (단, feature-list.json 초안이 먼저 생성된 후) |
  | **usecase-writer** | 20 | project | `docs/usecases/{feature_id}/spec.md` ← feature-list.json 초안 생성 후 dataflow-writer와 병렬 실행 |
  ```

---

## Task 10: policy-updater 자동 트리거 (#10)

**Files:**
- Modify: `.claude/agents/retrospective.md` — improve_needed:true 시 policy-updater 직접 실행 규칙

- [ ] **Step 1: retrospective.md 읽기**

  완료 후 동작 및 improve_needed 설정 부분 확인.

- [ ] **Step 2: 자동 트리거 규칙 추가**

  완료 후 동작 섹션에:

  ```
  ## 완료 후 자동 전환

  1. `learnings.md`와 `metrics.json` 갱신 후:
  2. `remaining_sprints` 값에 따라:
     - `true`: `claude-progress.txt`에 `remaining_sprints: true` 기록. 다음 sprint planner 실행을 메인 세션에 알린다.
     - `false`: `claude-progress.txt`에 `remaining_sprints: false` 기록.
       - `improve_needed: true`이면: **policy-updater 에이전트를 직접 실행한다.**
         policy-updater는 개정안을 생성하고 사용자 승인을 요청한다.
       - `improve_needed: false`이면: 완료 상태를 메인 세션에 알린다.
  ```

  단, CLAUDE.md 섹션 3에 따라 policy-updater 완료 후 사용자 승인 없이 파일 적용은 금지임을 명시.

---

## Task 11: 스크립트 이중 관리 해소 (#11)

**Files:**
- Modify: `.claude/agents/planner.md` — 복사 대신 symlink 또는 단일 경로 참조 정책
- Modify: `docs/harness-reference.md` — 스크립트 위치 설명 업데이트

- [ ] **Step 1: planner.md의 스크립트 복사 지시 확인**

  "cp profiles/<stack>/scripts/smoke scripts/smoke" 지시 위치 파악.

- [ ] **Step 2: 복사 정책을 "초기 생성 시만 복사"로 제한**

  기존:
  ```
  생성 후 scripts/ 루트에도 동일한 파일을 복사한다. 이미 존재하면 덮어쓴다.
  ```

  교체:
  ```
  스크립트 관리 정책:
  - scripts/{smoke,unit,e2e} 파일이 **존재하지 않는 경우에만** profiles/<stack>/scripts/에서 복사한다.
  - 이미 존재하면 복사하지 않는다 (사용자 커스터마이징 보존).
  - 새 스택 프로필을 사용하는 첫 번째 sprint에서만 복사가 발생한다.
  훅(check-smoke.sh)과 evaluator는 scripts/ 루트를 참조한다.
  ```

---

## Task 12: .claude-state/ 디렉토리 초기화 명시 (#12)

**Files:**
- Modify: `.claude/agents/planner.md` — 최초 실행 시 디렉토리 생성 단계 추가

- [ ] **Step 1: planner.md의 첫 번째 실행 단계 확인**

  planner가 sprint-contract.md를 생성하기 전 단계 위치 파악.

- [ ] **Step 2: 디렉토리 생성 단계 추가**

  planner의 첫 번째 실행 단계(또는 "준비" 섹션) 최상단에:

  ```
  ## 사전 준비

  1. `.claude-state/` 디렉토리가 존재하지 않으면 생성한다.
     - 이 디렉토리는 모든 상태 파일의 루트이므로, 어떤 파일 쓰기보다 먼저 확인한다.
  2. `docs/` 디렉토리도 존재하지 않으면 생성한다.
  ```

---

## Task 13: dataflow/usecase 병렬 안전성 (#13)

**Files:**
- Modify: `.claude/agents/planner.md` — Task 9에서 이미 처리 (usecase-writer는 feature-list.json 초안 이후 실행)
- Modify: `.claude/agents/usecase-writer.md` — database.md 없을 때 처리 방침 명시
- Modify: `docs/harness-reference.md` — 병렬 실행 조건 설명 업데이트

- [ ] **Step 1: usecase-writer.md 읽기**

  database.md 참조 방식 확인.

- [ ] **Step 2: usecase-writer.md에 database.md 부재 처리 추가**

  ```
  ## 입력 문서 우선순위

  - `docs/database.md`가 존재하면 반드시 참조해 DB 스키마와 usecase를 정합한다.
  - `docs/database.md`가 아직 생성 중(병렬 실행 중)인 경우:
    1. `docs/userflow.md`와 `docs/prd.md`만으로 우선 usecase를 작성한다.
    2. 문서 말미에 `⚠️ database.md 미참조 — dataflow-writer 완료 후 DB 스키마와 정합 검토 필요` 표시를 남긴다.
    3. planner 또는 sprint-builder가 두 문서 모두 완료된 후 usecase 검토 단계를 포함하도록 한다.
  ```

- [ ] **Step 3: harness-reference.md 흐름도 주석 업데이트**

  이미 Task 9 Step 4에서 처리. 추가로 플로우 설명에:
  ```
  dataflow-writer와 usecase-writer는 feature-list.json 초안 생성 후 병렬 실행.
  usecase-writer는 database.md 미완료 시에도 동작하나 검토 표시를 남긴다.
  ```

---

## Task 14: harness-reference.md 및 harness-version.md 최종 동기화

**Files:**
- Modify: `docs/harness-reference.md` — 모든 수정 사항 반영 확인
- Modify: `.claude-state/harness-version.md` — 버전 변경 이력 추가

- [ ] **Step 1: harness-reference.md 전체 검토**

  위 Task 1-13의 변경사항이 모두 반영되었는지 확인. 누락된 부분 보완.

- [ ] **Step 2: harness-version.md 업데이트**

  버전 항목에 이번 수정 이력 추가:

  ```
  ## v1.0 — 설계 결함 수정 (2026-04-05)

  수정 항목:
  - [#1] 병렬 implementer git 충돌 방지 (feature 단위 커밋 규칙)
  - [#2] code-reviewer 루프 카운터 추적 (code_review_attempt 필드)
  - [#3] common-module-writer 실패 처리 경로 추가
  - [#4] remaining_sprints 판독 위치 수정 (feature-list.json 기반)
  - [#5] check-output.sh fallback 단순화 (오차단 방지)
  - [#6] reviewer → retrospective 이중 트리거 방지
  - [#7] check-smoke.sh stub 검사 오탐 수정 (테스트 파일·주석 제외)
  - [#8] fix_attempt 카운터 기록 위치 명시 (sprint-contract.md)
  - [#9] feature_id 동기화 순서 명시 (feature-list.json 초안 선행 생성)
  - [#10] policy-updater 자동 트리거 (retrospective에서 직접 실행)
  - [#11] 스크립트 이중 관리 해소 (초기 생성 시만 복사)
  - [#12] .claude-state/ 초기화 명시 (planner 사전 준비)
  - [#13] dataflow/usecase 병렬 안전성 (database.md 미참조 표시)
  ```
