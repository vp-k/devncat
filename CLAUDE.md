# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

This is `devncat` — a **Claude Code plugin marketplace** that bundles six plugins as git submodules under `plugins/`. It is NOT a Flutter application itself; it provides Claude Code skills/commands for Flutter development and other workflows.

GitHub: `vp-k/devncat`

## Repository Structure

```
.claude-plugin/marketplace.json   # Marketplace manifest (lists 6 plugins)
plugins/
├── flutter-craft/                 # Git submodule → vp-k/flutter-craft
├── design-polish/                 # Git submodule → vp-k/design-polish
├── auto-complete-loop/            # Git submodule → vp-k/auto-complete-loop
├── godot-craft/                   # Git submodule → vp-k/godot-craft
├── multi-ai-roundtable/           # Git submodule → vp-k/multi-ai-roundtable
└── product-discovery/             # Git submodule → vp-k/product-discovery
```

## Plugins

### flutter-craft (v1.2.1)
Flutter Feature-Driven Development with Clean Architecture. Provides a full workflow: brainstorm → plan → execute → verify → finish. Enforces Clean Architecture layer order (domain → data → presentation) and priority-based testing (Repository → State → Widget).

Key commands: `/brainstorm`, `/plan`, `/execute`

### design-polish (v2.1.0)
Design polishing with WCAG accessibility checks. Has a built-in BM25 search engine over design knowledge (66 styles, 96 palettes, 57 typography pairings). Requires `npm install` for puppeteer + axe-core.

Key commands: `/design-polish`, `/design-renewal`

### auto-complete-loop (v4.6.0)
AI coding completion framework with Ralph Loop + DoD/SPEC/TDD verification. Orchestrates full project lifecycle: PM Planning → Doc Planning → Implementation → Code Review → Verification.

Key command: `/full-auto <requirements>` (runs all phases), plus standalone commands like `/plan-docs-full` (PM + Doc planning only with 4 strict gates), `/code-review-loop`, `/plan-docs-auto`, `/implement-docs-auto`

리뷰 모드: `solo`(Claude 서브에이전트 3개 병렬, 폴백 순차) / `codex`(기본, Claude+codex 2자) / `dual`(codex 2회 분할 병렬 독립 리뷰+Claude, 3자) / `teams`. v3.0.0에서 종료된 gemini CLI를 `dual`로 교체, v3.1.0에서 리뷰 프롬프트 단일화·quality-gate 캐시·템플릿 lazy-load·stop-hook 하드닝, v4.0.0에서 제품 발견 도구를 product-discovery 플러그인으로 분리(BREAKING: `/interview-*`, `/post-analysis` 제거) + solo/dual 병렬화 + admin.sh 모듈 분할, v4.1.0에서 하드 게이팅 배선 완성 — 기획 게이트·live-testing·레이어 커버리지·코드리뷰 finding이 verification.json 기록을 거쳐 stop-hook에서 결정적으로 차단(fail-closed), 자기신고 DoD 제거, 스펙 공백 시 임의 구현 금지 절차, runtime-gate(서버 1회 기동 통합 검증), verification-auditor fresh-context 교차 감사 배선. v4.2.0에서 인수 테스트 선작성+동결(TDD red→green) — 기획 Phase가 SPEC AC로부터 실행 가능한 인수 테스트(`tests/acceptance/`)를 생성해 해시 동결(`acceptance-freeze`), 구현 Phase는 수정 불가(훅 차단+`acceptance-gate` 해시 무결성), 완주하려면 동결된 테스트 green 필수. 스펙 변경은 사용자 승인 → `--approved-by-user` 재동결(이력 기록)로만. v4.3.0에서 verification.json 조작 차단(Edit/Write block + Bash 쓰기 가드) + lesson 메모리 루프("기억은 다음 실행 조건": 3-strike·L3+ 에스컬레이션·완주 교훈을 `.claude/acl-learnings.local.md`에 기록, session-start가 다음 세션에 주입) + SOFT 게이트 2연속 fail→HARD 승격. v4.4.0에서 4-렌즈 독립 감사(E2E 완주 스모크·셸 견고성·계약 전수·훅 상호작용) 수정 — 훅 입력 stdin 규약(promise 감지 복구+무한루프 탈출), DoD setter 부재 데드락 해소, jq 원자성 self-heal, 권한 프롬프트 우회 제거, 비플러그인 프로젝트 오탐 게이팅, E2E 하드 트랩(루트 404 서버·SPEC 부정 케이스) 해소, Bash 훅 단일 디스패처 통합. v4.6.0에서 `/check-docs` 현행화 — doc-consistency/doc-code-check가 dod·verification.json 자동 기록(모델 직접 세팅 금지, doc-check 템플릿에 `no_definition_conflict` 추가), 1단계에 definition-conflict·clarification-gate 편입([NEEDS-CLARIFICATION] 잔존 시 AskUserQuestion 예외), handoff-update 서브커맨드 사용, `--mode solo`(fresh-context 서브에이전트) 지원, 보호 파일 가드 차단 시 절차 명문화.

### godot-craft (v1.2.1)
텍스트 한 줄로 플레이 가능한 Godot 4 게임을 자율 생성하는 6-Phase 파이프라인 (Concept → Scaffold → Implement → Test → Review → Verify). 이미지 에셋 생성(Gemini API/Flux/Worker)과 Gemini Flash 기반 Visual QA 포함.

### product-discovery (v1.0.0)
제품 발견 도구. 사용자 인터뷰 준비/분석 (The Mom Test) + 출시 후 분석 (지표 추천/회고/런치 분석/경쟁 구도). auto-complete-loop v4.0.0에서 분리됨.

Key commands: `/interview-prep <기획문서>`, `/interview-summary <녹취>`, `/post-analysis [--only metrics|retro|launch|competitive]`

### multi-ai-roundtable (v2.0.0)
AI 토론 워크플로우. 실제 codex 바이너리를 Bash로 직접 호출해 비판적 관점을 수집하고, 여기에 Claude의 창의적 대안 관점을 더한 뒤, Claude가 중재·합성하여 합의 로드맵을 도출하고 병렬 에이전트로 실행. quota 감지 시 즉시 Claude 폴백. (종료된 gemini CLI를 두 번째 외부 CLI에서 제거 — v2.0.0. 이제 외부 CLI는 codex 하나)

Key command: `/roundtable <프로젝트 경로 또는 설명>`

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
