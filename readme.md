# 앱 이름

> 이 저장소는 **Claude Code 하네스 + 앱 코드**가 공존하는 구조입니다.

---

## 구조 설명

```
.
├── .claude/              # Claude Code 설정 및 AI 에이전트 정의 (하네스)
├── .claude-state/        # Sprint 진행상황, 학습 누적, 하네스 버전 (하네스)
├── .ruler/               # 코딩 원칙 (하네스)
├── docs/                 # 설계 문서 - planner가 자동 생성 (하네스→앱)
├── scripts/              # 테스트 실행 스크립트
├── src/                  # 앱 코드 ← 여기가 실제 앱
├── CLAUDE.md             # 하네스 운영 규칙
└── readme.md
```

`.claude/`, `.claude-state/`, `.ruler/`, `CLAUDE.md` 는 하네스 파일입니다.
`src/`, `docs/` 아래 생성된 파일들이 앱 결과물입니다.

---

## 하네스 사용법

### 새 앱 시작

1. 이 저장소를 복사해 새 저장소 생성
2. `docs/requirement.md` 에 요구사항 작성
3. Claude Code 실행 → 자동으로 planner → sprint-builder → evaluator 루프 진행

### 루프 단계

```
requirement.md 작성
    → planner (설계 문서 + sprint-contract 생성)
    → 사용자 승인
    → sprint-builder (구현)
    → evaluator (pass/fail)
    → reviewer (품질 개선 제안)
    → retrospective (학습 누적)
    → 다음 sprint
```

### 하네스 업데이트

`.claude-state/harness-version.md` 에서 현재 버전 확인.
에이전트 개선 시 `.claude/agents/` 파일 수정 후 버전 업.

---

## 요구사항

`docs/requirement.md` 참고
