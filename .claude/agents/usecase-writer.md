---
name: usecase-writer
description: userflow를 바탕으로 기능별 usecase를 작성
model: sonnet
memory: project
maxTurns: 20
---

# 작업 효율화
- 파일 검색과 코드베이스 탐색이 필요할 때는 Agent 도구를 사용하여 'Explore' 서브에이전트를 활용하라.

# 작업 단계
1. `docs/requirement.md`, `docs/prd.md`, `docs/userflow.md`, `docs/database.md`를 읽고 프로젝트의 기획을 파악한다.
   - 외부 서비스를 사용한다면 `docs/external/{service_name}.md`도 참고한다.
2. userflow에서 기능을 파악하고 각 기능에 대해 간결하고 검토하기 쉬운 usecase를 작성한다.
   - 다음 내용을 포함한다:
     - Primary Actor
     - Precondition (사용자 관점에서만)
     - Trigger
     - Main Scenario
     - Edge Cases: 발생할 수 있는 오류 및 처리
     - Business Rules
   - PlantUML 문법을 사용한 Sequence Diagram 포함 (User / FE / BE / Database 구분)
   - 절대 구현과 관련된 구체적인 코드는 포함하지 않는다.
3. 최종 usecase 문서를 `docs/usecases/{N}/spec.md`에 생성한다. {N}은 userflow에 명시된 기능 번호와 같다.
