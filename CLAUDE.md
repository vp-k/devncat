# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

This is `flutter-craft` — a **Claude Code plugin marketplace** (codename: "bitlab") that bundles three plugins as git submodules under `plugins/`. It is NOT a Flutter application itself; it provides Claude Code skills/commands for Flutter development and other workflows.

The repo is also registered as a submodule in the parent marketplace at `vp-k/devncat`.

## Repository Structure

```
.claude-plugin/marketplace.json   # Marketplace manifest (lists 3 plugins)
plugins/
├── flutter-craft/                 # Git submodule → vp-k/flutter-craft
├── design-polish/                 # Git submodule → vp-k/design-polish
└── auto-complete-loop/            # Git submodule → vp-k/auto-complete-loop
.tmp_pm_skills/                    # Vendored PM skills (pm-skills marketplace by Paweł Huryn)
```

## The Three Plugins

### flutter-craft (v1.1.2)
Flutter Feature-Driven Development with Clean Architecture. Provides a full workflow: brainstorm → plan → execute → verify → finish. Enforces Clean Architecture layer order (domain → data → presentation) and priority-based testing (Repository → State → Widget).

Key commands: `/brainstorm`, `/plan`, `/execute`

### design-polish (v2.0)
Design polishing with WCAG accessibility checks. Has a built-in BM25 search engine over design knowledge (66 styles, 96 palettes, 57 typography pairings). Requires `npm install` for puppeteer + axe-core.

Key commands: `/design-polish`, `/design-renewal`

### auto-complete-loop
AI coding completion framework with Ralph Loop + DoD/SPEC/TDD verification. Orchestrates full project lifecycle: PM Planning → Doc Planning → Implementation → Code Review → Verification.

Key command: `/full-auto <requirements>` (runs all phases), plus standalone commands like `/code-review-loop`, `/plan-docs-auto`, `/implement-docs-auto`

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

### ❌ 절대 하지 말 것

- **루트에서 `plugins/` 내부 파일을 직접 `git add`하지 않는다** — 서브모듈이 깨짐
- **코드 리뷰 등 자동화 수정 후 루트에서만 커밋하지 않는다** — 각 플러그인 레포에 먼저 푸시

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
