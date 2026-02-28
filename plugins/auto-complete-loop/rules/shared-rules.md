# 공통 규칙 (모든 스킬 적용)

## 검증 결과 기록 (필수)
모든 검증(빌드/테스트/린트) 결과는 `.claude-verification.json`에 기록합니다.
증거 없는 완료 선언은 금지입니다.

## DoD 확인
프로젝트 루트의 `DONE.md`가 있으면 반드시 읽고 체크리스트로 사용합니다.
없으면 각 스킬의 내장 완료 기준을 사용합니다 (빌드/테스트/린트/리뷰 통과).
필요 시 `${CLAUDE_PLUGIN_ROOT}/templates/DONE.md` 템플릿을 참고할 수 있습니다.

## Ralph Loop 모드
`.claude/ralph-loop.local.md`가 존재하면 Ralph Loop 모드입니다.
- 한 iteration에서 처리할 작업 단위를 최소화
- Iteration 종료 전 handoff 필드를 반드시 업데이트
- 모든 조건 충족 시에만 <promise> 태그를 출력

## Self-check (완료 선언 전 필수)
1. 원래 요구사항 다시 읽기
2. 구현이 요구사항을 충족하는지 항목별 대조
3. 빌드/테스트를 **지금** 실행 (이전 결과 재사용 금지)
4. 결과를 `.claude-verification.json`에 기록
5. 해당 progress 파일의 dod 체크리스트 업데이트 (evidence 포함)

## Error Classification
- **Fixable** (누락 import, lint, 단순 타입): 즉시 수정, 최대 3회
- **Non-Fixable** (로직, 아키텍처): codex-cli 근본 원인 분석 요청

## 포기 방지
- 5회 실패 전까지 스스로 해결
- 막히면 codex-cli 호출, 그래도 안 되면 완전히 다른 접근법
- "사용자가 직접 확인해주세요" 금지
