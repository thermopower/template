#!/usr/bin/env bash
# TeammateIdle hook — reviewer 완료 시 retrospective 실행을 Claude에게 알립니다.

"C:/Users/js/AppData/Local/Programs/Python/Python313/python.exe" -c "
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
