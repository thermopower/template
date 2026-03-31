# Claude Code App Generation Harness

Claude Code로 앱을 자동 생성하는 하네스 템플릿입니다.  
요구사항을 입력하면 planner → sprint-builder → evaluator → reviewer → retrospective 루프로 앱을 생성하고 스스로 학습합니다.

---

## 시작하기

### 1. 템플릿 복사

이 저장소를 새 프로젝트의 루트에 복사합니다.

```bash
git clone <this-repo> my-project
cd my-project
```

### 2. Claude Code로 세션 시작

```bash
claude
```

세션이 시작되면 하네스가 현재 상태를 자동으로 감지하고 다음 단계를 안내합니다.

### 3. 요구사항 수집 (requirement-writer)

`docs/requirement.md`가 비어있으면 requirement-writer가 자동으로 실행됩니다.  
아래 3가지를 대화로 수집합니다:

1. **프로젝트 목표** — 어떤 서비스인지, 핵심 사용자, 핵심 가치
2. **기술 스택** — 프레임워크, DB, 인증, 결제, 외부 API
3. **핵심 기능 명세** — MVP 기능 목록과 동작 방식

요구사항을 직접 작성하고 싶다면 `docs/requirement.md`에 미리 채워두면 이 단계를 건너뜁니다.

### 4. 이후는 자동

요구사항이 준비되면 하네스가 아래 순서로 진행합니다.  
각 단계는 Claude Code 에이전트가 담당합니다.

```
requirement-writer  → docs/requirement.md 작성
       ↓
    planner         → 설계 문서 + sprint-contract 초안 생성
       ↓ [사용자 승인]
 sprint-builder     → 코드 구현
       ↓
   evaluator        → pass/fail 판정
       ↓ fail
integration-fixer   → 환경/의존성 복구
       ↓ pass
    reviewer        → 품질 비평 및 개선 제안
       ↓
 retrospective      → 지표 수집, learnings 누적
       ↓ 임계점 도달 시
   /improve         → 에이전트·정책 자동 개선
```

> **사용자 승인이 필요한 시점은 2곳입니다:**
> - planner 완료 후 sprint-contract 범위 확인
> - policy-updater의 개정안 적용 전

---

## 디렉터리 구조

```
.
├── CLAUDE.md                   # 하네스 운영 규칙 (매 세션 자동 로드)
├── docs/
│   ├── requirement.md          # 요구사항 (여기서 시작)
│   └── harness-reference.md    # 에이전트·파일·훅 빠른 참조
├── .claude/
│   ├── agents/                 # 에이전트 프롬프트
│   │   ├── requirement-writer.md
│   │   ├── planner.md
│   │   ├── sprint-builder.md
│   │   ├── evaluator.md
│   │   ├── reviewer.md
│   │   ├── integration-fixer.md
│   │   ├── retrospective.md
│   │   └── policy-updater.md
│   ├── hooks/                  # 자동 실행 훅
│   │   ├── session-start.sh    # 세션 시작 시 상태 감지
│   │   ├── check-smoke.sh      # sprint-builder 종료 전 검증
│   │   ├── trigger-retrospective.sh
│   │   └── check-output.sh
│   └── settings.json           # 훅 설정
├── .claude-state/              # 하네스 상태 파일 (자동 관리)
│   ├── claude-progress.txt     # 현재 상태, blocker, 다음 액션
│   ├── sprint-contract.md      # sprint 범위 및 승인 상태
│   ├── evaluation-report.md    # evaluator 판정 결과
│   ├── review-notes.md         # reviewer 비평 내용
│   ├── learnings.md            # sprint별 누적 학습
│   └── metrics.json            # 정량 지표
├── scripts/
│   ├── smoke                   # 빌드 + 타입체크
│   ├── unit                    # 단위 테스트
│   ├── e2e                     # E2E 테스트
│   ├── evaluation-gate         # 전체 평가 게이트
│   ├── collect-metrics.sh      # metrics.json 갱신
│   └── check-thresholds.sh     # 개선 임계점 판정
└── profiles/
    └── <stack>/scripts/        # 스택별 smoke·unit·e2e 스크립트
        ├── smoke
        ├── unit
        └── e2e
```

---

## 주요 명령

| 명령 | 설명 |
|---|---|
| `claude` | 세션 시작, 현재 단계 자동 감지 |
| `/improve` | 누적 learnings 기반으로 에이전트·정책 자동 개선 |

---

## 지원 스택

planner가 요구사항을 분석해 아래 스택 중 하나를 자동 선택하고 검증 스크립트를 생성합니다.

| 스택 | profile 이름 |
|---|---|
| Next.js + Supabase | `nextjs-supabase` |
| Next.js | `nextjs` |
| React + Vite | `react-vite` |
| Python FastAPI | `fastapi` |
| 기타 | `generic` |

---

## 상세 참조

에이전트 역할, 상태 파일, 훅, 임계점 등 전체 구조는 [`docs/harness-reference.md`](docs/harness-reference.md)를 확인하세요.
