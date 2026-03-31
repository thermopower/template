#!/usr/bin/env bash
# SessionStart hook
# 세션 시작 시 상태 파일을 스캔하고 다음 단계를 Claude에게 주입합니다.

PROGRESS=".claude-state/claude-progress.txt"
CONTRACT=".claude-state/sprint-contract.md"
EVAL_REPORT=".claude-state/evaluation-report.md"
REVIEW_NOTES=".claude-state/review-notes.md"

CONTEXT=""

# 1. progress 요약
if [ -f "$PROGRESS" ]; then
  RECENT=$(head -20 "$PROGRESS")
  CONTEXT="${CONTEXT}\n## 최근 진행 상황\n${RECENT}\n"
else
  CONTEXT="${CONTEXT}\n## 상태\n초기 상태입니다. docs/requirement.md에 요구사항을 작성하고 planner를 실행하세요.\n"
fi

# 2. sprint-contract 상태 판별
NEXT_STEP=""
if [ ! -f "$CONTRACT" ]; then
  NEXT_STEP="planner를 실행하세요. docs/requirement.md에 요구사항이 있는지 먼저 확인하세요."
else
  STATUS=$(grep '^status:' "$CONTRACT" 2>/dev/null | awk '{print $2}')
  case "$STATUS" in
    none)
      NEXT_STEP="planner를 실행하세요."
      ;;
    draft)
      NEXT_STEP="sprint-contract.md가 draft 상태입니다. 사용자에게 내용을 제시하고 승인을 요청하세요."
      ;;
    approved)
      NEXT_STEP="sprint-contract가 승인되었습니다. sprint-builder를 실행하세요."
      ;;
    implemented)
      # evaluation-report 확인
      EVAL_STATUS=$(grep '^status:' "$EVAL_REPORT" 2>/dev/null | awk '{print $2}')
      if [ -z "$EVAL_STATUS" ] || [ "$EVAL_STATUS" = "none" ]; then
        NEXT_STEP="sprint-builder가 완료되었습니다. evaluator를 실행하세요."
      elif [ "$EVAL_STATUS" = "fail" ]; then
        NEXT_STEP="evaluation이 fail입니다. blocker를 확인하고 integration-fixer 또는 수정 sprint를 진행하세요."
      elif [ "$EVAL_STATUS" = "pass" ]; then
        # review-notes 확인
        if [ ! -f "$REVIEW_NOTES" ] || ! grep -q "##" "$REVIEW_NOTES" 2>/dev/null; then
          NEXT_STEP="evaluation이 pass입니다. reviewer를 실행하세요."
        else
          NEXT_STEP="review가 완료되었습니다. 사용자에게 다음 sprint 진행 여부를 확인하세요."
        fi
      fi
      ;;
    *)
      NEXT_STEP="sprint-contract status를 확인하세요: $STATUS"
      ;;
  esac
fi

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

CONTEXT="${CONTEXT}\n## 다음 단계\n${NEXT_STEP}\n"

# JSON output for additionalContext
PYTHON="C:/Users/js/AppData/Local/Programs/Python/Python313/python.exe"
"$PYTHON" -c "
import json, sys
context = sys.argv[1]
output = {
  'hookSpecificOutput': {
    'hookEventName': 'SessionStart',
    'additionalContext': context
  }
}
print(json.dumps(output))
" "$CONTEXT" 2>/dev/null || echo "{}"

exit 0
