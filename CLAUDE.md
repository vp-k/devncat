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

### design-polish (v2.7.0)
Design polishing with WCAG accessibility checks. Has a built-in BM25 search engine over design knowledge (66 styles, 96 palettes, 57 typography pairings). Requires `npm install` for puppeteer + axe-core. v2.2.0에서 측정 엔진 확장 — Health Score의 styleFit·performance가 고정 상수에서 **실측값**으로 전환(렌더 DOM 일관성 계측 + navigation/paint/resource timing), 계측(`page.evaluate`)과 순수 스코어러(`scoreConsistency`/`scorePerformance`) 분리로 결정적·단위테스트 가능(`npm test`), 모바일 axe 패스 + 터치 타겟(44px) 자동 감사, `--apply` 후 **close-the-loop 검증**(재캡처→before/after diff→회귀 시 롤백, renewal은 `design-renewal-backup` 브랜치 선생성), append-only `health-history.jsonl`(회귀·정체 감지), 라우트 자동 발견. v2.3.0에서 design-renewal이 전면 적용 前에 **동일 플래그 baseline 캡처를 필수 절차로 강제** — close-the-loop가 mode/route 일치 baseline과 before/after를 비교할 수 있게 보장(baseline 누락 시 `regression=null`로 떨어져 회귀 판정 불가였던 공백 차단), baseline 실패 시 백업 기반 수동 롤백으로 명시적 폴백. v2.4.0에서 v2.2.0 코드 리뷰 반영 — 콘솔 에러가 반응형 다중 뷰포트·모바일 재방문에 걸쳐 **중복 카운트되어 점수를 왜곡하던 버그 수정**(스코어링 직전 신원 기준 dedupe), 회귀 판정에 **dead-band(±3)** 도입(perf 계측 지터로 인한 거짓 regression→불필요 롤백 방지, `classifyRegression` 순수 함수·결정론적), `Number.isFinite` NaN 가드, design-renewal 백업 하드닝(`git stash create`는 untracked 미포함·GC 대상임을 명시→`git stash store` 고정+untracked는 파일 복사 백업 강제, baseline은 동일 cwd 요건 추가). 순수 스코어러 단위테스트 26종. v2.5.0에서 **디자인 계약(design contract) 도입** — 매 실행마다 디자인 시스템을 새로 유도하고 버리던 구조를 끊고 `.design-polish/DESIGN.md`(왜) + `design-decisions.json`(기계 검사 가능한 허용 토큰 집합)로 **영속화**, design-renewal이 계약 저장을 필수 절차(5-7단계)로 수행. 렌더 DOM에서 계약 위반을 계측하는 **토큰 드리프트 린트**(색/간격/모서리/폰트/그림자 — 표기 정규화 후 대조)와 **래칫**(`token-baseline.json`: 첫 실행 시 기존 위반을 동결, 이후 **신규** 위반만 CRITICAL로 승격 → 브라운필드 도입이 교착되지 않음), 히스토리 `styleMode` 태깅(heuristic↔contract 점수 체계 교차 비교로 인한 거짓 회귀 차단), 한국어 타이포(serif fallback·keep-all·자간)와 컴포넌트 상태(disabled·focus·cursor) 자동 감사, 그리고 **번호가 붙은 실패 규칙**(`knowledge/failure-rules.md` — DP-T/K/S/A/U/C 네임스페이스, append-only)로 "서술형 지적" 대신 규칙 ID 인용을 강제. 단위테스트 68종(28+40). v2.6.0에서 전수 감사 20건 반영 — **계약 해시 baseline 결속**(`token-baseline.json`에 `contractHash`·`routes` 기록, 허용 토큰이 바뀌면 옛 동결을 자동 무효화·재동결: `baseline.status` fresh/reused/refrozen; v2.5 무해시 파일은 재동결이 아니라 **채택**해 동결값을 보존한 채 해시만 기록 — 업그레이드 시점의 신규 부채가 baseline에 흡수되는 구멍 차단), **감점 분리 상한**(신규 위반 -12 / baseline 잔여 -3, `scoreTokenDriftPenalty` 순수 함수 — 기존 부채만으로 styleFit이 0이 되어 래칫이 무의미해지던 문제 해소), **키보드 Tab 순회 포커스 계측**(`collectFocusVisibility` 30개/5000ms, 프로그램 focus()가 아닌 실제 키보드 이동 — `:focus-visible` 규칙이 있거나 계측 불가면 DP-S002를 INFO로 강등해 거짓 CRITICAL 차단), 모델이 손으로 하던 산술을 스크립트로 이관(`stagnation` = `classifyStagnation` 최근 3회·폭 3 → `insufficient|stagnant|none`, `ruleFailureSummary.blockingViolations`; SKILL 1.9 Pivot 규칙은 `stagnant AND score < 80` — 고득점 정체는 수렴), 라우트별 서버 프로브(전부 ECONNREFUSED일 때만 `down`, 첫 거부 시 즉시 단락, 404는 `skipped`), health-history `viewports` 태그(뷰포트 세트 교차 비교 차단), severity 4단계(CRITICAL/HIGH/MEDIUM/LOW), `tokenDrift.measurement complete|incomplete`(샘플 상한 도달 시 정직 표기), 공용 `knowledge/backup-procedure.md`(stash create+store·백업 브랜치·untracked 파일 복사·**fail-closed**)를 renewal·polish·screenshot 3스킬이 공유, design-from-screenshot 계약 편입, `search.cjs` 유니코드 토크나이저(한글 질의 0건 버그 수정). auto-complete-loop `design.sh`가 읽는 `health-score.json` 필드(score/styleMode/regression/tokenDrift)는 이름·의미 유지. 직접 리뷰 3건(프로브 단락·구 baseline 채택·Pivot 가드) 반영. 단위테스트 120종(42+60+18). v2.7.0에서 fresh-context 전수 감사 14건 반영 — **정직한 실패 신호**: 서버 프로브를 순수 함수 `classifyProbes`로 분리해 전부 TIMEOUT인 느린 서버를 `down`으로 단정하지 않고 캡처를 시도(`attempt[]`, 상태 `reachable|down|unreachable(timeout)|unreachable|unknown`), 4xx/5xx·ECONNREFUSED만 `skipped`, 프로브 타임아웃은 `TIMEOUT` 설정에서 파생(상한 15s); `summarizeCaptureResults`가 skipped 라우트를 실패로 세지 않아 404 하나가 정상 캡처 실행을 exit 1로 만들던 버그 수정(시도 0건은 실패), JSON 결과에 `resultSummary`, 종료 코드 계약 0/1/2(README "Exit codes"). **포커스 요소별 계측**: 페이지 전역 `:focus-visible` 규칙 하나로 전 요소를 INFO 강등하던 fail-open을 요소별 매칭(`focusRuleMeasured`·`focusVisibleSelectorCount`·교차 출처 스타일시트 unreadable 계수)으로 교체, 강등 순서 = 키보드 계측 실패 → 스타일시트 unreadable → 해당 요소 매칭 규칙 → (구 계측에 한해) 전역 규칙 하위호환. **래칫 정합 Pivot**: `summarizeSeverity`에 `actionable`/`blockingNewViolations` 신설(래칫 규칙 DP-T*는 `newCount`만 조치 대상) — Pivot 임계는 `blockingNewViolations >= 5`로 바꿔 baseline 동결 부채만으로 Pivot을 권고하던 브라운필드 오판 차단(`blockingViolations`는 총량 보고용 유지). `classifyStagnation`이 `runs`(실제 회차)·`window`·`required`·`tolerance` 반환, backup-procedure 백업 브랜치 판정을 `git for-each-ref` 출력 유무로, SKILL/커맨드/README의 데이터 건수·임계 하드코딩을 `search.cjs --help` 단일 출처로 정리, Pre-delivery 체크리스트 heuristic/contract 분리. `health-score.json` 계약 무변경. 단위테스트 150종(60+72+18).

Key commands: `/design-polish`, `/design-renewal`

### auto-complete-loop (v4.22.0)
AI coding completion framework with Ralph Loop + DoD/SPEC/TDD verification. Orchestrates full project lifecycle: PM Planning → Doc Planning → Implementation → Code Review → Verification.

Key command: `/full-auto <requirements>` (runs all phases), plus standalone commands like `/plan-docs-full` (PM + Doc planning only with 4 strict gates), `/code-review-loop`, `/plan-docs-auto`, `/implement-docs-auto`

리뷰 모드: `solo`(Claude 서브에이전트 3개 병렬, 폴백 순차) / `codex`(기본, Claude+codex 2자) / `dual`(codex 2회 분할 병렬 독립 리뷰+Claude, 3자) / `teams`. v3.0.0에서 종료된 gemini CLI를 `dual`로 교체, v3.1.0에서 리뷰 프롬프트 단일화·quality-gate 캐시·템플릿 lazy-load·stop-hook 하드닝, v4.0.0에서 제품 발견 도구를 product-discovery 플러그인으로 분리(BREAKING: `/interview-*`, `/post-analysis` 제거) + solo/dual 병렬화 + admin.sh 모듈 분할, v4.1.0에서 하드 게이팅 배선 완성 — 기획 게이트·live-testing·레이어 커버리지·코드리뷰 finding이 verification.json 기록을 거쳐 stop-hook에서 결정적으로 차단(fail-closed), 자기신고 DoD 제거, 스펙 공백 시 임의 구현 금지 절차, runtime-gate(서버 1회 기동 통합 검증), verification-auditor fresh-context 교차 감사 배선. v4.2.0에서 인수 테스트 선작성+동결(TDD red→green) — 기획 Phase가 SPEC AC로부터 실행 가능한 인수 테스트(`tests/acceptance/`)를 생성해 해시 동결(`acceptance-freeze`), 구현 Phase는 수정 불가(훅 차단+`acceptance-gate` 해시 무결성), 완주하려면 동결된 테스트 green 필수. 스펙 변경은 사용자 승인 → `--approved-by-user` 재동결(이력 기록)로만. v4.3.0에서 verification.json 조작 차단(Edit/Write block + Bash 쓰기 가드) + lesson 메모리 루프("기억은 다음 실행 조건": 3-strike·L3+ 에스컬레이션·완주 교훈을 `.claude/acl-learnings.local.md`에 기록, session-start가 다음 세션에 주입) + SOFT 게이트 2연속 fail→HARD 승격. v4.4.0에서 4-렌즈 독립 감사(E2E 완주 스모크·셸 견고성·계약 전수·훅 상호작용) 수정 — 훅 입력 stdin 규약(promise 감지 복구+무한루프 탈출), DoD setter 부재 데드락 해소, jq 원자성 self-heal, 권한 프롬프트 우회 제거, 비플러그인 프로젝트 오탐 게이팅, E2E 하드 트랩(루트 404 서버·SPEC 부정 케이스) 해소, Bash 훅 단일 디스패처 통합. v4.6.0에서 `/check-docs` 현행화 — doc-consistency/doc-code-check가 dod·verification.json 자동 기록(모델 직접 세팅 금지, doc-check 템플릿에 `no_definition_conflict` 추가), 1단계에 definition-conflict·clarification-gate 편입([NEEDS-CLARIFICATION] 잔존 시 AskUserQuestion 예외), handoff-update 서브커맨드 사용, `--mode solo`(fresh-context 서브에이전트) 지원, 보호 파일 가드 차단 시 절차 명문화. v4.7.0에서 ouroboros 벤치마킹 6종 — `provenance-gate`(SPEC 핵심 섹션 출처 4분류 마커: user-fact/repo-fact/assumption/blocker, unsafe 도메인 assumption 금지, plan-docs-full 게이트 7종으로 확장), 막힘 패턴 감지 확장(3-strike 연속 판정 교정 + OSCILLATION·DIMINISHING_RETURNS, 정규화 해시, 패턴별 LESSON), `review-escalation-check`(L2+/범위 축소/재동결 트리거 시 dual/roundtable 승격 리뷰 의무, stop-hook fail-closed), TOO_BIG 문서 분할(record-error exit 4 → `doc-split record`, L4 전 단계, 깊이 1 제한), spec-completeness 4차원 명확성(Goal/Constraints/SC/Context + SPEC에 Context 섹션), append-only 이벤트 로그(`.claude/acl-events.jsonl`, 관측 전용). v4.8.0에서 SPEC 해시 동결 — acceptance-freeze가 SPEC 파일 해시를 manifest에 함께 동결하고 acceptance-gate가 대조, 게이트 통과 후 SPEC을 몰래 수정하는 세탁 차단(해시 갱신은 사용자 승인 재동결로만, pre-4.8 manifest는 skip 하위호환). v4.9.0에서 gajae-code 벤치마킹 — 리뷰 소스 해시 귀속(`source-hash` 서브커맨드, 각 리뷰 라운드가 캡처한 지문을 code-review-findings가 현재 상태와 대조해 리뷰 후 무리뷰 변경 차단 — 동결 3부작 완성) + 리뷰 래칫 5규칙(라운드 2+ delta-only·novelty justification·verdict monotonicity·severity scoping·dual counter-review). v4.10.0에서 ouroboros/gajae deep-interview 벤치마킹 — 명확성 선행 인터뷰(`ambiguity-score` 서브커맨드): Phase 0 문서 작성 前에 4차원(Goal .30/SuccessCriteria .25/Constraints .25/Context .20) 명확도를 AI가 채점하고 스크립트가 가중 합성점수를 결정론적으로 계산(채점=AI, 산술·판정·기록=스크립트, "프롬프트 임의 해석"을 게이트로 고정), composite ≥0.8 AND 모든 차원 ≥0.6(floor 맹점 차단) 통과 전까지 가장 약한 차원을 공략하는 인터뷰 루프. 개입 최소 원칙(사용자 주의 > 모델 토큰): repo-fact는 서브에이전트 auto-research로 자동 확인(사용자 안 부름), safe assumption 자동 기록, user-fact/blocker만 batch-ask 1회. max-rounds(3) 도달 시 잔여를 `[NEEDS-CLARIFICATION]`로 이관해 clarification/provenance-gate가 최종 fail-closed 차단. 거짓 고득점은 Phase 1 완료 시 spec-completeness가 같은 4축을 파일 기반으로 재검증해 backstop. v4.11.0에서 fresh-context 코드 리뷰 반영 — 게이트 fail-open 3종 차단(protect-files-guard가 teams progress 파일도 보호, acceptance-gate가 total>0 AND passed==total 강제해 스텁 러너 통과 차단, code-review-findings severity 대소문자 정규화로 소문자 critical 탈출 차단), stop-hook 하드닝(set -e 하 iteration 갱신 실패 시 block-continue 보장, jq 부재 우회 감사 기록, assistant grep 공백 내성), 포터빌리티·원자성(shared-gate bash4+ 조기 안내, atomic write 동일 디렉토리 temp, acceptance/SPEC 해시 CRLF 정규화). v4.11.1~4.11.3에서 block-no-verify 가드를 인용/백슬래시/세그먼트를 존중하는 실제 셸 토크나이저로 재작성(다중 라인 커밋 메시지 오탐 + `git commit -nm` 결합 단축 플래그 미탐 동시 해소, `bash-guards.bats` 16종)하고 잔존 미등록 사본 `block-no-verify.sh`를 삭제. v4.12.0에서 "애매한 채로 반복" 실패 모드 봉쇄 3종 — (1) 착수 전 명확화(`ambiguityScore`)를 stop-hook fail-closed 집합에 편입(`pass`|`escalated`만 허용, 키 부재=인터뷰 통째 스킵→차단; full-auto·plan-docs-full 양쪽) + spec-completeness가 자기신고↔파일 재검증 세탁을 교차검증(신고 ≥floor 0.6인데 실측 약한 차원 → `gate.ambiguity.mismatch` 이벤트·경고, 관측 전용), (2) session-start가 `acl-events.jsonl`을 소비해 성공 시 초기화되는 stuck-pattern이 놓치는 **교차 실행 반복**(반복 오류 타입 ≥3회·명확성 세탁·L4/L5 심층 에스컬레이션)을 다음 세션 경고로 주입(문서 힌트 없이 events만 있어도 emit), (3) exit-4 문서 분할 요구(`pendingSplit`)를 stop-hook fail-closed로 승격(분할·L4 전이 없이 완주 차단). bats 169/169. v4.13.0에서 **디자인 계약 강제** — SPEC이 "무엇을"의 계약이라면 `docs/DESIGN.md`는 "어떤 인상을"의 계약이다. `hasFrontend=true`면 doc-planning Step 1-0이 `templates/DESIGN.md`를 필수 문서로 복사(lazy-load 규칙 동일)하고 Step 1-9가 존재를 검증하며, `spec-completeness`가 미생성·템플릿 잔존·**제품 성격/브랜드 섹션의 `assumption` 마커**(추측한 성격은 전 화면에 전파되어 되돌리기가 가장 비싸므로 `user-fact`|`blocker`만 허용)를 MAJOR로 잡는다. 구조적 결정은 기존 `docs/adr/`에 남겨 번호 체계를 새로 만들지 않는다. 구현 Phase는 색·간격·모서리·폰트·상태 표현을 "자유 구현 세부"가 아닌 **동작 계약**으로 취급해 DESIGN.md에 없는 값을 코드에 먼저 넣는 것을 금지. `UI States` 표가 있어도 `AC-F-*`에 빈/로딩/에러/유효성이 하나도 반영되지 않으면 MAJOR(동결 인수 테스트가 happy path만 검증하는 공백 차단). design-polish 계약이 설정된 프로젝트에서는 `design-polish-gate`가 `tokenDrift`(total/new)를 verification.json에 기록하고 **신규** 위반만 pass→soft_fail 강등(`--strict`는 fail) — 기존 부채는 래칫으로 동결. bats 186/186. v4.14.0에서 doc-consistency 수치 검사를 교체 — 기존 [5]는 문서 전체에서 같은 단위가 다른 값으로 나오면 그 개수만큼 hard fail 시켰으나 "실패 사유 11개"와 "인수 테스트 8개"는 서로 다른 것을 세는 정상 문장이라 무언가를 세는 모든 문서 세트에서 구조적으로 통과 불가능했다(plan-docs-full DoD 데드락). 숫자를 마스킹한 문장을 키로 삼아 **같은 문장이 다른 숫자로 반복되는 경우만** CONFLICT로 계상하도록 바꾸고(복붙 드리프트 정조준, 20자·3토큰 미만 제외, 동일 키 1건 계상), 단위 스프레드는 INFO로 강등(판단 필요 시 `numericAudit` 기록). bats 195/195. v4.15.0에서 리뷰 루프 발산 차단 — full-auto Phase 3 완료 조건 "Critical/High/**Medium** 0개(라운드 제한 없음)" + "Medium 즉시 수정(스킵 금지)" + 재기록 라운드 규칙(v4.9.0)의 조합이 리뷰→의무 수정→소스 변경→재기록 라운드→수정분에서 새 MEDIUM의 무한 연쇄를 만들던 것을 standalone `/code-review-loop` 정책(C/H만 하드, MEDIUM deferred, 라운드 상한)에 정렬: 하드 조건은 open CRITICAL/HIGH 0개만(게이트 `code-review-findings` 계수 기준과 일치), MEDIUM/LOW는 라운드 3+부터 `deferred` 백로그(완료 비차단), **라운드 상한 5**(도달 시 C/H 잔존이면 에스컬레이션 — 상한을 이유로 C/H deferred 금지), **수렴 라운드 규칙**(신규 finding이 MEDIUM/LOW뿐이면 수정 없이 deferred 기록 → 소스 불변 → sourceHash 정합 자동 충족·즉시 완료 — 재기록 라운드 연쇄의 종료점). teams 모드(team-code-review)·implement-docs-auto("피드백 없을 때까지 반복"→C/H 0 기준)·phase-transition DoD evidence 동일 정렬. 문서 정책 변경만으로 게이트 스크립트는 원래 C/H만 세므로 무변경. v4.16.0에서 v4.15.0 fresh-context 리뷰 9건 반영 — (1) 수렴 라운드를 **라운드 3+·재기록 라운드로 한정**(라운드 1~2는 Medium 즉시 수정 우선 → 1라운드 무수정 완주 구멍 봉쇄, "즉시 완료"는 추가 리뷰 라운드 불요의 의미일 뿐 품질/E2E 게이트·escalation pending은 여전히 필수), (2) 상한을 "**수정이 발생한 라운드 5회**"로 재정의 — 확인 전용(수정 0건) 라운드·귀속용 재기록 라운드는 상한 비포함(재기록 라운드가 게이트 필수 절차인데 상한에 막히는 데드락 해소), 예산 소진 후 C/H 잔존 시 `record-error --type REVIEW_ROUND_CAP --level L2`로 review-escalation 트리거를 명시 배선(승격 라운드는 상한 예외), (3) **게이트 결정론 백스톱**: code-review-findings가 deferred/regressed CRITICAL/HIGH를 open으로 계수(상태값 세탁 차단, MEDIUM/LOW deferred는 비차단 유지) + interactive Acknowledge의 C/H는 dismissed 경로로 변경, (4) C/H→M/L **severity 강등에 사유 기록 의무**(`severityAdjustments`) + 강등분은 그 라운드 수렴 판정에서 원 severity 취급(강등 세탁 차단), (5) regressed C/H 완료 차단 명문화, findingHistory status enum 5값 통일, implement-docs-auto 리뷰 사이클 상한 5회 + M/L 3회 규칙 일원화. bats 199/199. v4.17.0에서 오픈 딜레이 유발 지점 8건 제거 — (1) 문서 합의 루프 조기 종료: doc-planning/solo/plan-docs-auto/polish-for-release 수렴 기준을 "신규 C/H 0건 라운드에서 즉시 합의"로 통일(최소 라운드 하한·확정 문서 재검토 라운드 제거, 1라운드 수렴 정상), 표준 템플릿 문서(logging-standard·error-policy·security-authn-authz·DESIGN.md)는 1라운드 상한, (2) **규모 비례 호출**: projectSize=Small이면 Phase 0-7 roundtable(codex 단독 대체)·Phase 1-6 아키텍처 리뷰·0→1/2→3 Director를 스킵(`SKIPPED_SMALL`/`directorSkipped` 증거를 outputs에 기록, 1→2/3→4는 항상 호출), (3) Step 2-2.5 AI 호출 제거 — AC를 SPEC+동결 테스트에서 직접 매핑(횡단 문서는 빈 배열 정상) + Step 2-4 문서당 리뷰를 C/H 전용 1사이클로 축소(M/L은 Phase 3 위임), (4) Step 4-2 codex 보안 리뷰를 Phase 3 SEC finding 이력 있을 때만으로 조건부화(secret-scan·vuln-scan은 무조건), (5) **Step 4-6.8 최종 델타 리뷰 신설** — 소스 지문이 HEAD를 포함해 Phase 4 폴리싱 커밋마다 code-review-findings가 stale FAIL하던 배선 공백을 "잔여 변경 전부 커밋 → 지문 대조 → 다르면 델타 리뷰 1회(재기록 라운드)"로 선제 해소, C/H 수정 커밋 시 acceptance-gate(+런타임 변경 시 runtime-gate) 재실행, 4-7c 말미 자동 커밋을 커밋 가드로 교체(리뷰 후 무리뷰 커밋 금지), 4-8 version bump는 버전 파일 한정 커밋으로 불변식 명시 예외, (6) Step 4-7.5 감사를 모델 기록분으로 축소 — write-guard된 fail-closed 키는 존재 확인만, 소프트 차원 evidence·DoD evidence·SPEC US spot-check·**Test Plan P0 전수/P1 샘플 spot-check**(계약 유지)만 fresh-context 감사. fresh-context 리뷰 9건(H1·M5·L3) 전부 반영. bats 199/199. v4.18.0에서 **의식 단계 제거 + 동결 탈출구 배선 + 규모 비례 축소** — 역할 프롬프트·불필요 단계·TDD 정체 전수 점검 결과 권장 7항목 반영. (1) 결정론 게이트를 중복하던 **Director 4회 호출·code-simplifier 에이전트 제거**(phase-transition은 게이트 통과 → `update-phase` 직행, `conditionalGoItems` 초기화·v7 마이그레이션 주입 제거), 리뷰 관점 템플릿의 강제 지적/severity 상향 규칙 삭제, verification-auditor는 Large 전용·관측 전용, pm-planning ADR 필수 완화. (2) **동결 탈출구 배선** — "승인받아도 고칠 도구가 없던" 모순을 `acceptance-unlock --approved-by-user --reason` 토큰(`.claude/acceptance-unlock.json`)으로 해소: protect-files-guard가 토큰 존재 시 SPEC.md·`tests/acceptance/**`만 한시 허용(overview/docs/specs/plans는 계속 차단), `acceptance-freeze --approved-by-user`가 토큰을 소비하며 `refreezeHistory`에 사유 기록, 토큰 잔존은 acceptance-gate FAIL + stop-hook(full-auto·plan-docs-full 공통) 차단. 토큰 파일 자체는 Edit/Write 하드 차단 + bash-guards 검사 5(Bash 경유 생성/수정/삭제)로 위조 불가. `--start-phase` 무인 재개는 `--approved-by`로 승인 출처 기록. (3) acceptance-gate 현실화: 동결 외 파일 추가는 WARN(`addedFiles`)으로 완화(변조·삭제는 FAIL 유지), 러너 실패 1회 재시도 — 2회차 green은 pass가 아니라 **`soft_fail`(flaky, `firstRun`)**로 기록해 완주 차단, 비결정성 제거 후 1회차 green이어야 pass. 구현 Phase는 US 파일 단독 실행(전체 러너는 Step 2-7·Phase 4만 — 남의 red 떠안기 방지), `_helper.sh` 필수(freeze WARN), 서버 재사용은 같은 셸이 띄운 프로세스로 한정(파일/env/열린 포트 신호로 재사용 판정 금지 — env 스크럽 우회 세탁 채널 봉쇄). (4) 스펙 공백은 `docs/CLARIFICATIONS.md` append(보호 파일에 태그를 넣다 훅에 막혀 질문이 통째로 사라지던 실패 모드 제거) + **Phase 4 Step 4-6.6 clarification-gate 재실행**(Phase 1의 옛 pass 기록으로 미해결 질문을 안은 채 완주하던 공백 차단). (5) **solo 통합**: doc-planning-solo 스킬을 doc-planning의 `{REVIEW_MODE}`(codex|solo|teams) 분기로 흡수, full-auto·plan-docs-full 파라미터 표에 REVIEW_MODE 행. (6) **Small 규모 축소**: 백엔드 표준 문서 3종·test-strategist는 Medium+만, spec-completeness test-plan 검사 Small skip(`testPlan.verdict=SKIPPED_SMALL`), `rules/project-size-rules.md`가 규모 분기 단일 출처. (7) 정리: commit-msg-guard·verification-write-guard 훅 파일·DONE.md 템플릿 삭제(bash-guards 단일 디스패처, DoD는 progress.dod 기준), doc-file-warning ALLOWED_DOCS 축소, CONTRIBUTING.md 신설, README 현행화. fresh-context opus 리뷰 8건(H2·M4·L2) 전부 반영. bats 227/227. v4.19.0에서 **규칙·커맨드 단일 출처화** — (1) `/plan-docs-auto`가 doc-planning 스킬 Step 1-2·`doc-planning-common.md`와 인라인 중복하던 토론 프로세스·codex 프롬프트·토론 규칙·체크리스트 약 190줄을 제거하고 "SKILL.md Read + 치환 규칙 표({PROGRESS_FILE}·{REVIEW_MODE}·최상위 documents·$1) + 적용 범위(Step 1-0 overview 검증·1-2·1-4만)"로 위임 — 검토자 분기(2-A codex/dual, 2-B solo)·수렴 기준·라운드 상한(codex/dual 5, solo 3; 기존 5회/7회/7라운드 혼재 제거)이 full-auto Phase 1과 동일해짐. (2) `shared-rules.md`의 2줄짜리 포인터 스텁 2개(에러 에스컬레이션·규모 판정 — 규칙 파일과 어긋난 Large 기준 요약 포함)를 삭제하고 "이 파일에 없는 규칙" 인덱스 표로 교체 — 스텁 삭제로 사라진 유일한 실행형 Read 지시를 표의 **로드 시점별 `Read ${CLAUDE_PLUGIN_ROOT}/rules/…` 지시**로 복원하고 pm-planning·implementation·implement-docs-auto의 상대 경로 인용도 실행형 Read로 승격, implement-docs-auto L2 절차를 규칙 파일과 정합(변경 파일만 `git stash push -- <files>` + 라운드테이블). (3) 리뷰 반영: **단순 approve 금지**를 solo 전용에서 모드 공통 토론 규칙으로 승격(근거 없는 approve 라운드는 수렴 라운드로 계상하지 않음 + codex 프롬프트에 총평 반환 금지), doc-planning-common 체크리스트 3항목(로깅/모니터링·배포/마이그레이션·경계값 테스트) 복원 + projectScope 부재 시 문서 내용으로 판단, plan-docs-auto 표준 템플릿 1라운드 상한을 실제 템플릿 사본(placeholder 잔존)에 한정·provenance-gate 부재 명시, README solo 다이어그램 현행화, 별칭 argument-hint 통일. fresh-context opus 리뷰 13건(H2·M6·L5) 전부 반영. bats 227/227. v4.20.0에서 **결정 기록 단일 출처 + 자가 루프 마감 강제 + 착수 전 assumption 일괄 확인** — "이유 없는 결정은 잘못된 결정"을 형식적으로 불가능하게 만드는 배선. (1) `record-decision` 서브커맨드: 무엇/왜/대안/가역성/scope/source를 `.claude/acl-decisions.jsonl`(append-only, `D-NNNN` 연번)에 기록하고 `decision.recorded` 이벤트·`handoff.keyDecisions`에 미러링. **`--why`가 공백 제외 10자 미만이면 거부**(jq 코드포인트 계수로 로케일 무관), `--none --why`로 "이번 iteration 결정 없음"도 이유와 함께 명시. 기존 채널(ADR·provenance 마커·CLARIFICATIONS·severityAdjustments)은 유지하고 `--source`로 같은 로그에 미러. 규칙 본문은 `shared-rules.md` "결정 기록 (단일 출처)" 한 곳. (2) 결정 지점 배선: 인터뷰 safe assumption·ADR·Step 2-2 기술 스택 세부·Step 2-2.7 데이터 전략·Step 2-1.9(a) 자유 구현 중 되돌리기 비싼 것(다른 US가 의존하는 결정)·에러 복구 L1/L3 접근 전환·L4 범위 축소·리뷰 deferred/강등(review-perspectives 1곳)에 기록 의무. (3) **stop-hook fail-closed 3종**(`decisionLog.enabled` progress만; v4.19 이하 파일은 NOTE만): `handoff.lastIteration==현재 iteration`(handoff 미갱신 차단), 현재 iteration 결정 기록 ≥1건(decision 또는 none), `assumptionReview.status∈{confirmed,none,escalated}`(full-auto·plan-docs-full). 하드 차단은 완주(promise) 경로에만, continue 경로는 리마인더(무한 block 방지). pre-compact가 최근 결정 5건을 "요약에 보존" 지시와 함께 주입, session-start가 결정 건수·마지막 결정 1줄 주입. `status`에 최근 결정 3건. (4) **Step 0-0.6 assumption 일괄 확인**: 인터뷰(PASS/ESCALATED) 직후 모델이 정한 safe assumption 전부를 표(항목·채택값·근거·가역성)로 AskUserQuestion 1회 승인/수정 → 승인분은 SPEC에 `user-fact`로 승격 + 각 항목 record-decision + `assumption-review --status/--count` 기록(`none`+count≠0, `confirmed`+count==0 위조 거부). 비대화형은 `escalated`. Phase 1 신규 assumption은 Step 1-9 clarification batch-ask에 합류(왕복 추가 없음) 후 provenance-gate 재실행. `--start-phase N≥1`은 `--status escalated --count 0` 명시 필수(confirmed 위조 금지). 직접 리뷰 4건(H1·M2·L1) 전부 반영 — 결정 로그 파일 Edit/Write·Bash 쓰기 가드(verification.json과 동급), 마감 2종을 ralph-loop-setup 공통 조건으로 단일 출처화(7개 워크플로우 전부 적용), handoff-update --iteration 생략 시 frontmatter 자동, README 서브커맨드 수 정정. bats 281/281. v4.21.0에서 v4.20.0 전수 감사 13건 반영 — **결정 로그 실행 격리(`runId`)**: init이 `run-<UTC>-<8hex>`를 생성해 7종 템플릿에 심고 record-decision이 매 레코드에 스탬프, stop-hook 마감 조건·`--list`(기본 현재 run, `--all` 전체)·pre-compact·session-start(`.claude-*progress*.json` 글롭)가 runId로 필터(runId 없는 v4.20 progress는 iteration만 보는 하위호환), 완주 시 `.claude/acl-decisions.jsonl`을 `archive_or_remove`로 정리해 다음 실행의 결정 건수 오염 차단. **assumption-review 교차검증**: `--status confirmed`는 이번 run의 `scope==interview && kind==decision` 결정 건수와 `--count`가 일치해야 기록(불일치 exit 1 — 표만 보여주고 record-decision을 건너뛴 위조 차단). **리뷰 라운드 상한을 게이트 계수로 이관**: `code-review-findings --round-kind fix|verify|rerecord`(기본 verify)가 `reviewRounds.{withFixes,total,cap=5,lastKind}`를 verification.json에 누적하고 `REVIEW_ROUND_CAP=5` 도달+open C/H 잔존 시 `record-error --type REVIEW_ROUND_CAP --level L2`를 요구(모델이 손으로 세던 "수정 라운드 5회"를 결정론화). `handoff-update --decision`이 덮어쓰기에서 append로 전환(NOTE 출력), `--iteration` 생략 시 frontmatter 자동 채움을 7종 워크플로우에 통일, 완료 조건 문구를 ralph-loop-setup 공통 조건 단일 출처로 정리, polish-for-release/implement-docs-auto가 수기 progress JSON 대신 `init --template`로 전환(polish `e2e_pass`/`secret_scan`, implement `definitionDoc`/`readmePath` 추가), 스킬 4종(pm-planning·verification·code-review·team-code-review)에 결정 기록 포인터, 워크플로우 7종에 "promise 직전 체크리스트"(handoff-update → record-decision → status 확인). 직접 리뷰 2건 반영 — (1) decisions.sh 락 회수가 owner 메타 부재를 즉시 스테일로 판정해 mkdir↔메타 기록 사이 찰나에 두 프로세스가 락을 쥐고 `D-NNNN` 채번이 충돌하던 경합을 **디렉토리 mtime 기반 30초 판정·못 재면 대기(fail-closed)**로 수정, (2) `--round-kind`가 모델 자기신고라 수정하고도 `verify`로 신고하면 상한을 피하던 세탁을 **소스 지문 교차검증**으로 차단(마지막 마감 이후 지문이 바뀌었으면 신고와 무관하게 `fix`로 계상, 신고값은 `declaredKind`에 보존). bats 306/306(v4.21.0 커밋 메시지의 318은 중단된 실행의 자식 프로세스가 같은 로그에 이어 쓴 집계 오염 — 고유 테스트 수 306이 정확). v4.22.0에서 v4.21.0 fresh-context 감사 12건 반영 — **fail-open 잔존 4곳 봉쇄**: (1) stop-hook jq 부재 시 `approve`(검증 0인 완주 승인)하던 단일 우회 지점을 Ralph 루프 활성 시 **block + 설치 안내**로 전환(`ACL_ALLOW_NO_JQ=1`만 명시적·이벤트 기록 탈출구, 루프 비활성 세션은 차단하지 않음), (2) `record-decision` 락 대기 소진 후 **무락 append**(`D-NNNN` 중복 가능)를 fail-closed 거부(5초 대기 후 재시도 안내, 죽은 프로세스 락은 30초 후 회수 유지), (3) implement-docs-auto의 `dod.code_review_pass`가 게이트 없는 모델 자기신고였던 것을 **stop-hook이 `codeReviewFindings=pass`를 fail-closed 요구**(`.claude-progress.json` 워크플로우 편입)하고 게이트만이 그 DoD를 기록하도록 배선, (4) `code-review-findings` 인자 파서가 미지 인자를 삼켜 `--round-kind` 오타가 기본값 `verify`로 떨어지던 것을 die로 거부(`--round-kind=fix` 등호 형식 지원). **라운드 예산 정직화**: 리뷰 증거 없음·sourceHash stale 실패는 "성립하지 않은 라운드"이므로 `reviewRounds` 계수를 올리지 않음(stale 재실행만으로 상한 5가 소진되던 문제). **호출부 정합**: full-auto·team-code-review·verification·phase-transition-rules의 `code-review-findings` 호출 4곳에 `--round-kind` 판정표(fix/verify/rerecord) 명시, bats가 문서의 모든 호출 예시에 `--round-kind`가 있는지 검사. plan-docs-full 완료 조건 1을 stop-hook이 실제로 검사하는 스키마(최상위 `documents`)로 정정, 문서의 `jq_inplace`(내부 함수) CLI 지시를 `jq … > tmp && mv` 패턴으로 교체, full-auto 파라미터 표에 INIT_TEMPLATE/MAX_ITERATIONS/EXTRA_INIT 행. **추출 버그 2건**: 완주 LESSON이 `handoff.scopeReductions`(없는 경로)·`warnings` 배열(실제는 문자열)을 읽어 빈 줄만 남기던 것을 `phases.phase_2.scopeReductions` 객체 배열(`feature → reduced (reason) [ticket]`)·문자열/배열 양쪽 수용으로 수정, session-start `ACL_RUN_ID`를 글롭 첫 매치가 아니라 **가장 최근 갱신된 progress 파일**에서 선택(옛 실행의 runId가 이번 결정 기록을 감추던 문제). stop-hook.sh CRLF 정규화. 감사 항목 중 1건(세션 에이전트 레지스트리의 director/code-simplifier 잔존)은 설치본 캐시로 레포 결함이 아니라 제외. bats 324/324.

### godot-craft (v1.3.1)
텍스트 한 줄로 플레이 가능한 Godot 4 게임을 자율 생성하는 6-Phase 파이프라인 (Concept → Scaffold → Implement → Test → Review → Verify). 이미지 에셋 생성(Gemini API/Flux/Worker)과 Gemini Flash 기반 Visual QA 포함.

### product-discovery (v1.1.1)
제품 발견 도구. 사용자 인터뷰 준비/분석 (The Mom Test) + 출시 후 분석 (지표 추천/회고/런치 분석/경쟁 구도). auto-complete-loop v4.0.0에서 분리됨.

Key commands: `/interview-prep <기획문서>`, `/interview-summary <녹취>`, `/post-analysis [--only metrics|retro|launch|competitive]`

### multi-ai-roundtable (v2.1.0)
AI 토론 워크플로우. 실제 codex 바이너리를 Bash로 직접 호출해 비판적 관점을 수집하고, 여기에 Claude의 창의적 대안 관점을 더한 뒤, Claude가 중재·합성하여 합의 로드맵을 도출하고 병렬 에이전트로 실행. quota 감지 시 즉시 Claude 폴백. (종료된 gemini CLI를 두 번째 외부 CLI에서 제거 — v2.0.0. 이제 외부 CLI는 codex 하나)

Key command: `/roundtable <프로젝트 경로 또는 설명>`

### open-reach (v2.0.1)
리서치 중 공개 소스가 표준 fetch(WebFetch/curl)로 막혔을 때(WAF 403·JS 챌린지·봇 차단) 사용하는 도구. 정책상 허용되는 공개 접근 경로를 순서대로 시도하고, 성공하면 본문 마크다운을, 실패하면 분류된 실패 사유와 시도 이력(attempts)을 재현 가능하게 남긴다. 조사의 근거가 "실제로 중요한 소스"가 아니라 "우연히 열리는 소스"로 좁혀지는 편향을 막는 것이 목적. **경계(NG-1~NG-13, 코드 정책 계층에서 fail-closed 강제, 완화·개정은 사용자 승인 없이 불가)**: 로그인월·페이월 미돌파(감지·보고만, 종료코드 2), 인증 우회·CAPTCHA 해결·프록시 로테이션·지속 신원 위장 없음, 호스트당 동시성 1 + 최소 간격 1.0s, SSRF 차단(사설 IP·루프백·메타데이터), 취득 본문 미보관. **v2.0.0에서 robots.txt는 기본적으로 조회하지 않는다**(아래 참조) — 사이트가 명시한 의사를 알고 지나가는 것이므로 "윤리 경계 준수"라 표기하지 않는다. 순수 표준 라이브러리로 동작(설치 개입 0회), `curl_cffi` 존재 시 브라우저 TLS 임퍼소네이션 추가. v1.1.0에서 **브라우저 티어(T2·`--allow-browser` opt-in)** 도입 — HTTP 티어(T1)가 JS 챌린지에 막힐 때만 지연 설치 patchright+Chromium으로 폴백해 HTML을 실제 렌더 후 공개 본문 취득. **A8 준수(회피 도구 판정 4항 통과)**: 매 호출 임시 프로필+LIFO 정리(정상·예외·SIGTERM), 지문 위조 없음(자동화 아티팩트 제거만)·행동 시뮬 없음·쿠키/자격증명 미취급, 성공은 '공개 본문 취득'으로만 판정. patchright 미설치 시 `browser_disabled`로 강등(없는 돌파를 지어내지 않음·NG-10). NG-11 프리엠티브 SSRF 가드(`context.route`로 공개→사설→공개 리디렉션 중간 홉 사전 차단). SC-2/5/6(holdout 낙폭 0%p·과적합 없음)/7/8 검증(docs/r3-contract.md), 인수 테스트 us-b-011(동결)+단위 test_browser_tier. SPEC/ADR/인수 테스트로 문서화되고 auto-complete-loop DoD/게이트로 검증됨(plan-docs-full). CLI: `python -m open_reach.engine {fetch|explain|bench|compare|baseline|refresh}`. v1.2.0에서 **지문 노후 경고**(R4) — `last_reviewed` 가 90일(`STALE_THRESHOLD_DAYS`)을 넘긴 벤더를 `load()` 시 프로세스당 1회 stderr로 경고(fail-closed 아님·경고만, SPEC §263). 판정은 `today` 를 주입받는 순수 함수 `stale_profiles`(결정적·부작용 없음)로 분리, 정확히 90일은 `>` 비교로 통과(경계 off-by-one 고정), 날짜 결측·파싱 불가는 신선도를 증명 못 하므로 함께 경고(`days_since=None`, NG-10 정신). 돌파율은 시간이 지나면 떨어진다는 전제로 정기 점검·회귀 감지·유지보수 절차를 담은 운영 런북 `docs/operations.md` 추가. 단위테스트 12종(test_profiles_stale). codex 리뷰 결함 없음, 유닛 160/160·동결 인수 11/11. v1.2.1에서 deferred(MEDIUM/LOW) 백로그 6건 전부 해결 — source URL 포트 범위(0..65535) 검증(범위 초과=열 수 없는 주소이므로 IndexLoadError, +65535 경계 회귀 테스트), `_lib.sh` PYTHONPATH 구분자를 os.pathsep 조회로(Windows `;`·CR 오염 해소), 동결 us-b-010 에 치환값 실림·예산 도달·source 누락/http/포트초과 거부 단언 보강, r2-contract 증적 관찰/추론 분리. codex 리뷰 3건(MEDIUM 1·LOW 2) 전부 반영, 유닛 161·동결 인수 11/11·acceptance-gate PASS. v1.3.0에서 **R5(insane-search 파리티)** — Phase 0 공개 플랫폼 어댑터 확장(US-B-012)과 **명시적 검색 URL 예외**(US-B-014). 라우팅 매칭을 `경로?쿼리`로 확장하고 chain 없는 endpoints 템플릿의 쿼리 **값 위치** 치환자만 허용(AC-B-010-11 R5 개정 — 이름 위치·chain·프래그먼트·`&`·`=`는 로드 시점 exit 3으로 그대로 닫힘), 인덱스 `search:` 선언(판정 전용·요청 없음·출처 의무)이 있는 검색 URL만 nav_shell 판정을 면제(길이 하한·챌린지 판별 유지, 명시성은 입력 URL로만 얻고 리디렉트로 선언 밖 도착 시 상실 — 양방향), entries·search 합산 20 상한. **등재는 robots.txt 전수 실측 결과 HN(Algolia)·Bluesky(XRPC) 2건뿐** — search.naver.com·www.reddit.com은 `User-agent: *` 전면 Disallow라 미등재(등재가 거짓 '지원' 표기가 됨, NG-8), US-B-013(Jina Reader)도 같은 이유로 철회. host 대조 의미론 확정: 포트 없는 선언=그 호스트의 모든 포트(동결 픽스처 계약), 포트 명시=netloc 정확 일치, userinfo(`@`)는 선언·URL 양쪽에서 fail-closed 거부. codex 리뷰 3라운드 종결(R1 H2·M1·L2 → 전부 수정/처분, R3 신규 C/H 없음), 유닛 184·동결 인수 13/13, rate_http_only=1.000(12/12) R2/R3 무회귀, Bluesky 라이브 phase0 구제 실증. **v2.0.0(BREAKING)에서 R6(insane-search 도달력 파리티 + 검색 계층)** — R1 70건 실측이 남긴 결론(원본 대비 잔여 격차의 실질 전부는 robots.txt 자발 준수, 기술 티어 돌파력 격차 0건)에 따라 사용자 결정으로 정책을 뒤집었다. **① robots.txt 기본 미조회**(`off`) — 현행 fail-closed 차단은 `--respect-robots`(`enforce`)로만 복원, `advisory`는 차단 없이 판정·Crawl-delay만 반영. 전역 mutable 없이 `FetchRequest`로 3개 호출부에 전달하고 `hop_guard`는 partial 바인딩, `MIN_HOST_INTERVAL_S=1.0`은 Crawl-delay 신호 소실을 메우는 하한으로 유지. SC-9·AC-B-012-6도 함께 개정(등재 의무는 "정직한 UA 200 실측 + `source` + `verified_at`"로 축소). **② NG-5 개정** — "단건 입력만" → "사용자가 명시한 유한 집합". 크롤러가 되지 않게 하는 실질 방벽은 **재귀 링크 추적 금지**이지 단건 제한이 아니다(취득 본문에서 링크를 뽑아 큐에 넣는 코드는 앞으로도 두지 않는다). **③ 자기선언 열린문 티어**(`alternates.py`, T1 실패 직후·Phase 0 앞) — JSON-LD `articleBody`·feed·amphtml·oembed·교차 오리진 canonical 중 **선언된 것만** 따라간다(R2가 0/12로 죽인 맹목적 `m.`/`amp` 접두 부착은 부활 금지), 예산 2건·후보마다 SSRF 재검사, 경계·CAPTCHA를 만나면 남은 선언을 두드리지 않고 그 사유로 즉시 종료(exit 2). **④ 병렬 배치**(`fetch --batch`, `--concurrency` 기본 4·상한 8) — 호스트당 1건 in-flight를 기존 `host_gate`로 보존하고 전역 워커만 병렬화, URL당 NDJSON 1줄. **⑤ 검색 계층**(`search "<질의>"`) — 질의→후보→배치 취득 3단, 기존 `search:`(판정 전용·요청 없음, us-b-014 동결) 오염을 피해 `search_sources:` 섹션 분리, 후보는 내놓기 전에 SSRF 가드로 거르고 제외 사실을 stderr에 남긴다(NG-10). **⑥ 본문 추출 품질** — 밀도 폴백 + 수확률 기반 성공 판정. 허용 UA 사칭은 넣지 않았다(robots를 안 보는 것과 신원을 속이는 것은 다른 일). codex 리뷰 2라운드 종결(R1 4C+1M — 전부 "대체 티어가 경계를 경계로 취급하지 않는다"는 한 결함의 다른 얼굴, R2 1M+1L — 벽 판정을 `extracted=""`로 불러 정상 피드를 auth_wall로 오판하던 위양성, 각 라운드에서 전부 수정·deferred 0). 유닛 296/296·동결 인수 18/18·`rate_http_only` 무회귀. 정직하게 남기는 것: **SC-6 holdout 미측정**(R3에서 소진, 새로 구성하지 않음), **자기선언 티어 라이브 성공 미관측**(유닛·동결 픽스처에서만 증명). 상세 `docs/r6-contract.md`. v2.0.1에서 릴리스 후 발견한 결함 1건 수정 — 수확률 판정(`_is_starved`)의 분모를 **응답 전체**로 잡아, 항목 50편짜리 피드에서 요청한 짧은 공지를 정확히 뽑고도 옆 글들의 부피 때문에 `validation_failed`로 버렸다(105KB 피드·311자 본문·수확률 0.00295 실측). 그 비율은 html이 **그 문서 하나의 그릇**이라는 전제 위에 서 있으므로 기준을 문서 자신의 그릇으로 바꿨다 — `feed_entry_for`가 고른 항목 조각을 함께 반환, oembed는 embed html, amphtml·canonical은 payload 유지. 옆 항목의 페이월 표시로 우리 글을 유죄로 만들지 않는 효과도 함께 얻는다. 리뷰 2라운드가 놓친 것은 결함이 모듈 안이 아니라 **모듈 사이**에 있었기 때문이다. 유닛 297/297·동결 인수 18/18(§15).

Key command: `/open-reach <URL>` (배치 `fetch --batch`, 검색 `search "<질의>"`)

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
