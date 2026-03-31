# Self-Learning Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 하네스가 sprint 루프 결과를 정량 지표로 학습하고, 임계점 도달 시 에이전트·정책 개정안을 생성해 사용자 승인 후 적용하는 자기개선 시스템을 추가한다.

**Architecture:** `retrospective` 에이전트가 매 루프 종료 후 자동으로 지표를 수집·누적하고, 임계점 감지 시 사용자에게 `/improve` 실행을 권장한다. `/improve` 명령 시 `policy-updater` 에이전트가 기존 파일 업데이트 우선, 신규 파일 최소 생성 원칙으로 개정안을 diff 형태로 제시하고 승인 후 적용한다.

**Tech Stack:** bash, python3 (json 처리), Claude Code agents/hooks/settings

---

## 파일 구조

### 새로 생성
- `.claude/agents/retrospective.md` — retrospective 에이전트 instruction
- `.claude/agents/policy-updater.md` — policy-updater 에이전트 instruction
- `.claude-state/learnings.md` — 누적 학습 데이터 초기 파일
- `.claude-state/metrics.json` — 정량 지표 시계열 초기 파일
- `scripts/collect-metrics.sh` — evaluation-report + sprint-contract에서 지표 추출
- `scripts/check-thresholds.sh` — metrics.json 읽어 임계점 판단
- `.claude/hooks/trigger-retrospective.sh` — reviewer 완료 시 retrospective 트리거

### 수정
- `CLAUDE.md` — retrospective 단계 및 `/improve` 명령 추가
- `.claude/settings.json` — TeammateIdle reviewer hook, TaskCompleted retrospective 추가, slash_commands 추가
- `.claude/hooks/session-start.sh` — learnings + 지표 요약 컨텍스트 주입
- `.claude/hooks/check-output.sh` — retrospective 산출물(learnings.md, metrics.json) 체크 추가

---

## Task 1: 상태 파일 초기화

**Files:**
- Create: `.claude-state/learnings.md`
- Create: `.claude-state/metrics.json`

- [ ] **Step 1: learnings.md 초기 파일 생성**

```markdown
# Learnings

status: none

<!-- retrospective 에이전트가 sprint 완료 후 자동으로 기록합니다. -->
```

파일 경로: `.claude-state/learnings.md`

- [ ] **Step 2: metrics.json 초기 파일 생성**

```json
{
  "sprints": [],
  "summary": {
    "total_sprints": 0,
    "pass_rate": null,
    "avg_blockers_per_sprint": null,
    "avg_turns": null,
    "repeated_blocker_types": {}
  }
}
```

파일 경로: `.claude-state/metrics.json`

- [ ] **Step 3: 커밋**

```bash
git add .claude-state/learnings.md .claude-state/metrics.json
git commit -m "feat: add initial state files for self-learning harness"
```

---

## Task 2: collect-metrics.sh 작성

**Files:**
- Create: `scripts/collect-metrics.sh`

- [ ] **Step 1: 스크립트 작성**

```bash
#!/usr/bin/env bash
# sprint 결과에서 정량 지표를 추출해 metrics.json에 추가합니다.
# 사용법: bash scripts/collect-metrics.sh <sprint_id>

set -e

SPRINT_ID="${1:-sprint-$(date +%Y%m%d%H%M%S)}"
EVAL_REPORT=".claude-state/evaluation-report.md"
CONTRACT=".claude-state/sprint-contract.md"
METRICS=".claude-state/metrics.json"

if [ ! -f "$EVAL_REPORT" ]; then
  echo "[collect-metrics] evaluation-report.md 없음. 지표 수집 건너뜀." >&2
  exit 0
fi

# eval_result 추출
EVAL_STATUS=$(grep '^status:' "$EVAL_REPORT" 2>/dev/null | awk '{print $2}' | head -1)
[ -z "$EVAL_STATUS" ] && EVAL_STATUS="unknown"

# blocker 수 추출 (## Blocker 섹션의 항목 수)
BLOCKER_COUNT=$(awk '/^## Blocker/,/^## /' "$EVAL_REPORT" 2>/dev/null | grep -c '^- ' || echo 0)

# blocker 유형 추출 (첫 번째 단어 기준)
BLOCKER_TYPES=$(awk '/^## Blocker/,/^## /' "$EVAL_REPORT" 2>/dev/null | grep '^- ' | awk '{print $2}' | tr '\n' ',' | sed 's/,$//' || echo "")

# fix_iterations: evaluation fail 횟수 (간단히 status: fail 줄 수)
FIX_ITER=$(grep -c '^status: fail' "$EVAL_REPORT" 2>/dev/null || echo 0)

DATE=$(date +%Y-%m-%d)

python3 - <<EOF
import json, sys

metrics_path = "$METRICS"
with open(metrics_path, 'r') as f:
    data = json.load(f)

sprint = {
    "sprint_id": "$SPRINT_ID",
    "date": "$DATE",
    "eval_result": "$EVAL_STATUS",
    "blocker_count": $BLOCKER_COUNT,
    "blocker_types": [t for t in "$BLOCKER_TYPES".split(',') if t],
    "total_turns": 0,
    "fix_iterations": $FIX_ITER
}
data["sprints"].append(sprint)

sprints = data["sprints"]
total = len(sprints)
passed = sum(1 for s in sprints if s["eval_result"] == "pass")
pass_rate = round(passed / total, 2) if total > 0 else None
avg_blockers = round(sum(s["blocker_count"] for s in sprints) / total, 1) if total > 0 else None
avg_turns = round(sum(s["total_turns"] for s in sprints) / total, 1) if total > 0 else None

blocker_counts = {}
for s in sprints:
    for bt in s.get("blocker_types", []):
        blocker_counts[bt] = blocker_counts.get(bt, 0) + 1

data["summary"] = {
    "total_sprints": total,
    "pass_rate": pass_rate,
    "avg_blockers_per_sprint": avg_blockers,
    "avg_turns": avg_turns,
    "repeated_blocker_types": blocker_counts
}

with open(metrics_path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"[collect-metrics] sprint {sprint['sprint_id']} 기록 완료 (eval: {sprint['eval_result']}, blockers: {sprint['blocker_count']})")
EOF
```

- [ ] **Step 2: 실행 권한 부여 및 동작 확인**

```bash
chmod +x scripts/collect-metrics.sh
bash scripts/collect-metrics.sh test-sprint-001
cat .claude-state/metrics.json
```

Expected: metrics.json에 test-sprint-001 항목이 추가됨

- [ ] **Step 3: 테스트 데이터 제거 후 초기화**

```bash
cat > .claude-state/metrics.json << 'EOF'
{
  "sprints": [],
  "summary": {
    "total_sprints": 0,
    "pass_rate": null,
    "avg_blockers_per_sprint": null,
    "avg_turns": null,
    "repeated_blocker_types": {}
  }
}
EOF
```

- [ ] **Step 4: 커밋**

```bash
git add scripts/collect-metrics.sh .claude-state/metrics.json
git commit -m "feat: add collect-metrics.sh for quantitative sprint metrics"
```

---

## Task 3: check-thresholds.sh 작성

**Files:**
- Create: `scripts/check-thresholds.sh`

- [ ] **Step 1: 스크립트 작성**

```bash
#!/usr/bin/env bash
# metrics.json을 읽어 임계점 도달 여부를 판단합니다.
# --summary 옵션: 한 줄 요약 출력
# exit 0: 정상, exit 1: 임계점 도달

METRICS=".claude-state/metrics.json"
SUMMARY_MODE=false
[ "$1" = "--summary" ] && SUMMARY_MODE=true

if [ ! -f "$METRICS" ]; then
  $SUMMARY_MODE && echo "지표 없음 (metrics.json 미존재)"
  exit 0
fi

python3 - <<'EOF'
import json, sys

with open(".claude-state/metrics.json", "r") as f:
    data = json.load(f)

summary = data.get("summary", {})
sprints = data.get("sprints", [])
summary_mode = "--summary" in sys.argv

triggered = []

# 임계점 1: 3회 연속 fail
if len(sprints) >= 3:
    last3 = [s["eval_result"] for s in sprints[-3:]]
    if all(r == "fail" for r in last3):
        triggered.append("3회 연속 eval fail")

# 임계점 2: 전체 pass율 < 50% (최소 4회 이상)
total = summary.get("total_sprints", 0)
pass_rate = summary.get("pass_rate")
if total >= 4 and pass_rate is not None and pass_rate < 0.5:
    triggered.append(f"전체 pass율 {int(pass_rate*100)}% (< 50%)")

# 임계점 3: 동일 blocker 유형 3회 이상
repeated = {k: v for k, v in summary.get("repeated_blocker_types", {}).items() if v >= 3}
for bt, cnt in repeated.items():
    triggered.append(f"blocker '{bt}' {cnt}회 반복")

# 임계점 4: 평균 턴 수 60 초과 3회 연속
if len(sprints) >= 3:
    last3_turns = [s["total_turns"] for s in sprints[-3:]]
    if all(t > 60 for t in last3_turns):
        triggered.append(f"3회 연속 턴 수 초과 (60턴 기준)")

if summary_mode:
    if triggered:
        print("⚠️ 임계점 도달: " + " / ".join(triggered))
    else:
        total_s = summary.get("total_sprints", 0)
        pr = f"{int(pass_rate*100)}%" if pass_rate is not None else "N/A"
        print(f"정상 (총 {total_s}회, pass율 {pr})")
    sys.exit(0)

if triggered:
    for t in triggered:
        print(f"[threshold] {t}", flush=True)
    sys.exit(1)
else:
    sys.exit(0)
EOF
```

- [ ] **Step 2: 실행 권한 부여 및 동작 확인**

```bash
chmod +x scripts/check-thresholds.sh
bash scripts/check-thresholds.sh --summary
```

Expected: `정상 (총 0회, pass율 N/A)`

- [ ] **Step 3: 커밋**

```bash
git add scripts/check-thresholds.sh
git commit -m "feat: add check-thresholds.sh for threshold detection"
```

---

## Task 4: trigger-retrospective.sh 작성

**Files:**
- Create: `.claude/hooks/trigger-retrospective.sh`

- [ ] **Step 1: 스크립트 작성**

```bash
#!/usr/bin/env bash
# TeammateIdle hook — reviewer 완료 시 retrospective 실행을 Claude에게 알립니다.

python3 -c "
import json
output = {
  'hookSpecificOutput': {
    'hookEventName': 'TeammateIdle',
    'additionalContext': 'reviewer가 완료되었습니다. retrospective 에이전트를 실행해 이번 sprint 지표를 수집하고 learnings를 누적하세요.'
  }
}
print(json.dumps(output))
"

exit 0
```

- [ ] **Step 2: 실행 권한 부여**

```bash
chmod +x .claude/hooks/trigger-retrospective.sh
```

- [ ] **Step 3: 커밋**

```bash
git add .claude/hooks/trigger-retrospective.sh
git commit -m "feat: add trigger-retrospective hook for reviewer completion"
```

---

## Task 5: retrospective 에이전트 작성

**Files:**
- Create: `.claude/agents/retrospective.md`

- [ ] **Step 1: 에이전트 파일 작성**

```markdown
---
name: retrospective
description: sprint 루프 종료 후 자동 실행. 정량 지표 분석 및 learnings 누적. 파일 수정은 learnings.md와 metrics.json만 허용.
model: haiku
memory: project
tools: Read, Write, Edit, Bash, Glob, Grep
maxTurns: 20
---

당신은 retrospective 에이전트다. sprint 루프가 끝날 때마다 자동으로 실행되어 정량 지표를 수집하고 learnings를 누적한다.

## 실행 순서

1. `.claude-state/evaluation-report.md`를 읽어 eval 결과, blocker 목록을 파악한다.
2. `.claude-state/sprint-contract.md`를 읽어 sprint ID와 범위를 파악한다.
3. `.claude-state/review-notes.md`를 읽어 반복 코멘트 패턴을 파악한다.
4. `~/.claude/projects/` memory를 참조해 cross-session 패턴을 확인한다.
5. `bash scripts/collect-metrics.sh <sprint_id>`를 실행해 metrics.json을 갱신한다.
6. `.claude-state/learnings.md`에 이번 sprint 요약을 누적한다.
   - 형식: `## <sprint_id> — <date>\n- eval: <result>\n- blocker: <유형>\n- 턴 수: <수>\n- 패턴: <관찰>`
7. `bash scripts/check-thresholds.sh`를 실행한다.
   - exit 1(임계점 도달): 사용자에게 다음 메시지를 출력한다.
     `⚠️ 개선 임계점에 도달했습니다. /improve 명령으로 policy-updater를 실행하세요.`
     구체적인 임계점 내용도 함께 출력한다.
   - exit 0(정상): 조용히 종료한다.

## learnings.md 갱신 규칙

- 기존 내용을 삭제하지 않는다. 항상 하단에 추가한다.
- status를 `active`로 갱신한다 (파일 상단 `status:` 줄).
- 항목당 5줄 이내로 간결하게 작성한다.

## 금지사항

- learnings.md, metrics.json 외 파일 수정
- policy-updater 자동 실행
- 개선 방향 상세 제안 (요약 패턴 기록만)
- evaluation-report.md, sprint-contract.md 수정
```

- [ ] **Step 2: 파일 존재 확인**

```bash
cat .claude/agents/retrospective.md | head -5
```

Expected: `---` frontmatter 시작 확인

- [ ] **Step 3: 커밋**

```bash
git add .claude/agents/retrospective.md
git commit -m "feat: add retrospective agent for sprint metrics collection"
```

---

## Task 6: policy-updater 에이전트 작성

**Files:**
- Create: `.claude/agents/policy-updater.md`

- [ ] **Step 1: 에이전트 파일 작성**

```markdown
---
name: policy-updater
description: learnings 기반으로 에이전트/정책 개정안을 생성한다. 업데이트 우선, 신규 파일 최소 생성. 사용자 승인 후에만 파일 적용.
model: sonnet
memory: project
tools: Read, Write, Edit, Glob, Grep
maxTurns: 30
---

당신은 policy-updater 에이전트다. 누적된 learnings와 metrics를 분석해 에이전트·정책 파일 개정안을 생성하고, 사용자 승인 후 적용한다.

## 실행 순서

1. `.claude-state/learnings.md` 전체를 읽는다.
2. `.claude-state/metrics.json` 전체를 읽는다.
3. 개선이 필요한 항목 목록을 작성한다. 각 항목마다:
   - 근거: learnings/metrics의 구체적 수치 또는 반복 패턴
   - 대상 파일: 어느 파일을 수정하는가
   - 판단: 기존 파일 업데이트 vs 신규 파일 생성
4. **업데이트 우선 원칙**: 기존 파일로 해결 가능하면 반드시 업데이트를 선택한다.
5. **신규 파일 생성 조건** (모두 충족해야 함):
   - 동일 패턴이 learnings에 3회 이상 기록됨
   - 기존 `.claude/agents/`, `.claude/hooks/`, `scripts/`, `CLAUDE.md` 중 어느 파일로도 커버 불가
   - 생성 후 독립적으로 삭제 가능한 단위
6. 개정안을 사용자에게 제시한다:
   - 업데이트 항목: diff 형태 (before/after)
   - 신규 파일: 전체 내용 + 생성 이유
7. 사용자 승인을 받는다. 승인 전에는 어떤 파일도 수정하지 않는다.
8. 승인 후 파일을 적용한다.
9. `.claude-state/learnings.md` 상단 status를 `reviewed`로 갱신한다.

## 개정안 제시 형식

```
## 개정안 목록

### 1. [업데이트] .claude/agents/implementer.md
근거: TypeScript any 사용 blocker 3회 반복 (sprint-001, 003, 005)
변경:
- before: TypeScript에서는 any를 피한다.
+ after: TypeScript에서는 any를 절대 사용하지 않는다. any가 필요한 경우 unknown으로 대체하고 타입 가드를 작성한다.

### 2. [신규] .claude/agents/type-checker.md
근거: type_error blocker 5회 반복, 기존 implementer/evaluator로 커버 불가
내용: (전체 파일 내용)
생성 이유: ...
```

## 금지사항

- 사용자 승인 없이 파일 수정
- 신규 파일 생성 조건 미충족 시 생성
- CLAUDE.md 직접 수정 (diff 제안만, 적용은 사용자가 판단)
- learnings 없이 추측으로 개정안 생성
- 한 번에 5개 초과 항목 제안 (우선순위 높은 것부터 5개 이내)
```

- [ ] **Step 2: 커밋**

```bash
git add .claude/agents/policy-updater.md
git commit -m "feat: add policy-updater agent for policy improvement"
```

---

## Task 7: settings.json 업데이트

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: 현재 파일 확인 후 수정**

`.claude/settings.json`을 다음으로 교체한다:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/session-start.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "matcher": "sprint-builder",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/check-smoke.sh",
            "timeout": 120
          }
        ]
      },
      {
        "matcher": "reviewer",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/trigger-retrospective.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "evaluator|reviewer|retrospective",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/check-output.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: JSON 유효성 확인**

```bash
python3 -m json.tool .claude/settings.json > /dev/null && echo "JSON valid"
```

Expected: `JSON valid`

- [ ] **Step 3: 커밋**

```bash
git add .claude/settings.json
git commit -m "feat: add reviewer TeammateIdle hook and retrospective TaskCompleted hook"
```

---

## Task 8: check-output.sh 업데이트

**Files:**
- Modify: `.claude/hooks/check-output.sh`

- [ ] **Step 1: retrospective 산출물 체크 추가**

`case "$AGENT_TYPE" in` 블록에 retrospective 케이스를 추가한다:

```bash
#!/usr/bin/env bash
# TaskCompleted hook (evaluator / reviewer / retrospective 전용)

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_type',''))" 2>/dev/null || echo "")

EVAL_REPORT=".claude-state/evaluation-report.md"
REVIEW_NOTES=".claude-state/review-notes.md"
LEARNINGS=".claude-state/learnings.md"
METRICS=".claude-state/metrics.json"

check_file_updated() {
  local FILE="$1"
  local LABEL="$2"

  if [ ! -f "$FILE" ]; then
    echo "[$LABEL] $FILE 파일이 존재하지 않습니다." >&2
    exit 2
  fi

  STATUS=$(grep '^status:' "$FILE" 2>/dev/null | awk '{print $2}')
  if [ -z "$STATUS" ] || [ "$STATUS" = "none" ]; then
    echo "[$LABEL] $FILE 가 갱신되지 않았습니다. (status: none)" >&2
    echo "[$LABEL] 판정 결과를 파일에 기록한 후 완료하세요." >&2
    exit 2
  fi

  echo "[$LABEL] $FILE 갱신 확인 (status: $STATUS)"
}

check_json_updated() {
  local FILE="$1"
  local LABEL="$2"

  if [ ! -f "$FILE" ]; then
    echo "[$LABEL] $FILE 파일이 존재하지 않습니다." >&2
    exit 2
  fi

  TOTAL=$(python3 -c "import json; d=json.load(open('$FILE')); print(d.get('summary',{}).get('total_sprints',0))" 2>/dev/null || echo "0")
  if [ "$TOTAL" = "0" ]; then
    echo "[$LABEL] metrics.json에 기록된 sprint가 없습니다." >&2
    exit 2
  fi

  echo "[$LABEL] metrics.json 갱신 확인 (total_sprints: $TOTAL)"
}

case "$AGENT_TYPE" in
  evaluator)
    check_file_updated "$EVAL_REPORT" "evaluator"
    ;;
  reviewer)
    check_file_updated "$REVIEW_NOTES" "reviewer"
    ;;
  retrospective)
    check_file_updated "$LEARNINGS" "retrospective"
    check_json_updated "$METRICS" "retrospective"
    ;;
  *)
    if [ -f "$EVAL_REPORT" ]; then
      STATUS=$(grep '^status:' "$EVAL_REPORT" 2>/dev/null | awk '{print $2}')
      if [ -z "$STATUS" ] || [ "$STATUS" = "none" ]; then
        echo "[check-output] evaluation-report.md 미갱신" >&2
        exit 2
      fi
    fi
    ;;
esac

exit 0
```

- [ ] **Step 2: 구문 확인**

```bash
bash -n .claude/hooks/check-output.sh && echo "syntax OK"
```

Expected: `syntax OK`

- [ ] **Step 3: 커밋**

```bash
git add .claude/hooks/check-output.sh
git commit -m "feat: add retrospective output check to check-output.sh"
```

---

## Task 9: session-start.sh 업데이트

**Files:**
- Modify: `.claude/hooks/session-start.sh`

- [ ] **Step 1: learnings + 지표 요약 주입 추가**

기존 `CONTEXT="${CONTEXT}\n## 다음 단계\n${NEXT_STEP}\n"` 줄 앞에 다음을 추가한다:

```bash
# 3. learnings 최근 내용 주입
if [ -f ".claude-state/learnings.md" ]; then
  LEARN_STATUS=$(grep '^status:' ".claude-state/learnings.md" 2>/dev/null | awk '{print $2}')
  if [ "$LEARN_STATUS" = "active" ] || [ "$LEARN_STATUS" = "reviewed" ]; then
    RECENT_LEARNINGS=$(tail -20 ".claude-state/learnings.md")
    CONTEXT="${CONTEXT}\n## 최근 학습 내용\n${RECENT_LEARNINGS}\n"
  fi
fi

# 4. 지표 요약 주입
if [ -f "scripts/check-thresholds.sh" ]; then
  THRESHOLD_SUMMARY=$(bash scripts/check-thresholds.sh --summary 2>/dev/null || echo "지표 확인 불가")
  CONTEXT="${CONTEXT}\n## 지표 요약\n${THRESHOLD_SUMMARY}\n"
fi
```

- [ ] **Step 2: 구문 확인**

```bash
bash -n .claude/hooks/session-start.sh && echo "syntax OK"
```

Expected: `syntax OK`

- [ ] **Step 3: 동작 확인**

```bash
bash .claude/hooks/session-start.sh
```

Expected: JSON 출력에 `지표 요약` 섹션 포함

- [ ] **Step 4: 커밋**

```bash
git add .claude/hooks/session-start.sh
git commit -m "feat: inject learnings and metrics summary into session context"
```

---

## Task 10: CLAUDE.md 업데이트

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 단계 전환 규칙 테이블에 retrospective 행 추가**

`review-notes.md 작성 완료` 행 다음에 추가:

```markdown
| `review-notes.md` 작성 완료 | retrospective 실행 |
| retrospective 완료, 임계점 도달 | 사용자에게 `/improve` 실행 권장 |
| `/improve` 명령 | policy-updater 실행 |
```

- [ ] **Step 2: 역할 구분 섹션에 새 에이전트 추가**

```markdown
- **retrospective**: sprint 지표 수집 및 learnings 누적. 파일 수정은 learnings.md/metrics.json만 허용.
- **policy-updater**: learnings 기반 개정안 생성. 업데이트 우선, 신규 최소. 승인 후 적용.
```

- [ ] **Step 3: `/improve` 명령 설명 섹션 추가**

`## 8. 코딩 원칙` 앞에 추가:

```markdown
## 8. 자기개선 명령

- `/improve`: 누적된 learnings 기반으로 policy-updater를 실행해 에이전트·정책 개정안을 생성한다.
  - 개정안은 diff 형태로 제시되며 사용자 승인 후 적용된다.
  - learnings가 없으면 실행하지 않는다.
```

- [ ] **Step 4: 커밋**

```bash
git add CLAUDE.md
git commit -m "feat: add retrospective/policy-updater stages and /improve command to CLAUDE.md"
```

---

## Task 11: 전체 통합 검증

- [ ] **Step 1: 파일 존재 확인**

```bash
ls .claude/agents/retrospective.md \
   .claude/agents/policy-updater.md \
   .claude-state/learnings.md \
   .claude-state/metrics.json \
   scripts/collect-metrics.sh \
   scripts/check-thresholds.sh \
   .claude/hooks/trigger-retrospective.sh
```

Expected: 모든 파일 존재

- [ ] **Step 2: 스크립트 구문 검사**

```bash
bash -n scripts/collect-metrics.sh && echo "collect-metrics OK"
bash -n scripts/check-thresholds.sh && echo "check-thresholds OK"
bash -n .claude/hooks/trigger-retrospective.sh && echo "trigger-retrospective OK"
bash -n .claude/hooks/session-start.sh && echo "session-start OK"
bash -n .claude/hooks/check-output.sh && echo "check-output OK"
```

Expected: 모두 OK

- [ ] **Step 3: 임계점 시뮬레이션 — 3회 연속 fail 주입**

```bash
python3 - << 'EOF'
import json

data = {
  "sprints": [
    {"sprint_id": "sim-001", "date": "2026-03-28", "eval_result": "fail", "blocker_count": 2, "blocker_types": ["type_error"], "total_turns": 45, "fix_iterations": 1},
    {"sprint_id": "sim-002", "date": "2026-03-29", "eval_result": "fail", "blocker_count": 3, "blocker_types": ["type_error", "dependency"], "total_turns": 55, "fix_iterations": 2},
    {"sprint_id": "sim-003", "date": "2026-03-30", "eval_result": "fail", "blocker_count": 2, "blocker_types": ["type_error"], "total_turns": 50, "fix_iterations": 1}
  ],
  "summary": {"total_sprints": 3, "pass_rate": 0.0, "avg_blockers_per_sprint": 2.3, "avg_turns": 50.0, "repeated_blocker_types": {"type_error": 3, "dependency": 1}}
}
with open(".claude-state/metrics.json", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print("시뮬레이션 데이터 주입 완료")
EOF
bash scripts/check-thresholds.sh --summary
```

Expected: `⚠️ 임계점 도달: 3회 연속 eval fail / blocker 'type_error' 3회 반복`

- [ ] **Step 4: 시뮬레이션 데이터 초기화**

```bash
cat > .claude-state/metrics.json << 'EOF'
{
  "sprints": [],
  "summary": {
    "total_sprints": 0,
    "pass_rate": null,
    "avg_blockers_per_sprint": null,
    "avg_turns": null,
    "repeated_blocker_types": {}
  }
}
EOF
```

- [ ] **Step 5: settings.json 최종 확인**

```bash
python3 -m json.tool .claude/settings.json > /dev/null && echo "settings.json valid"
```

Expected: `settings.json valid`

- [ ] **Step 6: 최종 커밋**

```bash
git add -A
git status
git commit -m "feat: complete self-learning harness integration"
```
