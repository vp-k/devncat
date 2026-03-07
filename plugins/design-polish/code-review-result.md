# 코드 리뷰 결과: design-renewal 명령어 추가 구현

## 요약

> 총 5건 발견 (Critical: 0, High: 1, Medium: 3, Low: 0)
> 검증 후 확인: 4건, 기각: 1건

## 리뷰 범위

- **대상**: design-renewal 명령어 추가 (commands, skills, plugin.json, README)
- **파일 수**: 4개
- **청크 수**: 1개
- **리뷰어**: codex-cli (독립 탐색) -> Claude Code (검증)

## Findings (확인됨)

### High

#### DATA-HIGH-003: 위치 인자 스키마 모호성 — style-keyword/site/keyword 해석 충돌
- **파일**: `commands/design-renewal.md`
- **라인**: 3, 16-18
- **발견자**: codex-cli
- **설명**: argument-hint가 `[style-keyword] [site] [keyword]`로 3개 선택형 위치 인자인데, 단일 인자 입력 시(예: `/design-renewal godly`) "godly"가 style-keyword인지 site인지 판별 기준이 없음. 기존 `/design-polish`는 `[site] [keyword]` 2개여서 문제없었으나, style-keyword 추가로 모호성 발생.
- **코드**:
  ```yaml
  argument-hint: [--analyze|--wcag-only|--no-wcag] [style-keyword] [site] [keyword]
  ```
- **권장 수정**: site allowlist 기반 파서를 SKILL.md에 명시. 알려진 사이트명(mobbin, godly, dribbble, siteinspire, lapa, httpster, savee, behance, awwwards, darkmodedesign, refero, pageflows)과 매칭되면 site로 해석, 아니면 style-keyword로 해석:
  ```yaml
  argument-hint: [--analyze|--wcag-only|--no-wcag] [style-keyword] [site] [keyword]
  ```
  SKILL.md에 파싱 규칙 추가:
  ```
  ## 인자 파싱 규칙
  1. `--` 플래그는 옵션으로 처리
  2. 나머지 위치 인자 중 알려진 레퍼런스 사이트명과 일치하면 → site
  3. site 다음 인자가 있으면 → keyword
  4. site와 매칭되지 않는 첫 번째 인자 → style-keyword
  ```

### Medium

#### SEC-MEDIUM-001: style-keyword의 셸 명령 인젝션 가능성
- **파일**: `skills/design-renewal/SKILL.md`
- **라인**: 86-93
- **발견자**: codex-cli
- **설명**: style-keyword를 search.cjs 인자로 전달하는 bash 예시에서 사용자 입력 검증 규칙이 없음. Claude Code 에이전트가 이 패턴을 따라 실행할 때 셸 메타문자(`;`, `|`, `$()` 등) 포함 입력으로 명령 인젝션 가능.
- **코드**:
  ```bash
  node "${CLAUDE_PLUGIN_ROOT}/scripts/search.cjs" --domain style "glassmorphism"
  ```
- **권장 수정**: SKILL.md에 입력 검증 규칙 추가:
  ```
  ### style-keyword 검증
  style-keyword는 영문자, 숫자, 하이픈만 허용합니다 (`/^[a-zA-Z0-9-]+$/`).
  검증 실패 시 사용자에게 안내 후 재입력 요청.
  ```

#### ERR-MEDIUM-002: --wcag-only / --no-wcag 옵션 분기 로직 미명시
- **파일**: `skills/design-renewal/SKILL.md`
- **라인**: 20-22, 41-64
- **발견자**: codex-cli (원래 HIGH, 검증 후 MEDIUM으로 조정)
- **설명**: 옵션 정의에 `--wcag-only`, `--no-wcag`가 있으나 실행 플로우에 해당 옵션의 분기/조기 종료가 명시되어 있지 않음. design-polish SKILL.md도 동일한 패턴이므로 HIGH에서 MEDIUM으로 조정하되, 명시적 분기 추가 권장.
- **권장 수정**: 실행 플로우 다이어그램 또는 0~4단계 참조 섹션에 분기 명시:
  ```
  ## 옵션별 플로우 분기
  - `--wcag-only`: 0단계 -> 1단계 -> 결과 출력 (1단계 이후 종료)
  - `--no-wcag`: 0단계 -> 1.5단계(1단계 건너뜀) -> 2~7단계
  - `--analyze`: 0~6단계 -> 종료 (7단계 건너뜀)
  ```

#### CODE-MEDIUM-005: 적용 트리거 컨벤션이 design-polish와 불일치
- **파일**: `commands/design-renewal.md`
- **라인**: 3, 13
- **발견자**: codex-cli
- **설명**: design-polish는 기본=분석, `--apply`=적용 패턴. design-renewal은 기본=분석+적용(사용자 확인 후), `--analyze`=분석만. 같은 플러그인 내에서 명령어 체계가 반대여서 사용자 혼란 가능.
- **권장 수정**: 두 가지 방안 중 택일:
  - **A안**: design-renewal도 `--apply` 패턴 채택 (기본=분석, `--apply`=적용)
  - **B안**: 현재 방식 유지하되 README와 커맨드 설명에 차이점을 명확히 안내

## 기각된 Findings

| ID | 제목 | 발견자 | 기각 사유 |
|----|------|--------|----------|
| PERF-MEDIUM-004 | 매 실행 시 design-polish SKILL.md 전체 로딩 | codex-cli | v1.0에서 허용 가능한 수준. SKILL에 핵심 요약(78-84행)이 이미 있어 에이전트가 전체 Read 없이도 진행 가능. 공용 문서 분리는 향후 최적화 사항 |

## 리뷰 통계

| 카테고리 | 발견 | 확인 | 기각 |
|----------|------|------|------|
| Security (SEC) | 1 | 1 | 0 |
| Error Handling (ERR) | 1 | 1 | 0 |
| Data Consistency (DATA) | 1 | 1 | 0 |
| Performance (PERF) | 1 | 0 | 1 |
| Code Consistency (CODE) | 1 | 1 | 0 |
| **합계** | **5** | **4** | **1** |
