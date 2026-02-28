---
description: "코드 리뷰 반복 수행 (리뷰→수정→재리뷰 자동화)"
argument-hint: "[--rounds N | --goal \"조건\"] <scope>"
---

# 코드 리뷰 루프 (Code Review Loop)

코드 리뷰를 **자동 반복** 수행합니다. 리뷰→수정→재리뷰 사이클을 Ralph Loop으로 자동화합니다.
codex-cli(SEC/ERR/DATA)와 gemini-cli(PERF/CODE)가 독립 리뷰, Claude Code가 검증 및 수정.

## 인수

- `$ARGUMENTS` 형식: `[--rounds N | --goal "조건"] [scope]`
- scope는 리뷰 범위 (파일/디렉토리/자연어 설명)

## 실행 모드

| 모드 | 사용법 | 동작 |
|------|--------|------|
| 기본 | `/code-review-loop [scope]` | 3라운드 리뷰→수정 반복 |
| 횟수 지정 | `/code-review-loop --rounds 5 [scope]` | N라운드 반복 |
| 목표 기반 | `/code-review-loop --goal "CRITICAL/HIGH 0개" [scope]` | 목표 달성까지 반복 (최대 10라운드) |

---

## 0단계: Ralph Loop 자동 설정 (최우선 실행)

**이 단계를 가장 먼저, 다른 어떤 작업보다 우선하여 실행합니다.**

### 0-1. 인수 파싱

`$ARGUMENTS`에서 다음을 추출:

1. **모드 결정**:
   - `--rounds N` 있으면 → rounds 모드, targetRounds = N
   - `--goal "조건"` 있으면 → goal 모드, targetRounds = 10 (최대)
   - **둘 다 있으면** → goal 모드 우선, targetRounds = N (--rounds 값을 최대 횟수로 사용)
   - 둘 다 없으면 → rounds 모드, targetRounds = 3 (기본)
2. **scope**: 나머지 인수를 scope로 사용 (없으면 `src/`)

### 0-2. 복구 감지

`.claude-review-loop-progress.json` 파일이 이미 존재하면:
- `status`가 `in_progress`면 → `currentRound`와 `handoff`를 읽고 이어서 진행
- `status`가 `completed`면 → "이미 완료된 리뷰입니다" 안내 후 종료
- 존재하지 않으면 → 새로 시작

### 0-3. `.claude-review-loop-progress.json` 초기화

새로 시작하는 경우, 다음 JSON을 생성:

```json
{
  "mode": "rounds 또는 goal",
  "targetRounds": 3,
  "goal": null,
  "goalMet": false,
  "scope": ["스코프 파일/디렉토리 목록"],
  "currentRound": 0,
  "status": "in_progress",
  "roundResults": [],
  "findingHistory": [],
  "dod": {
    "all_rounds_complete": { "checked": false, "evidence": null },
    "build_pass": { "checked": false, "evidence": null },
    "no_critical_high": { "checked": false, "evidence": null }
  },
  "handoff": {
    "lastIteration": null,
    "completedInThisIteration": "",
    "nextSteps": "Round 1 시작",
    "keyDecisions": [],
    "warnings": "",
    "currentApproach": ""
  }
}
```

findingHistory 각 항목 스키마:
- `id`: finding ID (예: "SEC-CRITICAL-001")
- `file`: 파일 경로
- `line`: 줄번호
- `description`: 문제 설명
- `severity`: "CRITICAL" | "HIGH" | "MEDIUM" | "LOW"
- `category`: "SEC" | "ERR" | "DATA" | "PERF" | "CODE"
- `discoveredInRound`: 최초 발견 라운드
- `status`: "open" | "fixed" | "regressed" | "deferred"
- `fixedInRound`: 수정된 라운드 (null이면 미수정)

### 0-4. `.claude/ralph-loop.local.md` 생성

`.claude` 디렉토리 생성 후, 아래 내용으로 `.claude/ralph-loop.local.md` 작성:

```markdown
---
active: true
iteration: 1
max_iterations: [targetRounds 값]
completion_promise: "REVIEW_LOOP_COMPLETE"
started_at: "[현재 ISO 시간]"
---

`.claude-review-loop-progress.json`을 읽고 상태를 확인하세요.
`handoff` 필드를 먼저 읽어 이전 라운드의 맥락을 복구하세요.

## 리뷰 루프 프로토콜

### 1. 현재 상태 파악
- progress 파일의 `currentRound`, `status`, `handoff` 확인
- `findingHistory`에서 open 상태 finding 파악

### 2. 리뷰 범위 결정
- **라운드 1**: 전체 scope 파일 대상
- **라운드 2+**: 수정된 파일 전체 (`git diff --name-only`). finding 기준 필터링 금지.
  - 이전 라운드 finding 목록은 codex/gemini에게 **참고용으로만** 전달 (범위 제한에 사용 금지)
  - 이를 통해 Claude가 놓친 새로운 이슈를 codex/gemini가 독립적으로 발견 가능

### 3. codex 리뷰 (SEC, ERR, DATA) — 순차 호출 1/2

```bash
codex exec --skip-git-repo-check '## 역할
당신은 보안/에러 처리/데이터 일관성 전문 코드 리뷰어입니다.
아래 파일들을 직접 읽고 3개 관점에서 결함을 탐색하세요.

## 전문 리뷰 관점
1. **Security (SEC)**: 인증/인가 누락, 입력 검증 부재, 민감 정보 노출, SQL injection, XSS
2. **Error Handling (ERR)**: try-catch 누락, 에러 응답 불일치, 에지 케이스 미처리
3. **Data Consistency (DATA)**: 트랜잭션 누락, 스키마 불일치, race condition

## 심각도: CRITICAL / HIGH / MEDIUM / LOW

## 리뷰 대상 파일
[파일 경로 목록 — 라운드 1: progress.scope 전체 / 라운드 2+: 변경된 파일 전체]

## 참고: 이전 라운드에서 알려진 이슈 (라운드 2+에만 포함)
[이전 finding 목록 — 참고용. 이 목록에 없는 새로운 이슈도 반드시 보고하세요]

## 출력 형식 (엄격히 준수)
### {CATEGORY}-{SEVERITY}-{번호}: {제목}
- 파일: {경로}
- 라인: {줄번호}
- 설명: {문제 상세}
- 권장: {수정안}

finding 없으면 "NO_FINDINGS". 마지막 줄: FINDING_COUNT: N'
```

호출 실패 시 재시도 1회 → 여전히 실패 시 Claude가 SEC/ERR/DATA 직접 리뷰.

### 4. gemini 리뷰 (PERF, CODE) — 순차 호출 2/2

```bash
gemini --prompt "## 역할
당신은 성능/코드 일관성 전문 코드 리뷰어입니다.
아래 파일들을 직접 읽고 2개 관점에서 결함을 탐색하세요.

## 전문 리뷰 관점
1. **Performance (PERF)**: N+1 쿼리, 불필요한 DB 호출, 대량 데이터 미처리, 메모리 누수
2. **Code Consistency (CODE)**: 컨벤션 위반, 패턴 불일치, 타입 안전성 부족, 미사용 코드

## 심각도: CRITICAL / HIGH / MEDIUM / LOW

## 리뷰 대상 파일
[파일 경로 목록 — 라운드 1: progress.scope 전체 / 라운드 2+: 변경된 파일 전체]

## 참고: 이전 라운드에서 알려진 이슈 (라운드 2+에만 포함)
[이전 finding 목록 — 참고용. 이 목록에 없는 새로운 이슈도 반드시 보고하세요]

## 출력 형식 (엄격히 준수)
### {CATEGORY}-{SEVERITY}-{번호}: {제목}
- 파일: {경로}
- 라인: {줄번호}
- 설명: {문제 상세}
- 권장: {수정안}

finding 없으면 NO_FINDINGS. 마지막 줄: FINDING_COUNT: N"
```

호출 실패 시 재시도 1회 → 여전히 실패 시 Claude가 PERF/CODE 직접 리뷰.

### 5. Finding 검증
각 finding을 Read 도구로 코드 확인. confirmed/dismissed 판정.
이전 라운드 finding과 대조: 동일 파일 + 라인 범위 겹침(±5줄) + 유사 문제 → same finding.
상태: fixed / regressed / new / open
중복 통합: 동일 이슈는 더 높은 severity 채택, 양쪽 설명 병합.

### 6. CRITICAL/HIGH 자동 수정
confirmed CRITICAL/HIGH finding을 Edit 도구로 코드 수정. MEDIUM/LOW는 deferred.

### 7. 빌드/테스트 검증
프로젝트 빌드 및 테스트 실행. 결과를 `.claude-verification.json`에 기록.

### 8. 라운드 결과 기록
progress 파일의 roundResults, findingHistory, handoff, dod 업데이트.
findingHistory 각 항목 스키마:
```json
{
  "id": "SEC-CRITICAL-001",
  "file": "src/auth.ts",
  "line": 42,
  "description": "SQL injection",
  "severity": "CRITICAL",
  "category": "SEC",
  "discoveredInRound": 1,
  "status": "open|fixed|regressed|deferred",
  "fixedInRound": null
}
```

### 9. 종료 조건 평가
- rounds 모드: currentRound >= targetRounds && 빌드/테스트 통과
- goal 모드: goal 조건 충족 || 수렴 감지 (2라운드 연속 동일 open finding 수)
- 공통: 빌드/테스트 통과 필수 (verification.build == 0 && verification.test == 0)
- CRITICAL/HIGH 0개는 DoD 항목 (체크만, 종료 차단 안 함)

**모든 조건 충족 시**: 최종 리포트 출력 후 `<promise>REVIEW_LOOP_COMPLETE</promise>`

### 규칙
- 자동 진행 (사용자 확인 없이)
- 중간 종료 금지 (리포트 작성 전 종료 불가)
- codex/gemini에게 파일 경로만 전달 (코드 미전달)
- codex → gemini 순차 호출 (병렬 금지)
- 10턴 이상 시 /compact 실행
```

**주의**: `max_iterations`는 rounds 모드면 `targetRounds`, goal 모드면 `10`으로 설정.

---

## 1단계: 스코프 해석 (자연어 → 파일 목록)

scope($ARGUMENTS에서 추출)를 실제 파일 목록으로 변환:

1. **Glob으로 파일 탐색**: scope에 해당하는 파일 패턴 탐색
2. **파일 목록 확정**: 리뷰 대상 파일 경로 목록 생성 (테스트/설정 파일 제외)
3. **progress 파일 업데이트**: `scope` 필드에 확정된 파일 목록 저장, `currentRound` → 1

**스코프 해석 예시:**

| 자연어 입력 | 해석 |
|------------|------|
| `src/` | src/ 하위 주요 소스 파일 |
| `인증 시스템` | auth 관련 파일 탐색 |
| 미지정 | `src/` 전체 |

---

## 2단계: 리뷰 실행 (codex + gemini 3자 리뷰)

**라운드 1**: 전체 scope 파일 대상
**라운드 2+**: 수정된 파일 전체 (`git diff --name-only`). 이전 finding 목록은 **참고용으로만** 프롬프트에 포함 (범위 제한 금지). codex/gemini가 Claude가 놓친 새로운 이슈를 독립적으로 발견할 수 있어야 함.

### codex-cli 호출 (SEC, ERR, DATA 관점)

```bash
codex exec --skip-git-repo-check '## 역할
당신은 보안/에러 처리/데이터 일관성 전문 코드 리뷰어입니다.
아래 파일들을 직접 읽고 3개 관점에서 결함을 탐색하세요.

## 전문 리뷰 관점
1. **Security (SEC)**: 인증/인가 누락, 입력 검증 부재, 민감 정보 노출, SQL injection, XSS
2. **Error Handling (ERR)**: try-catch 누락, 에러 응답 불일치, 에지 케이스 미처리
3. **Data Consistency (DATA)**: 트랜잭션 누락, 스키마 불일치, race condition

## 심각도 기준
- CRITICAL: 보안 취약점, 데이터 손실 가능
- HIGH: 주요 버그, 에러 처리 누락
- MEDIUM: 잠재적 문제, 일관성 위반
- LOW: 사소한 개선, 스타일

## 리뷰 대상 파일
[파일 경로 목록 — 라운드 1: scope 전체 / 라운드 2+: 변경된 파일 전체]

## 참고: 이전 라운드에서 알려진 이슈 (라운드 2+에만 포함)
[이전 finding 목록 — 참고용. 이 목록에 없는 새로운 이슈도 반드시 보고하세요]

## 출력 형식
### {CATEGORY}-{SEVERITY}-{번호}: {제목}
- 파일: {경로}
- 라인: {줄번호}
- 설명: {문제 상세}
- 권장: {수정안}

finding 없으면 "NO_FINDINGS".
마지막 줄: FINDING_COUNT: N'
```

### gemini-cli 호출 (PERF, CODE 관점)

```bash
gemini --prompt "## 역할
당신은 성능/코드 일관성 전문 코드 리뷰어입니다.
아래 파일들을 직접 읽고 2개 관점에서 결함을 탐색하세요.

## 전문 리뷰 관점
1. **Performance (PERF)**: N+1 쿼리, 불필요한 DB 호출, 대량 데이터 미처리, 메모리 누수
2. **Code Consistency (CODE)**: 컨벤션 위반, 패턴 불일치, 타입 안전성 부족, 미사용 코드

## 심각도 기준
- CRITICAL: 심각한 성능 문제, 메모리 누수
- HIGH: N+1 쿼리, 주요 패턴 위반
- MEDIUM: 잠재적 성능 문제, 일관성 위반
- LOW: 사소한 최적화, 스타일

## 리뷰 대상 파일
[파일 경로 목록 — 라운드 1: scope 전체 / 라운드 2+: 변경된 파일 전체]

## 참고: 이전 라운드에서 알려진 이슈 (라운드 2+에만 포함)
[이전 finding 목록 — 참고용. 이 목록에 없는 새로운 이슈도 반드시 보고하세요]

## 출력 형식
### {CATEGORY}-{SEVERITY}-{번호}: {제목}
- 파일: {경로}
- 라인: {줄번호}
- 설명: {문제 상세}
- 권장: {수정안}

finding 없으면 NO_FINDINGS.
마지막 줄: FINDING_COUNT: N"
```

**순차 호출**: codex 완료 후 gemini 호출 (병렬 금지). 두 리뷰어는 서로 결과를 참조하지 않음.

**호출 실패 시**: 재시도 1회 → 여전히 실패 시 Claude가 해당 관점 직접 리뷰.

---

## 3단계: Finding 검증 (Claude Code 판정)

codex와 gemini가 발견한 각 finding을 직접 검증:

### 검증 프로세스

각 finding에 대해:
1. **Read 도구**로 해당 파일의 해당 라인 직접 읽기
2. **판정**:
   - **Confirmed**: 실제 문제. severity 조정 가능.
   - **Dismissed**: false positive, 의도된 설계 → 기각 사유 기록

### 중복 Finding 통합

두 리뷰어가 동일 이슈를 지적한 경우:
- 같은 파일 + 라인 범위 겹침(±5줄) + 문제 유형 유사 → 같은 finding
- 더 높은 severity 채택, 양쪽 설명 병합

### 라운드 간 Finding 매칭 (라운드 2+)

이전 라운드 finding과 대조:
- 동일 파일 + 라인 범위 겹침(±5줄) + 문제 유형 유사 → 같은 finding
- 상태 분류:
  - 이전 `open` → 이번 미발견 → `fixed`
  - 이전 `fixed` → 이번 재발견 → `regressed`
  - 이번 신규 → `new` (status: `open`)
  - MEDIUM/LOW 보류 → `deferred`

### Finding ID 형식

`{CATEGORY}-{SEVERITY}-{번호}` (예: SEC-CRITICAL-001, PERF-HIGH-002)

---

## 4단계: 수정 (CRITICAL/HIGH 자동 수정)

confirmed **CRITICAL** 및 **HIGH** finding을 **Edit 도구**로 자동 수정:

1. 각 finding의 파일과 라인 확인
2. 권장 수정안을 기반으로 코드 수정
3. 수정 결과를 finding status에 반영
4. MEDIUM/LOW는 이 라운드에서 수정하지 않음 (`deferred`)

**수정 원칙:**
- 최소한의 변경으로 문제 해결
- 기존 코드 스타일 및 패턴 유지
- 한 finding 수정이 다른 코드에 영향주지 않도록 주의

---

## 5단계: 수정 후 빌드/테스트 검증

수정 후 프로젝트 빌드 및 테스트 실행:

1. **빌드 검증**: 프로젝트 빌드 명령 실행 (예: `npm run build`, `pnpm build`)
2. **타입 체크**: TypeScript면 `tsc --noEmit`
3. **린트**: `npm run lint` 또는 유사 명령
4. **테스트**: `npm test` 또는 유사 명령

결과를 verification 객체에 기록 (exit code: 0=통과, 비0=실패):
```json
{ "build": 0, "typeCheck": 0, "lint": 0, "test": 0 }
```

**빌드/테스트 실패 시**: 해당 라운드에서 수정 시도. 수정 불가 시 handoff에 기록.

---

## 6단계: 라운드 결과 기록 + 종료 조건 평가

### 6-1. 결과 기록

`.claude-review-loop-progress.json` 업데이트:

- `currentRound` 증가
- `roundResults`에 현재 라운드 결과 추가:
  ```json
  {
    "round": 1,
    "findings": {
      "total": 12,
      "confirmed": 10,
      "dismissed": 2,
      "bySeverity": { "CRITICAL": 1, "HIGH": 3, "MEDIUM": 4, "LOW": 2 }
    },
    "fixes": { "attempted": 4, "succeeded": 4, "failed": 0 },
    "verification": { "build": 0, "typeCheck": 0, "lint": 0, "test": 0 },
    "timestamp": "ISO"
  }
  ```
- `findingHistory` 업데이트 (각 finding의 상태 반영)
- `handoff` 업데이트 (다음 반복을 위한 컨텍스트)

### 6-2. 종료 조건 평가

**횟수 모드** (`mode: "rounds"`):
- `currentRound >= targetRounds` → 종료 조건 충족

**목표 모드** (`mode: "goal"`):
- 목표 조건 파싱:
  - "CRITICAL 0개" → CRITICAL severity open finding 0개
  - "CRITICAL/HIGH 0개" → CRITICAL + HIGH open finding 합계 0개
  - "finding 5개 이하" → 전체 confirmed open finding 5개 이하
- 수렴 감지: 2라운드 연속 open finding 수 동일 → 더 이상 개선 불가, 중단

**공통 조건** (모드 무관):
- 빌드/테스트 통과 필수 (verification의 build/test가 0)

### 6-3. DoD 업데이트

```json
"dod": {
  "all_rounds_complete": { "checked": [종료 조건 충족 여부], "evidence": "Round N/N 완료" },
  "build_pass": { "checked": [빌드 통과 여부], "evidence": "build exit 0" },
  "no_critical_high": { "checked": true, "evidence": "open CRITICAL: N, HIGH: M (정보 기록용, 종료 차단 안 함)" }
}
```

**주의**: `no_critical_high`는 항상 `checked: true`로 설정. 이 항목은 정보 기록용이며 종료를 차단하지 않음. evidence에 실제 수치를 기록.

### 6-4. 종료 또는 계속

**종료 조건** = (rounds 또는 goal 조건 충족) && (빌드/테스트 통과)

- **종료 조건 충족**: → DoD 최종 업데이트, 완료 보고 후 `<promise>REVIEW_LOOP_COMPLETE</promise>` 출력
- **미충족**: → `handoff`에 다음 라운드 안내 기록, 현재 턴에서 종료 (stop-hook이 다음 반복 트리거)

---

## 완료 보고

모든 라운드 완료 후 간결하게 보고:

```
## 코드 리뷰 루프 완료

- **라운드**: N회 수행
- **총 Finding**: X건 발견 → Y건 확인, Z건 기각
- **수정 결과**: A건 수정 (CRITICAL: B, HIGH: C)
- **남은 Finding**: D건 (MEDIUM: E, LOW: F)
- **빌드/테스트**: 통과

### 라운드별 추이
| 라운드 | 발견 | 수정 | 남은 CRITICAL/HIGH |
|--------|------|------|-------------------|
| 1      | 12   | 4    | 0                 |
| 2      | 3    | 1    | 0                 |
| ...    | ...  | ...  | ...               |
```

보고 후 `<promise>REVIEW_LOOP_COMPLETE</promise>` 출력.

---

## 목표 조건 파싱 규칙

`--goal` 인수의 자연어를 파싱:

| 입력 | 해석 |
|------|------|
| "CRITICAL 0개" | CRITICAL open finding 0개 |
| "CRITICAL/HIGH 0개" | CRITICAL + HIGH open finding 합계 0개 |
| "finding 5개 이하" | 전체 confirmed open finding ≤ 5개 |
| "보안 이슈 없음" | SEC 카테고리 open finding 0개 |

**수렴 감지**: 2라운드 연속 open finding 수 동일 → 더 이상 개선 불가로 판단, 루프 중단.

---

## 강제 규칙 (절대 위반 금지)

1. **자동 진행**: 단계 간 사용자 확인 없이 자동 진행
2. **중간 종료 금지**: 모든 라운드 완료/종료 조건 충족 전까지 종료하지 않음
3. **상태 파일 동기화**: 라운드 변경 시 반드시 progress 파일 업데이트
4. **질문 금지**: AskUserQuestion 사용 금지
5. **코드 미전달**: codex/gemini에게 파일 경로만 전달
6. **독립 리뷰**: codex와 gemini는 서로의 결과 참조 금지
7. **순차 호출**: codex → gemini 순서로 순차 호출 (병렬 금지)
8. **handoff 필수**: 매 라운드 종료 시 handoff 필드 업데이트

## 포기 방지 규칙 (강제)

- codex 호출 실패 시 → 재시도 1회, 이후에도 실패 시 Claude가 SEC/ERR/DATA 직접 리뷰
- gemini 호출 실패 시 → 재시도 1회, 이후에도 실패 시 Claude가 PERF/CODE 직접 리뷰
- 파싱 실패 시 → 출력 원문 기반 수동 파싱
- 컨텍스트 부족 시 → `/compact` 실행 후 계속 진행

## 컨텍스트 관리

- 10턴 이상 시 `/compact` 실행
- 청크 전환 시 이전 결과 요약 후 진행
- "prompt too long" 감지 시 즉시 `/compact`
