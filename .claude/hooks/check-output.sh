#!/usr/bin/env bash
# TaskCompleted hook (evaluator / reviewer / retrospective 전용)
# 산출물 파일이 갱신되었는지 확인합니다.
# 미갱신 시 exit 2로 완료를 차단합니다.

PYTHON="C:/Users/js/AppData/Local/Programs/Python/Python313/python.exe"

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_type',''))" 2>/dev/null || echo "")

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

  TOTAL=$("$PYTHON" -c "import json; d=json.load(open('$FILE')); print(d.get('summary',{}).get('total_sprints',0))" 2>/dev/null || echo "0")
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
    # agent_type 판별 불가 시 evaluation-report 확인
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
