# Korean Text
코드를 생성한 후에 utf-8 기준으로 깨지는 한글이 있는지 확인해주세요. 만약 있다면 수정해주세요.
항상 한국어로 응답하세요.


코드 수정 작업을 완료한 뒤 commit을 남겨주세요. message는 최근 기록을 참고해서 적절히 작성하세요.

# SOT(Source Of Truth) Design
docs폴더의 문서를 참고하여 프로그램 구조를 파악하세요. docs/external에는 외부서비스 연동 관련 문서가 있으니 필요시 확인하여 파악하세요.

# Functional Programming Principles

모든 코드는 다음 함수형 프로그래밍 원칙을 따릅니다.

## 핵심 원칙
1. **순수 함수**: 같은 입력 → 같은 출력, 외부 상태 변경 금지
2. **불변성**: 데이터 직접 변경 금지, 새 객체 생성 (스프레드 연산자 활용)
3. **선언적 코드**: for/while 대신 map/filter/reduce 사용
4. **함수 합성**: 작은 순수 함수들을 조합

## 적용 방법
- const 선호, let 최소화
- 배열/객체 변경 시 스프레드 연산자 사용
- 루프 대신 Array 메서드 활용 (map, filter, reduce, every, some)
- 조건문보다 객체 매핑이나 삼항 연산자 선호
