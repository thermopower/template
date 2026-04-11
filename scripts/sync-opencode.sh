#!/usr/bin/env bash
# sync-opencode.sh
# .ruler/AGENTS.md 또는 .claude/agents/*.md 변경 시 .opencode/ 와 싱크한다.
# 사용법: bash scripts/sync-opencode.sh [--agents | --rules | --all]
#   --agents : .claude/agents/*.md → .opencode/agents/*.md 싱크
#   --rules  : .ruler/AGENTS.md → .opencode/rules/AGENTS.md 싱크
#   --all    : 둘 다 (기본값)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---all}"

sync_rules() {
  local src="$ROOT/.ruler/AGENTS.md"
  local dst="$ROOT/.opencode/rules/AGENTS.md"

  if [[ ! -f "$src" ]]; then
    echo "[sync] SKIP: $src not found"
    return
  fi

  # dst에서 OpenCode 전용 섹션(--- 구분선 이전)을 추출
  local header
  header=$(awk '/^---$/{exit} {print}' "$dst")

  # 정본(.ruler/AGENTS.md) 내용에서 제목 줄(# AI Coding Agent Rules) 제거 후 합성
  local body
  body=$(tail -n +2 "$src")

  printf '%s\n\n---\n\n%s\n' "$header" "$body" > "$dst"
  echo "[sync] rules: .ruler/AGENTS.md → .opencode/rules/AGENTS.md"
}

sync_agents() {
  local src_dir="$ROOT/.claude/agents"
  local dst_dir="$ROOT/.opencode/agents"

  if [[ ! -d "$src_dir" ]]; then
    echo "[sync] SKIP: $src_dir not found"
    return
  fi

  mkdir -p "$dst_dir"

  for src_file in "$src_dir"/*.md; do
    [[ -f "$src_file" ]] || continue
    local filename
    filename=$(basename "$src_file")
    local dst_file="$dst_dir/$filename"

    # Claude Code 프론트매터를 OpenCode 프론트매터로 변환
    # Claude 형식: name, description, model, memory, tools, maxTurns
    # OpenCode 형식: description, mode, temperature, tools(맵), permissions
    python3 - "$src_file" "$dst_file" <<'PYEOF'
import sys, re

src_path = sys.argv[1]
dst_path = sys.argv[2]

with open(src_path, encoding='utf-8') as f:
    content = f.read()

# 프론트매터 분리
fm_match = re.match(r'^---\n(.*?)\n---\n(.*)', content, re.DOTALL)
if not fm_match:
    # 프론트매터 없으면 그대로 복사
    with open(dst_path, 'w', encoding='utf-8') as f:
        f.write(content)
    sys.exit(0)

fm_text = fm_match.group(1)
body = fm_match.group(2)

# Claude 프론트매터 파싱
fields = {}
for line in fm_text.splitlines():
    if ':' in line:
        k, _, v = line.partition(':')
        fields[k.strip()] = v.strip()

# 기존 dst 프론트매터가 있으면 보존 (이미 OpenCode 형식인 경우)
if dst_path:
    try:
        with open(dst_path, encoding='utf-8') as f:
            dst_content = f.read()
        dst_fm_match = re.match(r'^---\n(.*?)\n---\n(.*)', dst_content, re.DOTALL)
        if dst_fm_match:
            dst_fm = dst_fm_match.group(1)
            # OpenCode 형식 여부 확인 (mode 필드 존재)
            if 'mode:' in dst_fm:
                # 본문만 교체
                new_content = f'---\n{dst_fm}\n---\n{body}'
                with open(dst_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                sys.exit(0)
    except FileNotFoundError:
        pass

# OpenCode 프론트매터 생성
description = fields.get('description', '')
max_turns = fields.get('maxTurns', '30')

# tools 문자열 파싱 → OpenCode 맵 형식
tools_str = fields.get('tools', '')
tool_names = [t.strip() for t in tools_str.split(',') if t.strip()]
tool_map_lines = []
for t in ['Read', 'Write', 'Edit', 'Glob', 'Grep', 'Bash', 'WebFetch', 'WebSearch']:
    enabled = 'true' if t in tool_names else 'false'
    tool_map_lines.append(f'  {t.lower()}: {enabled}')
tools_map = '\n'.join(tool_map_lines)

new_fm = f"""description: {description}
mode: subagent
temperature: 0.1
tools:
{tools_map}
permissions:
  edit: allow"""

new_content = f'---\n{new_fm}\n---\n{body}'
with open(dst_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
PYEOF

    echo "[sync] agents: $filename"
  done
}

case "$MODE" in
  --rules)  sync_rules ;;
  --agents) sync_agents ;;
  --all)    sync_rules; sync_agents ;;
  *)
    echo "Usage: $0 [--agents | --rules | --all]"
    exit 1
    ;;
esac

echo "[sync] done"
