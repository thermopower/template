#!/usr/bin/env bash
# SubagentStop hook (evaluator / reviewer / retrospective 전용)
# 산출물 파일이 갱신되었는지 확인합니다.
# 미갱신 시 exit 2로 완료를 차단합니다.

_try_python() { "$1" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$1"; }
PYTHON="${PYTHON_CMD:-$(_try_python python || _try_python python3 || echo 'python')}"

INPUT=$(cat)

# SubagentStop JSON에서 에이전트 이름 추출
# Claude Code는 subagent_name, name, agent_name 등 여러 필드를 사용할 수 있으므로
# 알려진 모든 필드를 순서대로 시도하고, 모두 없으면 matcher를 통해 판별
AGENT_NAME=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # 알려진 필드명 우선순위 순으로 시도
    for key in ('subagent_name', 'agent_name', 'name', 'agent_type'):
        val = d.get(key, '')
        if val:
            print(val)
            sys.exit(0)
    print('')
except Exception:
    print('')
" 2>/dev/null || echo "")

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

  # status: none 또는 빈 파일이면 미갱신으로 판단
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

  TOTAL=$("$PYTHON" -c "import json; d=json.load(open('${FILE}')); print(d.get('summary',{}).get('total_sprints',0))" 2>/dev/null || echo "0")
  if [ "$TOTAL" = "0" ]; then
    echo "[$LABEL] metrics.json에 기록된 sprint가 없습니다." >&2
    exit 2
  fi

  echo "[$LABEL] metrics.json 갱신 확인 (total_sprints: $TOTAL)"
}

# 에이전트 이름 기반으로 분기 (부분 일치)
case "$AGENT_NAME" in
  *evaluator*)
    check_file_updated "$EVAL_REPORT" "evaluator"
    ;;
  *reviewer*)
    check_file_updated "$REVIEW_NOTES" "reviewer"
    ;;
  *retrospective*)
    check_file_updated "$LEARNINGS" "retrospective"
    check_json_updated "$METRICS" "retrospective"
    ;;
  *)
    # 에이전트 이름 판별 불가 시: 변경된 파일 기준으로 추론
    # 주의: 각 파일을 독립적으로 검사한다.
    # "해당 에이전트가 담당하는 파일만" 검사해야 하므로,
    # status가 none이 아닌 파일(= 이미 이전에 갱신된 파일)은 무시하고
    # 이번에 갱신됐어야 할 파일만 차단 대상으로 삼는다.
    # 판별 기준: 3개 파일 중 status != none인 것이 하나라도 있으면
    # 그 파일의 담당 에이전트가 방금 실행된 것으로 간주하고 해당 파일만 검증한다.
    BLOCKED=0
    UPDATED_COUNT=0

    EVAL_STATUS=""
    REVIEW_STATUS=""
    LEARN_STATUS=""

    [ -f "$EVAL_REPORT" ] && EVAL_STATUS=$(grep '^status:' "$EVAL_REPORT" 2>/dev/null | awk '{print $2}')
    [ -f "$REVIEW_NOTES" ] && REVIEW_STATUS=$(grep '^status:' "$REVIEW_NOTES" 2>/dev/null | awk '{print $2}')
    [ -f "$LEARNINGS" ] && LEARN_STATUS=$(grep '^status:' "$LEARNINGS" 2>/dev/null | awk '{print $2}')

    [ -n "$EVAL_STATUS" ] && [ "$EVAL_STATUS" != "none" ] && UPDATED_COUNT=$((UPDATED_COUNT + 1))
    [ -n "$REVIEW_STATUS" ] && [ "$REVIEW_STATUS" != "none" ] && UPDATED_COUNT=$((UPDATED_COUNT + 1))
    [ -n "$LEARN_STATUS" ] && [ "$LEARN_STATUS" != "none" ] && UPDATED_COUNT=$((UPDATED_COUNT + 1))

    if [ "$UPDATED_COUNT" = "0" ]; then
      # 세 파일 모두 none — sprint-builder 직후이거나 최초 상태이므로 차단하지 않음
      echo "[check-output] 에이전트 이름 판별 불가 (raw: '${AGENT_NAME}'). 산출물 파일 모두 초기 상태 — 통과."
    else
      # 하나 이상 갱신됨 — 갱신된 파일 중 none인 것이 있으면 해당 에이전트가 미완료로 판단
      if [ -n "$EVAL_STATUS" ] && [ "$EVAL_STATUS" != "none" ]; then
        echo "[check-output] evaluation-report.md 갱신 확인 (status: $EVAL_STATUS)"
      elif [ -f "$EVAL_REPORT" ] && { [ -z "$EVAL_STATUS" ] || [ "$EVAL_STATUS" = "none" ]; }; then
        # evaluator가 실행됐어야 하는데 미갱신 — 다른 파일이 갱신된 상황이므로 skip
        true
      fi

      if [ -n "$REVIEW_STATUS" ] && [ "$REVIEW_STATUS" != "none" ]; then
        echo "[check-output] review-notes.md 갱신 확인 (status: $REVIEW_STATUS)"
      fi

      if [ -n "$LEARN_STATUS" ] && [ "$LEARN_STATUS" != "none" ]; then
        echo "[check-output] learnings.md 갱신 확인 (status: $LEARN_STATUS)"
      fi

      # 갱신된 파일이 있는데 learnings만 none이고 나머지도 이미 갱신 완료 상태라면
      # retrospective가 방금 실행된 것으로 간주 — learnings가 none이면 차단
      if [ "$UPDATED_COUNT" -ge 2 ] && { [ -z "$LEARN_STATUS" ] || [ "$LEARN_STATUS" = "none" ]; }; then
        echo "[check-output] 에이전트 이름 불명 — learnings.md 미갱신 감지 (retrospective 미완료 추정)" >&2
        BLOCKED=1
      fi
    fi

    if [ "$BLOCKED" = "1" ]; then
      exit 2
    fi

    echo "[check-output] 에이전트 이름 판별 불가 (raw: '${AGENT_NAME}'). 검사 완료."
    ;;
esac

exit 0
