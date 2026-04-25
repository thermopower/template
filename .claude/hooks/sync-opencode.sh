#!/usr/bin/env bash
# sync-opencode.sh (hook)
# PostToolUse: Edit/Write 시 변경된 파일이 .ruler/AGENTS.md 또는 .claude/agents/ 이면
# scripts/sync-opencode.sh 를 실행해 .opencode/ 와 싱크한다.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Claude Code 훅은 stdin으로 JSON을 전달한다
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); p=d.get('tool_input',{}); print(p.get('file_path', p.get('path','')))" 2>/dev/null || echo "")

# Edit/Write 이외는 무시
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

# 변경 파일 판단
if [[ "$FILE_PATH" == *".ruler/AGENTS.md" ]]; then
  bash "$ROOT/scripts/sync-opencode.sh" --rules
elif [[ "$FILE_PATH" == *".claude/agents/"* ]]; then
  bash "$ROOT/scripts/sync-opencode.sh" --agents
fi

exit 0
