# Auto Complete Loop

AI 코딩 완주 프레임워크. Ralph Loop 내장 + DoD/SPEC/TDD/Fresh Context Verification으로 AI가 끝까지 완성하도록 강제합니다.

## 설치

Claude Code 플러그인으로 설치:
```bash
claude plugins install /path/to/auto-complete-loop
```

설치 후 기존 `~/.claude/commands/`의 동명 파일(implement-docs-auto.md, plan-docs-auto-v2.md, polish-for-release-v2.md)을 삭제하세요 (충돌 방지).

## 명령어

### `/implement-docs-auto <definition> <doclist>`
기획 문서를 실제 코드로 구현합니다. Ralph Loop이 자동 활성화되어 완료까지 반복합니다.

### `/plan-docs-auto-v2 <definition> <doclist>`
기획 문서를 3자 자동 토론(codex-cli, Gemini, Claude Code)으로 완성합니다.

### `/polish-for-release-v2 [definition] [doclist]`
프로덕션 릴리즈 전 폴리싱을 수행합니다.

### `/code-review-loop [--rounds N | --goal "조건"] <scope>`
코드 리뷰를 자동 반복 수행합니다. codex-cli(SEC/ERR/DATA) + gemini-cli(PERF/CODE) 독립 리뷰 후 Claude Code가 검증/수정.
- 기본: 3라운드 리뷰→수정 반복
- `--rounds N`: N라운드 반복
- `--goal "CRITICAL/HIGH 0개"`: 목표 달성까지 반복 (최대 10라운드)

## 핵심 메커니즘

### Ralph Loop 내장
- Stop Hook이 세션 종료를 물리적으로 차단
- completion-promise + 검증 파일(.claude-verification.json)로 거짓 완료 방지
- Iteration 단위 작업 분할로 컨텍스트 고갈 방지

### 5원칙 통합
1. **DoD (Definition of Done)**: DONE.md 템플릿으로 완료 기준 명확화
2. **SPEC**: SPEC.md 템플릿으로 구현 기준 명확화
3. **티켓 분할**: 문서를 독립 검증 가능한 티켓으로 분할
4. **Fresh Context Verification**: 별도 AI가 fresh context에서 검증
5. **Handoff**: Iteration 간 맥락(왜/어떻게) 전달

## 파일 구조

```
auto-complete-loop/
├── .claude-plugin/plugin.json           # 플러그인 메타데이터
├── commands/
│   ├── implement-docs-auto.md           # 기획 문서 → 코드 구현
│   ├── plan-docs-auto-v2.md             # 기획 문서 3자 토론 완성
│   ├── polish-for-release-v2.md         # 릴리즈 전 폴리싱
│   └── code-review-loop.md             # 코드 리뷰 자동 반복
├── hooks/
│   └── stop-hook.sh                     # Stop hook (Ralph Loop 확장)
├── rules/shared-rules.md               # 모든 스킬 공통 규칙
├── templates/                           # DONE.md, SPEC.md 템플릿
└── README.md
```
