# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

This is `devncat` — a **Claude Code plugin marketplace** that bundles seven plugins as git submodules under `plugins/`. It is NOT a Flutter application itself; it provides Claude Code skills/commands for Flutter development and other workflows.

GitHub: `vp-k/devncat`

## Repository Structure

```
.claude-plugin/marketplace.json   # Marketplace manifest (lists 7 plugins)
plugins/
├── flutter-craft/                 # Git submodule → vp-k/flutter-craft
├── design-polish/                 # Git submodule → vp-k/design-polish
├── auto-complete-loop/            # Git submodule → vp-k/auto-complete-loop
├── godot-craft/                   # Git submodule → vp-k/godot-craft
├── multi-ai-roundtable/           # Git submodule → vp-k/multi-ai-roundtable
├── product-discovery/             # Git submodule → vp-k/product-discovery
└── open-reach/                    # Git submodule → vp-k/open-reach
```

## Plugins

### flutter-craft (v1.4.2)
Flutter Feature-Driven Development with Clean Architecture. Provides a full workflow: brainstorm → plan → execute → verify → finish. Enforces Clean Architecture layer order (domain → data → presentation) and priority-based testing (Repository → State → Widget).

Key commands: `/brainstorm`, `/plan`, `/execute`

### design-polish (v2.5.0)
Design polishing with WCAG accessibility checks. Has a built-in BM25 search engine over design knowledge (66 styles, 96 palettes, 57 typography pairings). Requires `npm install` for puppeteer + axe-core. v2.2.0에서 측정 엔진 확장 — Health Score의 styleFit·performance가 고정 상수에서 **실측값**으로 전환(렌더 DOM 일관성 계측 + navigation/paint/resource timing), 계측(`page.evaluate`)과 순수 스코어러(`scoreConsistency`/`scorePerformance`) 분리로 결정적·단위테스트 가능(`npm test`), 모바일 axe 패스 + 터치 타겟(44px) 자동 감사, `--apply` 후 **close-the-loop 검증**(재캡처→before/after diff→회귀 시 롤백, renewal은 `design-renewal-backup` 브랜치 선생성), append-only `health-history.jsonl`(회귀·정체 감지), 라우트 자동 발견. v2.3.0에서 design-renewal이 전면 적용 前에 **동일 플래그 baseline 캡처를 필수 절차로 강제** — close-the-loop가 mode/route 일치 baseline과 before/after를 비교할 수 있게 보장(baseline 누락 시 `regression=null`로 떨어져 회귀 판정 불가였던 공백 차단), baseline 실패 시 백업 기반 수동 롤백으로 명시적 폴백. v2.4.0에서 v2.2.0 코드 리뷰 반영 — 콘솔 에러가 반응형 다중 뷰포트·모바일 재방문에 걸쳐 **중복 카운트되어 점수를 왜곡하던 버그 수정**(스코어링 직전 신원 기준 dedupe), 회귀 판정에 **dead-band(±3)** 도입(perf 계측 지터로 인한 거짓 regression→불필요 롤백 방지, `classifyRegression` 순수 함수·결정론적), `Number.isFinite` NaN 가드, design-renewal 백업 하드닝(`git stash create`는 untracked 미포함·GC 대상임을 명시→`git stash store` 고정+untracked는 파일 복사 백업 강제, baseline은 동일 cwd 요건 추가). 순수 스코어러 단위테스트 26종. v2.5.0에서 **디자인 계약(design contract) 도입** — 매 실행마다 디자인 시스템을 새로 유도하고 버리던 구조를 끊고 `.design-polish/DESIGN.md`(왜) + `design-decisions.json`(기계 검사 가능한 허용 토큰 집합)로 **영속화**, design-renewal이 계약 저장을 필수 절차(5-7단계)로 수행. 렌더 DOM에서 계약 위반을 계측하는 **토큰 드리프트 린트**(색/간격/모서리/폰트/그림자 — 표기 정규화 후 대조)와 **래칫**(`token-baseline.json`: 첫 실행 시 기존 위반을 동결, 이후 **신규** 위반만 CRITICAL로 승격 → 브라운필드 도입이 교착되지 않음), 히스토리 `styleMode` 태깅(heuristic↔contract 점수 체계 교차 비교로 인한 거짓 회귀 차단), 한국어 타이포(serif fallback·keep-all·자간)와 컴포넌트 상태(disabled·focus·cursor) 자동 감사, 그리고 **번호가 붙은 실패 규칙**(`knowledge/failure-rules.md` — DP-T/K/S/A/U/C 네임스페이스, append-only)로 "서술형 지적" 대신 규칙 ID 인용을 강제. 단위테스트 68종(28+40).

Key commands: `/design-polish`, `/design-renewal`

### auto-complete-loop (v4.17.0)
AI coding completion framework with Ralph Loop + DoD/SPEC/TDD verification. Orchestrates full project lifecycle: PM Planning → Doc Planning → Implementation → Code Review → Verification.

Key command: `/full-auto <requirements>` (runs all phases), plus standalone commands like `/plan-docs-full` (PM + Doc planning only with 4 strict gates), `/code-review-loop`, `/plan-docs-auto`, `/implement-docs-auto`

리뷰 모드: `solo`(Claude 서브에이전트 3개 병렬, 폴백 순차) / `codex`(기본, Claude+codex 2자) / `dual`(codex 2회 분할 병렬 독립 리뷰+Claude, 3자) / `teams`. v3.0.0에서 종료된 gemini CLI를 `dual`로 교체, v3.1.0에서 리뷰 프롬프트 단일화·quality-gate 캐시·템플릿 lazy-load·stop-hook 하드닝, v4.0.0에서 제품 발견 도구를 product-discovery 플러그인으로 분리(BREAKING: `/interview-*`, `/post-analysis` 제거) + solo/dual 병렬화 + admin.sh 모듈 분할, v4.1.0에서 하드 게이팅 배선 완성 — 기획 게이트·live-testing·레이어 커버리지·코드리뷰 finding이 verification.json 기록을 거쳐 stop-hook에서 결정적으로 차단(fail-closed), 자기신고 DoD 제거, 스펙 공백 시 임의 구현 금지 절차, runtime-gate(서버 1회 기동 통합 검증), verification-auditor fresh-context 교차 감사 배선. v4.2.0에서 인수 테스트 선작성+동결(TDD red→green) — 기획 Phase가 SPEC AC로부터 실행 가능한 인수 테스트(`tests/acceptance/`)를 생성해 해시 동결(`acceptance-freeze`), 구현 Phase는 수정 불가(훅 차단+`acceptance-gate` 해시 무결성), 완주하려면 동결된 테스트 green 필수. 스펙 변경은 사용자 승인 → `--approved-by-user` 재동결(이력 기록)로만. v4.3.0에서 verification.json 조작 차단(Edit/Write block + Bash 쓰기 가드) + lesson 메모리 루프("기억은 다음 실행 조건": 3-strike·L3+ 에스컬레이션·완주 교훈을 `.claude/acl-learnings.local.md`에 기록, session-start가 다음 세션에 주입) + SOFT 게이트 2연속 fail→HARD 승격. v4.4.0에서 4-렌즈 독립 감사(E2E 완주 스모크·셸 견고성·계약 전수·훅 상호작용) 수정 — 훅 입력 stdin 규약(promise 감지 복구+무한루프 탈출), DoD setter 부재 데드락 해소, jq 원자성 self-heal, 권한 프롬프트 우회 제거, 비플러그인 프로젝트 오탐 게이팅, E2E 하드 트랩(루트 404 서버·SPEC 부정 케이스) 해소, Bash 훅 단일 디스패처 통합. v4.6.0에서 `/check-docs` 현행화 — doc-consistency/doc-code-check가 dod·verification.json 자동 기록(모델 직접 세팅 금지, doc-check 템플릿에 `no_definition_conflict` 추가), 1단계에 definition-conflict·clarification-gate 편입([NEEDS-CLARIFICATION] 잔존 시 AskUserQuestion 예외), handoff-update 서브커맨드 사용, `--mode solo`(fresh-context 서브에이전트) 지원, 보호 파일 가드 차단 시 절차 명문화. v4.7.0에서 ouroboros 벤치마킹 6종 — `provenance-gate`(SPEC 핵심 섹션 출처 4분류 마커: user-fact/repo-fact/assumption/blocker, unsafe 도메인 assumption 금지, plan-docs-full 게이트 7종으로 확장), 막힘 패턴 감지 확장(3-strike 연속 판정 교정 + OSCILLATION·DIMINISHING_RETURNS, 정규화 해시, 패턴별 LESSON), `review-escalation-check`(L2+/범위 축소/재동결 트리거 시 dual/roundtable 승격 리뷰 의무, stop-hook fail-closed), TOO_BIG 문서 분할(record-error exit 4 → `doc-split record`, L4 전 단계, 깊이 1 제한), spec-completeness 4차원 명확성(Goal/Constraints/SC/Context + SPEC에 Context 섹션), append-only 이벤트 로그(`.claude/acl-events.jsonl`, 관측 전용). v4.8.0에서 SPEC 해시 동결 — acceptance-freeze가 SPEC 파일 해시를 manifest에 함께 동결하고 acceptance-gate가 대조, 게이트 통과 후 SPEC을 몰래 수정하는 세탁 차단(해시 갱신은 사용자 승인 재동결로만, pre-4.8 manifest는 skip 하위호환). v4.9.0에서 gajae-code 벤치마킹 — 리뷰 소스 해시 귀속(`source-hash` 서브커맨드, 각 리뷰 라운드가 캡처한 지문을 code-review-findings가 현재 상태와 대조해 리뷰 후 무리뷰 변경 차단 — 동결 3부작 완성) + 리뷰 래칫 5규칙(라운드 2+ delta-only·novelty justification·verdict monotonicity·severity scoping·dual counter-review). v4.10.0에서 ouroboros/gajae deep-interview 벤치마킹 — 명확성 선행 인터뷰(`ambiguity-score` 서브커맨드): Phase 0 문서 작성 前에 4차원(Goal .30/SuccessCriteria .25/Constraints .25/Context .20) 명확도를 AI가 채점하고 스크립트가 가중 합성점수를 결정론적으로 계산(채점=AI, 산술·판정·기록=스크립트, "프롬프트 임의 해석"을 게이트로 고정), composite ≥0.8 AND 모든 차원 ≥0.6(floor 맹점 차단) 통과 전까지 가장 약한 차원을 공략하는 인터뷰 루프. 개입 최소 원칙(사용자 주의 > 모델 토큰): repo-fact는 서브에이전트 auto-research로 자동 확인(사용자 안 부름), safe assumption 자동 기록, user-fact/blocker만 batch-ask 1회. max-rounds(3) 도달 시 잔여를 `[NEEDS-CLARIFICATION]`로 이관해 clarification/provenance-gate가 최종 fail-closed 차단. 거짓 고득점은 Phase 1 완료 시 spec-completeness가 같은 4축을 파일 기반으로 재검증해 backstop. v4.11.0에서 fresh-context 코드 리뷰 반영 — 게이트 fail-open 3종 차단(protect-files-guard가 teams progress 파일도 보호, acceptance-gate가 total>0 AND passed==total 강제해 스텁 러너 통과 차단, code-review-findings severity 대소문자 정규화로 소문자 critical 탈출 차단), stop-hook 하드닝(set -e 하 iteration 갱신 실패 시 block-continue 보장, jq 부재 우회 감사 기록, assistant grep 공백 내성), 포터빌리티·원자성(shared-gate bash4+ 조기 안내, atomic write 동일 디렉토리 temp, acceptance/SPEC 해시 CRLF 정규화). v4.11.1~4.11.3에서 block-no-verify 가드를 인용/백슬래시/세그먼트를 존중하는 실제 셸 토크나이저로 재작성(다중 라인 커밋 메시지 오탐 + `git commit -nm` 결합 단축 플래그 미탐 동시 해소, `bash-guards.bats` 16종)하고 잔존 미등록 사본 `block-no-verify.sh`를 삭제. v4.12.0에서 "애매한 채로 반복" 실패 모드 봉쇄 3종 — (1) 착수 전 명확화(`ambiguityScore`)를 stop-hook fail-closed 집합에 편입(`pass`|`escalated`만 허용, 키 부재=인터뷰 통째 스킵→차단; full-auto·plan-docs-full 양쪽) + spec-completeness가 자기신고↔파일 재검증 세탁을 교차검증(신고 ≥floor 0.6인데 실측 약한 차원 → `gate.ambiguity.mismatch` 이벤트·경고, 관측 전용), (2) session-start가 `acl-events.jsonl`을 소비해 성공 시 초기화되는 stuck-pattern이 놓치는 **교차 실행 반복**(반복 오류 타입 ≥3회·명확성 세탁·L4/L5 심층 에스컬레이션)을 다음 세션 경고로 주입(문서 힌트 없이 events만 있어도 emit), (3) exit-4 문서 분할 요구(`pendingSplit`)를 stop-hook fail-closed로 승격(분할·L4 전이 없이 완주 차단). bats 169/169. v4.13.0에서 **디자인 계약 강제** — SPEC이 "무엇을"의 계약이라면 `docs/DESIGN.md`는 "어떤 인상을"의 계약이다. `hasFrontend=true`면 doc-planning Step 1-0이 `templates/DESIGN.md`를 필수 문서로 복사(lazy-load 규칙 동일)하고 Step 1-9가 존재를 검증하며, `spec-completeness`가 미생성·템플릿 잔존·**제품 성격/브랜드 섹션의 `assumption` 마커**(추측한 성격은 전 화면에 전파되어 되돌리기가 가장 비싸므로 `user-fact`|`blocker`만 허용)를 MAJOR로 잡는다. 구조적 결정은 기존 `docs/adr/`에 남겨 번호 체계를 새로 만들지 않는다. 구현 Phase는 색·간격·모서리·폰트·상태 표현을 "자유 구현 세부"가 아닌 **동작 계약**으로 취급해 DESIGN.md에 없는 값을 코드에 먼저 넣는 것을 금지. `UI States` 표가 있어도 `AC-F-*`에 빈/로딩/에러/유효성이 하나도 반영되지 않으면 MAJOR(동결 인수 테스트가 happy path만 검증하는 공백 차단). design-polish 계약이 설정된 프로젝트에서는 `design-polish-gate`가 `tokenDrift`(total/new)를 verification.json에 기록하고 **신규** 위반만 pass→soft_fail 강등(`--strict`는 fail) — 기존 부채는 래칫으로 동결. bats 186/186. v4.14.0에서 doc-consistency 수치 검사를 교체 — 기존 [5]는 문서 전체에서 같은 단위가 다른 값으로 나오면 그 개수만큼 hard fail 시켰으나 "실패 사유 11개"와 "인수 테스트 8개"는 서로 다른 것을 세는 정상 문장이라 무언가를 세는 모든 문서 세트에서 구조적으로 통과 불가능했다(plan-docs-full DoD 데드락). 숫자를 마스킹한 문장을 키로 삼아 **같은 문장이 다른 숫자로 반복되는 경우만** CONFLICT로 계상하도록 바꾸고(복붙 드리프트 정조준, 20자·3토큰 미만 제외, 동일 키 1건 계상), 단위 스프레드는 INFO로 강등(판단 필요 시 `numericAudit` 기록). bats 195/195. v4.15.0에서 리뷰 루프 발산 차단 — full-auto Phase 3 완료 조건 "Critical/High/**Medium** 0개(라운드 제한 없음)" + "Medium 즉시 수정(스킵 금지)" + 재기록 라운드 규칙(v4.9.0)의 조합이 리뷰→의무 수정→소스 변경→재기록 라운드→수정분에서 새 MEDIUM의 무한 연쇄를 만들던 것을 standalone `/code-review-loop` 정책(C/H만 하드, MEDIUM deferred, 라운드 상한)에 정렬: 하드 조건은 open CRITICAL/HIGH 0개만(게이트 `code-review-findings` 계수 기준과 일치), MEDIUM/LOW는 라운드 3+부터 `deferred` 백로그(완료 비차단), **라운드 상한 5**(도달 시 C/H 잔존이면 에스컬레이션 — 상한을 이유로 C/H deferred 금지), **수렴 라운드 규칙**(신규 finding이 MEDIUM/LOW뿐이면 수정 없이 deferred 기록 → 소스 불변 → sourceHash 정합 자동 충족·즉시 완료 — 재기록 라운드 연쇄의 종료점). teams 모드(team-code-review)·implement-docs-auto("피드백 없을 때까지 반복"→C/H 0 기준)·phase-transition DoD evidence 동일 정렬. 문서 정책 변경만으로 게이트 스크립트는 원래 C/H만 세므로 무변경. v4.16.0에서 v4.15.0 fresh-context 리뷰 9건 반영 — (1) 수렴 라운드를 **라운드 3+·재기록 라운드로 한정**(라운드 1~2는 Medium 즉시 수정 우선 → 1라운드 무수정 완주 구멍 봉쇄, "즉시 완료"는 추가 리뷰 라운드 불요의 의미일 뿐 품질/E2E 게이트·escalation pending은 여전히 필수), (2) 상한을 "**수정이 발생한 라운드 5회**"로 재정의 — 확인 전용(수정 0건) 라운드·귀속용 재기록 라운드는 상한 비포함(재기록 라운드가 게이트 필수 절차인데 상한에 막히는 데드락 해소), 예산 소진 후 C/H 잔존 시 `record-error --type REVIEW_ROUND_CAP --level L2`로 review-escalation 트리거를 명시 배선(승격 라운드는 상한 예외), (3) **게이트 결정론 백스톱**: code-review-findings가 deferred/regressed CRITICAL/HIGH를 open으로 계수(상태값 세탁 차단, MEDIUM/LOW deferred는 비차단 유지) + interactive Acknowledge의 C/H는 dismissed 경로로 변경, (4) C/H→M/L **severity 강등에 사유 기록 의무**(`severityAdjustments`) + 강등분은 그 라운드 수렴 판정에서 원 severity 취급(강등 세탁 차단), (5) regressed C/H 완료 차단 명문화, findingHistory status enum 5값 통일, implement-docs-auto 리뷰 사이클 상한 5회 + M/L 3회 규칙 일원화. bats 199/199. v4.17.0에서 오픈 딜레이 유발 지점 8건 제거 — (1) 문서 합의 루프 조기 종료: doc-planning/solo/plan-docs-auto/polish-for-release 수렴 기준을 "신규 C/H 0건 라운드에서 즉시 합의"로 통일(최소 라운드 하한·확정 문서 재검토 라운드 제거, 1라운드 수렴 정상), 표준 템플릿 문서(logging-standard·error-policy·security-authn-authz·DESIGN.md)는 1라운드 상한, (2) **규모 비례 호출**: projectSize=Small이면 Phase 0-7 roundtable(codex 단독 대체)·Phase 1-6 아키텍처 리뷰·0→1/2→3 Director를 스킵(`SKIPPED_SMALL`/`directorSkipped` 증거를 outputs에 기록, 1→2/3→4는 항상 호출), (3) Step 2-2.5 AI 호출 제거 — AC를 SPEC+동결 테스트에서 직접 매핑(횡단 문서는 빈 배열 정상) + Step 2-4 문서당 리뷰를 C/H 전용 1사이클로 축소(M/L은 Phase 3 위임), (4) Step 4-2 codex 보안 리뷰를 Phase 3 SEC finding 이력 있을 때만으로 조건부화(secret-scan·vuln-scan은 무조건), (5) **Step 4-6.8 최종 델타 리뷰 신설** — 소스 지문이 HEAD를 포함해 Phase 4 폴리싱 커밋마다 code-review-findings가 stale FAIL하던 배선 공백을 "잔여 변경 전부 커밋 → 지문 대조 → 다르면 델타 리뷰 1회(재기록 라운드)"로 선제 해소, C/H 수정 커밋 시 acceptance-gate(+런타임 변경 시 runtime-gate) 재실행, 4-7c 말미 자동 커밋을 커밋 가드로 교체(리뷰 후 무리뷰 커밋 금지), 4-8 version bump는 버전 파일 한정 커밋으로 불변식 명시 예외, (6) Step 4-7.5 감사를 모델 기록분으로 축소 — write-guard된 fail-closed 키는 존재 확인만, 소프트 차원 evidence·DoD evidence·SPEC US spot-check·**Test Plan P0 전수/P1 샘플 spot-check**(계약 유지)만 fresh-context 감사. fresh-context 리뷰 9건(H1·M5·L3) 전부 반영. bats 199/199.

### godot-craft (v1.3.1)
텍스트 한 줄로 플레이 가능한 Godot 4 게임을 자율 생성하는 6-Phase 파이프라인 (Concept → Scaffold → Implement → Test → Review → Verify). 이미지 에셋 생성(Gemini API/Flux/Worker)과 Gemini Flash 기반 Visual QA 포함.

### product-discovery (v1.1.1)
제품 발견 도구. 사용자 인터뷰 준비/분석 (The Mom Test) + 출시 후 분석 (지표 추천/회고/런치 분석/경쟁 구도). auto-complete-loop v4.0.0에서 분리됨.

Key commands: `/interview-prep <기획문서>`, `/interview-summary <녹취>`, `/post-analysis [--only metrics|retro|launch|competitive]`

### multi-ai-roundtable (v2.1.0)
AI 토론 워크플로우. 실제 codex 바이너리를 Bash로 직접 호출해 비판적 관점을 수집하고, 여기에 Claude의 창의적 대안 관점을 더한 뒤, Claude가 중재·합성하여 합의 로드맵을 도출하고 병렬 에이전트로 실행. quota 감지 시 즉시 Claude 폴백. (종료된 gemini CLI를 두 번째 외부 CLI에서 제거 — v2.0.0. 이제 외부 CLI는 codex 하나)

Key command: `/roundtable <프로젝트 경로 또는 설명>`

### open-reach (v1.2.0)
리서치 중 공개 소스가 표준 fetch(WebFetch/curl)로 막혔을 때(WAF 403·JS 챌린지·봇 차단) 사용하는 도구. 정책상 허용되는 공개 접근 경로를 순서대로 시도하고, 성공하면 본문 마크다운을, 실패하면 분류된 실패 사유와 시도 이력(attempts)을 재현 가능하게 남긴다. 조사의 근거가 "실제로 중요한 소스"가 아니라 "우연히 열리는 소스"로 좁혀지는 편향을 막는 것이 목적. **경계(NG-1~NG-13, 코드 정책 계층에서 fail-closed 강제, 완화 금지)**: 로그인월·페이월 미돌파(감지·보고만, 종료코드 2), 인증 우회·CAPTCHA 해결·프록시 로테이션·지속 신원 위장 없음, rate limit 존중, SSRF 차단(사설 IP·루프백·메타데이터), 취득 본문 미보관. 순수 표준 라이브러리로 동작(설치 개입 0회), `curl_cffi` 존재 시 브라우저 TLS 임퍼소네이션 추가. v1.1.0에서 **브라우저 티어(T2·`--allow-browser` opt-in)** 도입 — HTTP 티어(T1)가 JS 챌린지에 막힐 때만 지연 설치 patchright+Chromium으로 폴백해 HTML을 실제 렌더 후 공개 본문 취득. **A8 준수(회피 도구 판정 4항 통과)**: 매 호출 임시 프로필+LIFO 정리(정상·예외·SIGTERM), 지문 위조 없음(자동화 아티팩트 제거만)·행동 시뮬 없음·쿠키/자격증명 미취급, 성공은 '공개 본문 취득'으로만 판정. patchright 미설치 시 `browser_disabled`로 강등(없는 돌파를 지어내지 않음·NG-10). NG-11 프리엠티브 SSRF 가드(`context.route`로 공개→사설→공개 리디렉션 중간 홉 사전 차단). SC-2/5/6(holdout 낙폭 0%p·과적합 없음)/7/8 검증(docs/r3-contract.md), 인수 테스트 us-b-011(동결)+단위 test_browser_tier. SPEC/ADR/인수 테스트로 문서화되고 auto-complete-loop DoD/게이트로 검증됨(plan-docs-full). CLI: `python -m open_reach.engine {fetch|explain|bench|compare|baseline|refresh}`. v1.2.0에서 **지문 노후 경고**(R4) — `last_reviewed` 가 90일(`STALE_THRESHOLD_DAYS`)을 넘긴 벤더를 `load()` 시 프로세스당 1회 stderr로 경고(fail-closed 아님·경고만, SPEC §263). 판정은 `today` 를 주입받는 순수 함수 `stale_profiles`(결정적·부작용 없음)로 분리, 정확히 90일은 `>` 비교로 통과(경계 off-by-one 고정), 날짜 결측·파싱 불가는 신선도를 증명 못 하므로 함께 경고(`days_since=None`, NG-10 정신). 돌파율은 시간이 지나면 떨어진다는 전제로 정기 점검·회귀 감지·유지보수 절차를 담은 운영 런북 `docs/operations.md` 추가. 단위테스트 12종(test_profiles_stale). codex 리뷰 결함 없음, 유닛 160/160·동결 인수 11/11.

Key command: `/open-reach <URL>`

## Plugin Architecture

Each plugin follows the Claude Code plugin structure:
- `.claude-plugin/plugin.json` — Plugin metadata
- `commands/*.md` — Slash commands (user-invocable)
- `skills/*/SKILL.md` — Skills (auto-triggered or referenced by commands)
- `hooks/` — Lifecycle hooks (e.g., session-start, stop-hook)
- `rules/` — Shared rules injected into context
- `agents/` — Agent definitions

## Key Scripts

- `plugins/auto-complete-loop/scripts/shared-gate.sh` — Central quality gate utility. Subcommands: `init`, `status`, `update-step`, `quality-gate`, `secret-scan`, `record-error`, etc. Used by all auto-complete-loop workflows.
- `plugins/design-polish/scripts/search.cjs` — BM25 search over design JSON data
- `plugins/design-polish/scripts/capture.cjs` — Puppeteer screenshot + axe-core WCAG check

## ⚠️ 커밋/푸시 규칙 — 반드시 읽고 따를 것

> **`plugins/` 내 각 폴더는 독립 git 레포의 서브모듈입니다.**
> 플러그인 코드를 수정하면 **해당 플러그인 폴더에서** 커밋/푸시해야 합니다.
> 이 루트 레포에서 커밋하면 서브모듈 참조만 업데이트됩니다.
>
> **마켓플레이스 배포 경로**: `.claude-plugin/marketplace.json`의 각 플러그인 `source`는
> **HTTPS git URL 직접 참조**(`{"source": "url", "url": "https://github.com/vp-k/<플러그인>.git"}`)다.
> 이유: ① `/plugin marketplace add`가 plain clone만 수행해 서브모듈이 초기화되지 않으므로
> 상대 경로(`./plugins/...`)는 원격 사용자에게 빈 디렉토리가 됨, ② `{"source": "github", "repo": ...}`
> 형식은 SSH(`git@github.com:`)로 clone해 **SSH 키 없는 사용자의 설치가 실패**함 (실측 검증).
> 따라서 **플러그인 레포에 푸시하면 사용자는 marketplace update로 바로 받는다**
> (루트 서브모듈 ref 갱신은 이 모노레포 체크아웃의 정합용으로 계속 유지).

### 플러그인 코드 수정 후 커밋/푸시 순서

```bash
# 1️⃣ 해당 플러그인 폴더로 이동하여 커밋/푸시
cd plugins/auto-complete-loop    # (또는 design-polish, flutter-craft)
git add <수정한 파일>
git commit -m "메시지"
git push

# 2️⃣ 루트로 돌아와서 서브모듈 참조 업데이트
cd <project-root>
git add plugins/auto-complete-loop
git commit -m "chore: update auto-complete-loop submodule ref"
git push
```

### ✅ 버전 업데이트 규칙 — 커밋 전 반드시 확인

플러그인 동작/기능에 변화가 있는 커밋이면 **푸시 전에 반드시 버전을 올린다.** 잊으면 사용자가 받는 마켓플레이스 캐시가 갱신되지 않거나, 변경 사항을 추적할 수 없게 된다.

**무엇을 바꾸나:**

1. `plugins/<플러그인>/.claude-plugin/plugin.json`의 `version` 필드 (필수)
2. 해당 플러그인의 메인 `SKILL.md` frontmatter `version` 필드 (있는 경우)
3. 루트 `CLAUDE.md`의 "Plugins" 섹션에 적힌 버전 표시 (예: `### multi-ai-roundtable (v1.1.0)`)

**SemVer 가이드 (`MAJOR.MINOR.PATCH`):**

| 범위 | 예시 |
|------|------|
| **PATCH** (예: 1.1.0 → 1.1.1) | 오탈자, 문구 수정, 작은 버그픽스, 동작 변화 없음 |
| **MINOR** (예: 1.0.0 → 1.1.0) | 새 명령/플래그 추가, 기존 동작 보강(하위호환), Phase 흐름 재구성 |
| **MAJOR** (예: 1.x → 2.0) | 기존 명령/인자 호환성 깨는 변경, 동작 패러다임 변경 |

**커밋 흐름에서의 위치:**

```
플러그인 폴더(서브모듈)에서
  └─ ① 코드 수정
  └─ ② plugin.json / SKILL.md frontmatter version 변경 ← 잊지 마
  └─ ③ git add → commit → push

루트로 돌아와서
  └─ ④ CLAUDE.md Plugins 섹션의 버전 표기 갱신 (필요 시)
  └─ ⑤ git add plugins/<플러그인> [+ CLAUDE.md] → commit → push
```

루트 커밋 메시지에는 새 버전을 명시한다 (예: `chore: update multi-ai-roundtable submodule ref (v1.1.0 — deterministic CLI invocation)`).

순수 문서 정정(README 오탈자 등)으로 동작이 안 바뀐다면 PATCH도 생략 가능하지만, 의심되면 **올린다**.

### ❌ 절대 하지 말 것

- **루트에서 `plugins/` 내부 파일을 직접 `git add`하지 않는다** — 서브모듈이 깨짐
- **코드 리뷰 등 자동화 수정 후 루트에서만 커밋하지 않는다** — 각 플러그인 레포에 먼저 푸시
- **버전 안 올리고 동작 변경을 푸시하지 않는다** — 위 "버전 업데이트 규칙" 참조

### 서브모듈 기본 명령

```bash
# 클론 후 서브모듈 초기화
git submodule init && git submodule update

# 모든 서브모듈 최신으로 업데이트
git submodule foreach 'git checkout main && git pull'

# 서브모듈 상태 확인 (mode 160000이어야 정상)
git ls-tree HEAD plugins/
```

## design-polish Setup

```bash
cd plugins/design-polish && npm install
```

Required for screenshot capture and WCAG checks. Environment variables: `BASE_URL` (default: `http://localhost:3000`), `FULL_PAGE`, `WAIT_TIME`, `TIMEOUT`.
