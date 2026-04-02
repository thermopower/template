#!/usr/bin/env bash
# Stop hook — Claude 응답이 끝날 때마다 변경사항을 자동 커밋+푸시합니다.
# 변경사항이 없으면 조용히 종료합니다.

# git 저장소 루트로 이동
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
  exit 0
fi
cd "$REPO_ROOT" || exit 0

# 변경사항 확인 (스테이지드 + 언스테이지드 + 미추적)
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  exit 0
fi

# 커밋 메시지 생성: diff 요약 기반
DIFF_STAT=$(git diff --stat HEAD 2>/dev/null | tail -1)
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null | head -5 | tr '\n' ', ' | sed 's/,$//')
UNTRACKED=$(git ls-files --others --exclude-standard | head -3 | tr '\n' ', ' | sed 's/,$//')

# 변경 파일 목록 조합
ALL_CHANGED=""
[ -n "$CHANGED_FILES" ] && ALL_CHANGED="$CHANGED_FILES"
if [ -n "$UNTRACKED" ]; then
  [ -n "$ALL_CHANGED" ] && ALL_CHANGED="$ALL_CHANGED, $UNTRACKED" || ALL_CHANGED="$UNTRACKED"
fi

# type 결정 (파일 경로 기반 휴리스틱)
TYPE="chore"
if echo "$ALL_CHANGED" | grep -qE '\.claude/agents/|\.claude/hooks/|scripts/|CLAUDE\.md'; then
  TYPE="fix"
fi
if echo "$ALL_CHANGED" | grep -qE 'docs/'; then
  TYPE="docs"
fi
if echo "$ALL_CHANGED" | grep -qE 'src/|app/|pages/|components/'; then
  TYPE="feat"
fi

# 커밋 메시지 조합
if [ -n "$ALL_CHANGED" ]; then
  MSG="${TYPE}: checkpoint — ${ALL_CHANGED}"
else
  MSG="${TYPE}: checkpoint"
fi
# 메시지 길이 제한 (72자)
MSG=$(echo "$MSG" | cut -c1-72)

# 민감 파일 제외 후 전체 스테이징
git add --all -- \
  ':!*.env' ':!*.env.*' ':!.env*' \
  ':!**/*.pem' ':!**/*.key' ':!**/*.p12' ':!**/*.pfx' \
  ':!**/secrets.*' ':!**/credentials.*' \
  2>/dev/null || git add --all

# 스테이징된 변경사항이 있을 때만 커밋
if ! git diff --cached --quiet; then
  git commit -m "$MSG" 2>/dev/null
  git push 2>/dev/null || true
fi

exit 0
