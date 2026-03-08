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

## Working with Submodules

```bash
# After cloning, init submodules
git submodule init && git submodule update

# Update all submodules to latest
git submodule foreach 'git checkout main && git pull'

# Check submodule state
git ls-tree HEAD plugins/    # Should show mode 160000
```

Each plugin has its own git repository. Changes to plugin code should be committed in the respective plugin repo first, then the submodule reference updated here.

## design-polish Setup

```bash
cd plugins/design-polish && npm install
```

Required for screenshot capture and WCAG checks. Environment variables: `BASE_URL` (default: `http://localhost:3000`), `FULL_PAGE`, `WAIT_TIME`, `TIMEOUT`.
