# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

This is `devncat` — a **Claude Code plugin marketplace** that bundles three plugins as git submodules under `plugins/`. It is NOT a Flutter application itself; it provides Claude Code skills/commands for Flutter development and other workflows.

GitHub: `vp-k/devncat`

## Repository Structure

```
.claude-plugin/marketplace.json   # Marketplace manifest (lists 3 plugins)
plugins/
├── flutter-craft/                 # Git submodule → vp-k/flutter-craft
├── design-polish/                 # Git submodule → vp-k/design-polish
├── auto-complete-loop/            # Git submodule → vp-k/auto-complete-loop
└── multi-ai-roundtable/           # Git submodule → vp-k/multi-ai-roundtable
```

## Plugins

### flutter-craft (v1.1.2)
Flutter Feature-Driven Development with Clean Architecture. Provides a full workflow: brainstorm → plan → execute → verify → finish. Enforces Clean Architecture layer order (domain → data → presentation) and priority-based testing (Repository → State → Widget).

Key commands: `/brainstorm`, `/plan`, `/execute`

### design-polish (v2.0)
Design polishing with WCAG accessibility checks. Has a built-in BM25 search engine over design knowledge (66 styles, 96 palettes, 57 typography pairings). Requires `npm install` for puppeteer + axe-core.

Key commands: `/design-polish`, `/design-renewal`

### auto-complete-loop (v2.2.1)
AI coding completion framework with Ralph Loop + DoD/SPEC/TDD verification. Orchestrates full project lifecycle: PM Planning → Doc Planning → Implementation → Code Review → Verification.

Key command: `/full-auto <requirements>` (runs all phases), plus standalone commands like `/code-review-loop`, `/plan-docs-auto`, `/implement-docs-auto`

### multi-ai-roundtable (v1.1.0)
다자 AI 토론 워크플로우. 실제 codex / gemini CLI 바이너리를 Bash로 직접 호출(기본 모드: `codex` only, `--both`로 둘 다, `--gemini-only`로 gemini만)하여 다른 모델의 관점을 수집한 뒤, Claude가 중재·합성하여 합의 로드맵을 도출하고 병렬 에이전트로 실행. quota 감지 시 즉시 Claude 폴백.

Key command: `/roundtable [--both | --gemini-only] <프로젝트 경로 또는 설명>`

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
