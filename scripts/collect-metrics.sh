#!/usr/bin/env bash
# sprint 결과에서 정량 지표를 추출해 metrics.json에 추가합니다.
# 사용법: bash scripts/collect-metrics.sh <sprint_id>

set -e

SPRINT_ID="${1:-sprint-$(date +%Y%m%d%H%M%S)}"
EVAL_REPORT=".claude-state/evaluation-report.md"
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

# fix_iterations: evaluation fail 횟수
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
