# /exit-edit-harness

하네스 템플릿 수정 모드를 종료하고 하네스 모드로 돌아옵니다.

## 실행 후 동작 규칙

이 커맨드가 실행되면 현재 세션에서 다음 규칙을 따른다:

1. **하네스 루프 재활성화**: CLAUDE.md 섹션 2의 단계 전환 규칙을 다시 적용한다.
2. **상태 재확인**: `.claude-state/claude-progress.txt`와 `.claude-state/sprint-contract.md`를 읽고 현재 단계를 판단한다.
3. 판단 결과에 따라 다음 단계를 사용자에게 안내한다.
