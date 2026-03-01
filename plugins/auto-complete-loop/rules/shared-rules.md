# 공통 규칙 (모든 스킬 적용)

## 검증 결과 기록 (필수)
모든 검증(빌드/테스트/린트) 결과는 `.claude-verification.json`에 기록합니다.
증거 없는 완료 선언은 금지입니다.
품질 게이트는 `bash ${CLAUDE_PLUGIN_ROOT}/scripts/shared-gate.sh quality-gate`로 실행합니다.

## DoD 확인
프로젝트 루트의 `DONE.md`가 있으면 반드시 읽고 체크리스트로 사용합니다.
없으면 각 스킬의 내장 완료 기준을 사용합니다 (빌드/테스트/린트/리뷰 통과).
필요 시 `${CLAUDE_PLUGIN_ROOT}/templates/DONE.md` 템플릿을 참고할 수 있습니다.

## Ralph Loop 모드
`.claude/ralph-loop.local.md`가 존재하면 Ralph Loop 모드입니다.
- 한 iteration에서 처리할 작업 단위를 최소화
- Iteration 종료 전 handoff 필드를 반드시 업데이트
- 모든 조건 충족 시에만 <promise> 태그를 출력
- Ralph Loop 파일 생성: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/shared-gate.sh init-ralph <promise> <progress_file> [max_iter]`

## Self-check (완료 선언 전 필수)
1. 원래 요구사항 다시 읽기
2. 구현이 요구사항을 충족하는지 항목별 대조
3. 빌드/테스트를 **지금** 실행 (이전 결과 재사용 금지)
4. 결과를 `.claude-verification.json`에 기록
5. 해당 progress 파일의 dod 체크리스트 업데이트 (evidence 포함)

## Error Classification
- **Fixable** (누락 import, lint, 단순 타입): 즉시 수정, 최대 3회
- **Non-Fixable** (로직, 아키텍처): codex-cli 근본 원인 분석 요청
- 에러 기록: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/shared-gate.sh record-error --file <f> --type <t> --msg <m>`
  - exit 0 = 계속 시도, exit 2 = 3회 초과 → codex 요청, exit 3 = 5회 초과 → 사용자 개입

## 포기 방지
- 5회 실패 전까지 스스로 해결
- 막히면 codex-cli 호출, 그래도 안 되면 완전히 다른 접근법
- "사용자가 직접 확인해주세요" 금지

## 강제 규칙 (모든 스킬 공통)
1. **단일 in_progress**: 동시에 하나의 문서/단계만 `in_progress` 상태
2. **완료 전 진행 금지**: `in_progress` 작업이 `completed` 되기 전 다음 작업 시작 금지
3. **스킵 금지**: 어떤 이유로도 `pending` 작업을 건너뛰지 않음
4. **중간 종료 금지**: 모든 작업이 `completed` 될 때까지 종료하지 않음
5. **상태 파일 동기화**: 상태 변경 시 반드시 progress 파일 업데이트
6. **자동 전환**: 작업 완료 → 다음 작업으로 확인 없이 자동 진행
7. **질문 금지**: 명시적으로 허용된 시점 외에는 AskUserQuestion 사용 금지

## 컨텍스트 관리 (Prompt Too Long 방지)

### 자동 `/compact` 실행 시점
| 조건 | 트리거 |
|------|--------|
| 단일 작업 내 | 12턴 이상 → `/compact` |
| "prompt too long" 에러 | 즉시 `/compact` |
| 작업 전환 시 | 다음 작업 시작 전 `/compact` |

### 에러 감지
- "prompt too long", "context length exceeded" 메시지 감지 시 즉시 `/compact`
- `/compact` 후에도 반복 시:
  1. 현재 진행 상황을 progress 파일에 저장
  2. handoff 필드 업데이트
  3. 세션을 자연스럽게 종료 (Stop Hook이 다음 iteration 자동 시작)

### 메모리 관리
- 각 작업 완료 시 해당 내용은 요약으로만 기억
- 이전 작업의 전체 코드/토론을 누적하지 않음
- 현재 작업에만 집중, 필요시 다른 파일은 다시 읽기

## Handoff 업데이트 (Iteration 종료 전 필수)

progress 파일의 `handoff` 필드를 반드시 업데이트합니다:

```json
"handoff": {
  "lastIteration": N,
  "completedInThisIteration": "이번 iteration에서 완료한 작업 요약",
  "nextSteps": "다음 iteration에서 바로 시작할 작업 + 필요한 맥락",
  "keyDecisions": ["이번 iteration에서 내린 설계 결정과 이유"],
  "warnings": "주의사항, 알려진 이슈, 기술 부채",
  "currentApproach": "현재 사용 중인 아키텍처/패턴/구조"
}
```

**Iteration 시작 시 handoff 읽기:**
1. progress 파일 로드
2. `handoff.nextSteps`를 최우선으로 확인 → 여기서 시작
3. `handoff.keyDecisions`로 이전 결정 맥락 복구
4. `handoff.warnings`로 주의사항 인지
5. `handoff.currentApproach`로 진행 구조 맥락 복구

## 외부 AI 자체 탐색 (codex/gemini 호출 시)
- codex/gemini에게 **파일 경로**를 전달하여 직접 읽도록 함
- Claude가 문서 내용을 요약/가공하여 프롬프트에 embed하지 않음 (요약 편향 방지)
- 코드 전체가 아닌 **핵심 부분만** 전달 (최대 100줄)
- 이전 토론 내용은 결론만 요약해서 전달

## 증거 기반 완료 선언 (필수)

**완료 선언 전 반드시 실행 결과 확인:**
- 빌드 성공 로그 (exit code 0 확인)
- 테스트 통과 로그 (PASSED 개수 확인)
- 린트 통과 로그
- `.claude-verification.json`에 기록 완료
- progress 파일의 dod 체크리스트 전체 checked + evidence 포함

**금지 (실행 없이 선언):**
- "아마 통과할 것입니다"
- "테스트가 성공할 것입니다"
- 이전 실행 결과 재사용

**원칙:** evidence 없으면 checked=true 불가. 로그 없으면 완료 없음.
