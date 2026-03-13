#!/usr/bin/env bash
# godot-gate.sh — Make with Godot 중앙 게이트 유틸리티
# 서브커맨드: init, init-ralph, status, update-phase, update-task, scaffold,
#   build-order, compile-check, plan-gate, scaffold-gate, impl-gate, vqa-gate,
#   final-gate, asset-integrity, scene-integrity, find-debug-code,
#   collision-setup, ui-theme, i18n-scaffold, next-task, budget-report, record-error
set -euo pipefail

PROGRESS_FILE=".claude-godot-progress.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ─── 유틸리티 ───

die() { echo "ERROR: $*" >&2; exit 1; }

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required but not installed. Install: sudo apt-get install jq"
}

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ"; }

jq_inplace() {
  local file="$1"; shift
  local tmp
  tmp=$(mktemp)
  if jq "$@" "$file" > "$tmp"; then
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
    die "jq update failed for $file"
  fi
}

require_progress() {
  [[ -f "$PROGRESS_FILE" ]] || die "Progress file not found: $PROGRESS_FILE. Run 'init' first."
}

require_godot() {
  command -v godot >/dev/null 2>&1 || die "Godot is not installed or not in PATH"
}

# project.godot 기반 프로젝트 디렉토리 자동 탐지
detect_project_dir() {
  if [[ -f "project.godot" ]]; then
    echo "."
  elif [[ -f "$PROGRESS_FILE" ]]; then
    local game_name
    game_name=$(jq -r '.gameName // empty' "$PROGRESS_FILE" 2>/dev/null)
    if [[ -n "$game_name" ]] && [[ -f "$game_name/project.godot" ]]; then
      echo "$game_name"
    else
      die "Cannot detect project directory. No project.godot found."
    fi
  else
    die "Cannot detect project directory."
  fi
}

# ─── init: progress JSON 초기화 ───

cmd_init() {
  local game_name="${1:?Usage: init <game_name> <requirement> [dimension]}"
  local requirement="${2:?Usage: init <game_name> <requirement> [dimension]}"
  local dimension="${3:-2d}"

  require_jq

  if [[ -f "$PROGRESS_FILE" ]]; then
    echo "WARNING: $PROGRESS_FILE already exists. Backing up."
    cp "$PROGRESS_FILE" "${PROGRESS_FILE}.bak.$(date +%s)"
  fi

  local template
  template=$(cat "$PLUGIN_ROOT/templates/progress.json")

  echo "$template" | jq \
    --arg name "$game_name" \
    --arg req "$requirement" \
    --arg dim "$dimension" \
    --arg ts "$(timestamp)" \
    '.gameName = $name | .requirement = $req | .dimension = $dim | .createdAt = $ts' \
    > "$PROGRESS_FILE"

  echo "OK: Progress initialized → $PROGRESS_FILE (game: $game_name, dim: $dimension)"
}

# ─── init-ralph: Ralph Loop 파일 생성 ───

cmd_init_ralph() {
  local promise="${1:?Usage: init-ralph <promise> <progress_file> [max_iter]}"
  local progress_file="${2:?Usage: init-ralph <promise> <progress_file> [max_iter]}"
  local max_iter="${3:-0}"

  if ! [[ "$max_iter" =~ ^[0-9]+$ ]]; then
    die "init-ralph: max_iter must be a non-negative integer"
  fi

  if [[ "$progress_file" == /* ]] || [[ "$progress_file" == *..* ]]; then
    die "init-ralph: relative path only, no .. allowed"
  fi

  mkdir -p .claude

  cat > ".claude/ralph-loop.local.md" <<ENDRALPH
---
active: true
iteration: 1
max_iterations: $max_iter
completion_promise: "$promise"
progress_file: "$progress_file"
started_at: "$(timestamp)"
---

이전 작업을 이어서 진행합니다.
\`$progress_file\`을 읽고 상태를 확인하세요.
현재 Phase와 태스크 상태를 파악한 후, 중단된 지점부터 재개하세요.
ENDRALPH

  echo "OK: Ralph loop initialized (promise: $promise, progress: $progress_file)"
}

# ─── status: Phase/태스크 상태 요약 ───

cmd_status() {
  require_jq
  require_progress

  echo "=== Make with Godot — Status ==="
  echo ""
  jq -r '
    "Game: \(.gameName) (\(.dimension))",
    "Requirement: \(.requirement)",
    "Current Phase: \(.currentPhase)",
    "",
    "--- Phases ---",
    (.phases | to_entries[] | "  \(.key): \(.value.name) → \(.value.status)"),
    "",
    "--- Tasks ---",
    if (.tasks | length) == 0 then "  (no tasks yet)"
    else (.tasks[] | "  [\(.id)] \(.title) → \(.status)" + if .deps and (.deps | length) > 0 then " (deps: \(.deps | join(",")))" else "" end)
    end,
    "",
    "--- Assets ---",
    "  Budget: images=\(.assets.budget.images) models=\(.assets.budget.models) sounds=\(.assets.budget.sounds) music=\(.assets.budget.music) total=$\(.assets.budget.totalCost)",
    "  Generated: \(.assets.generated | length) items",
    "",
    "--- Errors ---",
    "  Total: \(.errors | length), Escalation Level: L\(.escalation.currentLevel)"
  ' "$PROGRESS_FILE"
}

# ─── update-phase: Phase 상태 전이 ───

cmd_update_phase() {
  local phase="${1:?Usage: update-phase <phase> <status>}"
  local status="${2:?Usage: update-phase <phase> <status>}"

  require_jq
  require_progress

  # 유효한 phase 검증
  local valid_phases="phase_0 phase_1 phase_2 phase_3 phase_4 phase_5"
  echo "$valid_phases" | grep -qw "$phase" || die "Invalid phase: $phase (valid: $valid_phases)"

  # 유효한 status 검증
  local valid_statuses="pending in_progress completed failed"
  echo "$valid_statuses" | grep -qw "$status" || die "Invalid status: $status (valid: $valid_statuses)"

  jq_inplace "$PROGRESS_FILE" \
    --arg phase "$phase" \
    --arg status "$status" \
    '.phases[$phase].status = $status | .currentPhase = $phase'

  echo "OK: $phase → $status"
}

# ─── update-task: 태스크 상태 업데이트 ───

cmd_update_task() {
  local task_num="${1:?Usage: update-task <task_num> <status>}"
  local status="${2:?Usage: update-task <task_num> <status>}"

  require_jq
  require_progress

  local valid_statuses="pending ready in_progress done failed blocked"
  echo "$valid_statuses" | grep -qw "$status" || die "Invalid status: $status"

  # task_num은 1-based → 0-based index
  local idx=$((task_num - 1))

  local total
  total=$(jq '.tasks | length' "$PROGRESS_FILE")
  [[ $idx -ge 0 ]] && [[ $idx -lt $total ]] || die "Task $task_num out of range (total: $total)"

  jq_inplace "$PROGRESS_FILE" \
    --argjson idx "$idx" \
    --arg status "$status" \
    --arg ts "$(timestamp)" \
    '.tasks[$idx].status = $status | .tasks[$idx].updatedAt = $ts'

  echo "OK: Task $task_num → $status"
}

# ─── scaffold: project.godot + 디렉토리 구조 ───

cmd_scaffold() {
  local structure_md="${1:?Usage: scaffold <structure_md_path>}"

  require_jq
  require_progress

  [[ -f "$structure_md" ]] || die "STRUCTURE.md not found: $structure_md"

  local game_name dimension
  game_name=$(jq -r '.gameName' "$PROGRESS_FILE")
  dimension=$(jq -r '.dimension // "2d"' "$PROGRESS_FILE")

  # 프로젝트 디렉토리 생성
  mkdir -p "$game_name"

  # 표준 디렉토리 구조
  mkdir -p "$game_name/scenes"
  mkdir -p "$game_name/scripts"
  mkdir -p "$game_name/assets/sprites"
  mkdir -p "$game_name/assets/audio/sfx"
  mkdir -p "$game_name/assets/audio/bgm"
  mkdir -p "$game_name/assets/fonts"
  mkdir -p "$game_name/assets/models"
  mkdir -p "$game_name/assets/ui"
  mkdir -p "$game_name/resources"
  mkdir -p "$game_name/addons"

  # project.godot 복사
  local template_file="$PLUGIN_ROOT/templates/project.godot.${dimension}"
  if [[ ! -f "$template_file" ]]; then
    template_file="$PLUGIN_ROOT/templates/project.godot.2d"
  fi

  local game_desc
  game_desc=$(jq -r '.requirement // ""' "$PROGRESS_FILE")

  # sed 안전 치환: 특수문자 이스케이프
  local safe_name safe_desc
  safe_name=$(printf '%s\n' "$game_name" | sed 's/[&/\]/\\&/g')
  safe_desc=$(printf '%s\n' "$game_desc" | sed 's/[&/\]/\\&/g')

  sed -e "s/{{GAME_NAME}}/$safe_name/g" \
      -e "s/{{GAME_DESCRIPTION}}/$safe_desc/g" \
      -e '/{{INPUT_ACTIONS}}/d' \
      -e '/{{COLLISION_LAYERS}}/d' \
      "$template_file" > "$game_name/project.godot"

  # .gitignore
  cp "$PLUGIN_ROOT/templates/gitignore" "$game_name/.gitignore"

  # 기본 icon.svg (Godot 기본)
  if [[ ! -f "$game_name/icon.svg" ]]; then
    cat > "$game_name/icon.svg" <<'ENDSVG'
<svg height="128" width="128" xmlns="http://www.w3.org/2000/svg">
  <rect width="128" height="128" fill="#363d52"/>
  <text x="50%" y="55%" dominant-baseline="middle" text-anchor="middle" font-family="sans-serif" font-size="64" fill="#fff">G</text>
</svg>
ENDSVG
  fi

  echo "OK: Scaffolded project '$game_name' (${dimension}) with standard directories"
}

# ─── build-order: 씬 의존성 위상 정렬 ───

cmd_build_order() {
  local structure_md="${1:?Usage: build-order <structure_md_path>}"

  [[ -f "$structure_md" ]] || die "STRUCTURE.md not found: $structure_md"

  # STRUCTURE.md에서 씬 목록 + 의존성 추출 (간단한 파싱)
  # 형식: - scene_name.tscn (depends: dep1.tscn, dep2.tscn)
  echo "=== Scene Build Order (topological) ==="

  # 의존성이 없는 씬을 먼저, 의존성이 있는 씬을 나중에
  grep -oP '\w+\.tscn' "$structure_md" 2>/dev/null | sort -u | while read -r scene; do
    local deps
    deps=$(grep -F "$scene" "$structure_md" | grep -oP 'depends?:\s*\K[^)]+' 2>/dev/null || true)
    if [[ -z "$deps" ]]; then
      echo "L0: $scene (no deps)"
    else
      echo "L1+: $scene (deps: $deps)"
    fi
  done
}

# ─── compile-check: GDScript 구문 검증 ───

cmd_compile_check() {
  require_godot

  local project_dir
  project_dir=$(detect_project_dir)

  echo "=== Compile Check ==="

  local stderr_file
  stderr_file=$(mktemp)
  trap 'rm -f "$stderr_file"' RETURN

  local exit_code=0
  # --headless --quit로 프로젝트를 로드만 하고 종료
  # stderr를 캡처하여 에러 파싱
  godot --headless --quit --path "$project_dir" 2>"$stderr_file" || exit_code=$?

  local errors=""
  local error_count=0

  if [[ -s "$stderr_file" ]]; then
    # GDScript 에러 패턴 추출
    errors=$(grep -iE '(error|SCRIPT ERROR|Parse Error|at line|Cannot)' "$stderr_file" 2>/dev/null || true)
    error_count=$(echo "$errors" | grep -c '.' 2>/dev/null || echo "0")
  fi

  # JSON 결과 출력
  jq -n \
    --argjson exitCode "$exit_code" \
    --argjson errorCount "$error_count" \
    --arg errors "$errors" \
    --arg stderr "$(cat "$stderr_file")" \
    '{
      "command": "compile-check",
      "exitCode": $exitCode,
      "errorCount": $errorCount,
      "errors": $errors,
      "stderr": $stderr,
      "passed": ($exitCode == 0 and $errorCount == 0)
    }'

  if [[ $exit_code -ne 0 ]] || [[ $error_count -gt 0 ]]; then
    return 1
  fi
  return 0
}

# ─── plan-gate: PLAN.md 구조 검증 ───

cmd_plan_gate() {
  require_jq
  require_progress

  echo "=== Plan Gate ==="
  local errors=0

  # PLAN.md 존재 확인
  if [[ ! -f "PLAN.md" ]]; then
    echo "FAIL: PLAN.md not found"
    errors=$((errors + 1))
  else
    # 태스크 섹션 존재 확인
    if ! grep -q '## Task\|## 태스크\|### T[0-9]' PLAN.md; then
      echo "FAIL: No task sections found in PLAN.md"
      errors=$((errors + 1))
    else
      echo "OK: PLAN.md exists with task sections"
    fi
  fi

  # STRUCTURE.md 존재 확인
  if [[ ! -f "STRUCTURE.md" ]]; then
    echo "FAIL: STRUCTURE.md not found"
    errors=$((errors + 1))
  else
    echo "OK: STRUCTURE.md exists"
  fi

  # ASSETS.md 존재 확인
  if [[ ! -f "ASSETS.md" ]]; then
    echo "FAIL: ASSETS.md not found"
    errors=$((errors + 1))
  else
    echo "OK: ASSETS.md exists"
  fi

  # progress에 태스크가 로드되었는지
  local task_count
  task_count=$(jq '.tasks | length' "$PROGRESS_FILE")
  if [[ $task_count -eq 0 ]]; then
    echo "FAIL: No tasks in progress file"
    errors=$((errors + 1))
  else
    echo "OK: $task_count tasks loaded"
  fi

  if [[ $errors -gt 0 ]]; then
    echo "GATE FAILED: $errors issues"
    return 1
  fi

  echo "GATE PASSED: Plan gate OK"
  return 0
}

# ─── scaffold-gate: Phase 1 게이트 ───

cmd_scaffold_gate() {
  require_jq
  require_progress

  echo "=== Scaffold Gate ==="
  local errors=0

  local game_name
  game_name=$(jq -r '.gameName' "$PROGRESS_FILE")

  # project.godot 존재
  if [[ ! -f "$game_name/project.godot" ]]; then
    echo "FAIL: project.godot not found"
    errors=$((errors + 1))
  else
    echo "OK: project.godot exists"
  fi

  # 최소 1개 씬 존재
  local scene_count
  scene_count=$(find "$game_name/scenes" -name "*.tscn" 2>/dev/null | wc -l)
  if [[ $scene_count -eq 0 ]]; then
    echo "FAIL: No .tscn files found"
    errors=$((errors + 1))
  else
    echo "OK: $scene_count scene(s) found"
  fi

  # 최소 1개 스크립트 존재
  local script_count
  script_count=$(find "$game_name/scripts" -name "*.gd" 2>/dev/null | wc -l)
  if [[ $script_count -eq 0 ]]; then
    echo "FAIL: No .gd scripts found"
    errors=$((errors + 1))
  else
    echo "OK: $script_count script(s) found"
  fi

  # 컴파일 체크
  if ! cmd_compile_check > /dev/null 2>&1; then
    echo "FAIL: Compile check failed"
    errors=$((errors + 1))
  else
    echo "OK: Compile check passed"
  fi

  if [[ $errors -gt 0 ]]; then
    echo "GATE FAILED: $errors issues"
    return 1
  fi

  echo "GATE PASSED: Scaffold gate OK"
  return 0
}

# ─── impl-gate: Phase 2 게이트 ───

cmd_impl_gate() {
  require_jq
  require_progress

  echo "=== Implementation Gate ==="
  local errors=0

  # 모든 태스크가 done인지
  local pending
  pending=$(jq '[.tasks[] | select(.status != "done")] | length' "$PROGRESS_FILE")
  if [[ $pending -gt 0 ]]; then
    echo "FAIL: $pending tasks not done"
    jq -r '.tasks[] | select(.status != "done") | "  [\(.id)] \(.title) → \(.status)"' "$PROGRESS_FILE"
    errors=$((errors + 1))
  else
    echo "OK: All tasks done"
  fi

  # 컴파일 체크
  if ! cmd_compile_check > /dev/null 2>&1; then
    echo "FAIL: Compile check failed"
    errors=$((errors + 1))
  else
    echo "OK: Compile check passed"
  fi

  if [[ $errors -gt 0 ]]; then
    echo "GATE FAILED: $errors issues"
    return 1
  fi

  echo "GATE PASSED: Implementation gate OK"
  return 0
}

# ─── vqa-gate: Phase 3 게이트 ───

cmd_vqa_gate() {
  require_jq
  require_progress

  echo "=== VQA Gate ==="

  local rounds
  rounds=$(jq '.vqa.rounds | length' "$PROGRESS_FILE")
  if [[ $rounds -eq 0 ]]; then
    echo "FAIL: No VQA rounds recorded"
    return 1
  fi

  # 마지막 라운드의 verdict 확인
  local last_verdict
  last_verdict=$(jq -r '.vqa.rounds[-1].verdict // "unknown"' "$PROGRESS_FILE")

  if [[ "$last_verdict" == "pass" ]] || [[ "$last_verdict" == "acceptable" ]]; then
    echo "GATE PASSED: VQA verdict = $last_verdict"
    return 0
  fi

  echo "FAIL: VQA verdict = $last_verdict (need pass or acceptable)"
  return 1
}

# ─── final-gate: Phase 4 게이트 ───

cmd_final_gate() {
  require_jq
  require_progress

  echo "=== Final Gate ==="
  local errors=0

  # 컴파일 체크
  if ! cmd_compile_check > /dev/null 2>&1; then
    echo "FAIL: Compile check failed"
    errors=$((errors + 1))
  else
    echo "OK: Compile check passed"
  fi

  # 에셋 정합성
  if ! cmd_asset_integrity > /dev/null 2>&1; then
    echo "FAIL: Asset integrity failed"
    errors=$((errors + 1))
  else
    echo "OK: Asset integrity passed"
  fi

  # 비디오 존재
  local game_name
  game_name=$(jq -r '.gameName' "$PROGRESS_FILE")
  if ! find . -maxdepth 2 -name "*.mp4" 2>/dev/null | grep -q .; then
    echo "WARN: No gameplay video found (non-blocking)"
  else
    echo "OK: Gameplay video exists"
  fi

  # 디버그 코드 확인
  local debug_count
  debug_count=$(cmd_find_debug_code 2>/dev/null | grep -c "FOUND" || echo "0")
  if [[ $debug_count -gt 0 ]]; then
    echo "WARN: $debug_count debug code instances found (non-blocking)"
  else
    echo "OK: No debug code found"
  fi

  if [[ $errors -gt 0 ]]; then
    echo "GATE FAILED: $errors issues"
    return 1
  fi

  echo "GATE PASSED: Final gate OK"
  return 0
}

# ─── asset-integrity: 에셋 존재/형식 검증 ───

cmd_asset_integrity() {
  require_jq
  require_progress

  echo "=== Asset Integrity Check ==="
  local errors=0
  local game_name
  game_name=$(jq -r '.gameName' "$PROGRESS_FILE")

  # progress에 기록된 에셋들이 실제 존재하는지
  local asset_count
  asset_count=$(jq '.assets.generated | length' "$PROGRESS_FILE")

  if [[ $asset_count -eq 0 ]]; then
    echo "INFO: No assets recorded in progress"
    echo "Asset integrity check: OK (0 assets)"
    return 0
  fi

  for i in $(seq 0 $((asset_count - 1))); do
    local path type
    path=$(jq -r ".assets.generated[$i].path" "$PROGRESS_FILE")
    type=$(jq -r ".assets.generated[$i].type" "$PROGRESS_FILE")

    if [[ ! -f "$path" ]]; then
      echo "FAIL: Missing asset: $path ($type)"
      errors=$((errors + 1))
      continue
    fi

    # 매직 바이트 검증
    case "$type" in
      png)
        if ! file "$path" | grep -qi "png"; then
          echo "FAIL: $path is not a valid PNG"
          errors=$((errors + 1))
        fi
        ;;
      jpg|jpeg)
        if ! file "$path" | grep -qi "jpeg\|jpg"; then
          echo "FAIL: $path is not a valid JPEG"
          errors=$((errors + 1))
        fi
        ;;
      wav)
        if ! file "$path" | grep -qi "wave\|wav\|riff"; then
          echo "FAIL: $path is not a valid WAV"
          errors=$((errors + 1))
        fi
        ;;
      ogg)
        if ! file "$path" | grep -qi "ogg\|vorbis"; then
          echo "FAIL: $path is not a valid OGG"
          errors=$((errors + 1))
        fi
        ;;
      glb|gltf)
        if ! file "$path" | grep -qi "gltf\|glb\|binary"; then
          echo "WARN: Cannot verify GLB format for $path"
        fi
        ;;
      *)
        echo "OK: $path ($type) — format check skipped"
        ;;
    esac
  done

  if [[ $asset_count -eq 0 ]]; then
    echo "WARN: No assets registered in progress file"
  fi

  if [[ $errors -gt 0 ]]; then
    echo "INTEGRITY FAILED: $errors issues"
    return 1
  fi

  echo "INTEGRITY PASSED: All $asset_count assets OK"
  return 0
}

# ─── scene-integrity: .tscn 참조 검증 ───

cmd_scene_integrity() {
  require_progress

  echo "=== Scene Integrity Check ==="
  local errors=0
  local project_dir
  project_dir=$(detect_project_dir)

  # 모든 .tscn/.tres 파일에서 ext_resource 경로 추출 + 존재 확인
  while IFS= read -r tscn_file; do
    # ext_resource에서 path="res://..." 추출
    while IFS= read -r res_path; do
      local full_path="$project_dir/$res_path"
      if [[ ! -f "$full_path" ]]; then
        echo "FAIL: $tscn_file references missing: res://$res_path"
        errors=$((errors + 1))
      fi
    done < <(grep -oP 'path="res://\K[^"]+' "$tscn_file" 2>/dev/null || true)

    # load("res://...") 패턴도 확인
    while IFS= read -r res_path; do
      local full_path="$project_dir/$res_path"
      if [[ ! -f "$full_path" ]]; then
        echo "FAIL: $tscn_file loads missing: res://$res_path"
        errors=$((errors + 1))
      fi
    done < <(grep -oP 'load\("res://\K[^"]+' "$tscn_file" 2>/dev/null || true)
  done < <(find "$project_dir" -name "*.tscn" -o -name "*.tres" 2>/dev/null)

  # .gd 스크립트의 load/preload 참조도 확인
  while IFS= read -r gd_file; do
    while IFS= read -r res_path; do
      local full_path="$project_dir/$res_path"
      if [[ ! -f "$full_path" ]]; then
        echo "FAIL: $gd_file loads missing: res://$res_path"
        errors=$((errors + 1))
      fi
    done < <(grep -oP '(?:pre)?load\("res://\K[^"]+' "$gd_file" 2>/dev/null || true)
  done < <(find "$project_dir" -name "*.gd" 2>/dev/null)

  if [[ $errors -gt 0 ]]; then
    echo "SCENE INTEGRITY FAILED: $errors broken references"
    return 1
  fi

  echo "SCENE INTEGRITY PASSED"
  return 0
}

# ─── find-debug-code: print/breakpoint 탐색 ───

cmd_find_debug_code() {
  local dir="${1:-$(detect_project_dir)}"

  echo "=== Debug Code Search ==="

  # GDScript 디버그 패턴
  local patterns=(
    'print('
    'print_debug('
    'breakpoint'
    'assert('
    'OS.alert('
    'push_warning('
    'push_error('
  )

  local found=0
  for pattern in "${patterns[@]}"; do
    local matches
    matches=$(grep -rn "$pattern" "$dir" --include="*.gd" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      echo "FOUND [$pattern]:"
      echo "$matches" | head -20
      found=$((found + 1))
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo "CLEAN: No debug code found"
  else
    echo "TOTAL: $found debug patterns found"
  fi
}

# ─── collision-setup: 충돌 레이어/마스크 설정 ───

cmd_collision_setup() {
  local structure_md="${1:?Usage: collision-setup <structure_md_path>}"

  require_progress

  [[ -f "$structure_md" ]] || die "STRUCTURE.md not found: $structure_md"

  local game_name
  game_name=$(jq -r '.gameName' "$PROGRESS_FILE")
  local project_godot="$game_name/project.godot"

  [[ -f "$project_godot" ]] || die "project.godot not found. Run scaffold first."

  echo "=== Collision Layer Setup ==="

  # STRUCTURE.md에서 collision_layers 섹션 파싱
  # 형식: Layer N: name (예: Layer 1: player, Layer 2: enemy)
  local layer_config=""
  local found_section=false

  while IFS= read -r line; do
    if echo "$line" | grep -qi 'collision.*layer\|충돌.*레이어'; then
      found_section=true
      continue
    fi
    if $found_section; then
      if echo "$line" | grep -qP '^#+\s|^$' && [[ -n "$layer_config" ]]; then
        break
      fi
      if echo "$line" | grep -qP 'Layer\s*\d+'; then
        local num name
        num=$(echo "$line" | grep -oP '\d+' | head -1)
        name=$(echo "$line" | grep -oP ':\s*\K\w+' | head -1)
        if [[ -n "$num" ]] && [[ -n "$name" ]]; then
          layer_config="${layer_config}2d_physics/layer_${num}=\"${name}\"\n"
          layer_config="${layer_config}3d_physics/layer_${num}=\"${name}\"\n"
        fi
      fi
    fi
  done < "$structure_md"

  if [[ -z "$layer_config" ]]; then
    echo "WARN: No collision layers found in STRUCTURE.md. Using defaults."
    layer_config='2d_physics/layer_1="player"\n2d_physics/layer_2="enemy"\n2d_physics/layer_3="projectile"\n2d_physics/layer_4="environment"\n'
  fi

  # project.godot의 [layer_names] 섹션에 추가
  local resolved_config
  resolved_config=$(printf '%b' "$layer_config")

  if grep -q '\[layer_names\]' "$project_godot"; then
    # 기존 섹션에 추가 — sed -i 이식성 문제 방지를 위해 임시 파일 사용
    local tmp_godot
    tmp_godot=$(mktemp)
    awk -v cfg="$resolved_config" '/\[layer_names\]/{print; print cfg; next}1' "$project_godot" > "$tmp_godot" && mv "$tmp_godot" "$project_godot"
  else
    # 섹션 추가
    printf '\n[layer_names]\n%s\n' "$resolved_config" >> "$project_godot"
  fi

  echo "OK: Collision layers configured"
}

# ─── ui-theme: 기본 UI 테마 생성 ───

cmd_ui_theme() {
  local style="${1:-default}"

  require_progress

  local game_name
  game_name=$(jq -r '.gameName' "$PROGRESS_FILE")

  mkdir -p "$game_name/resources"

  cat > "$game_name/resources/default_theme.tres" <<'ENDTHEME'
[gd_resource type="Theme" format=3]

[resource]
default_font_size = 16

Button/colors/font_color = Color(1, 1, 1, 1)
Button/colors/font_hover_color = Color(1, 1, 0.8, 1)
Button/colors/font_pressed_color = Color(0.8, 0.8, 0.8, 1)
Button/font_sizes/font_size = 18

Label/colors/font_color = Color(1, 1, 1, 1)
Label/font_sizes/font_size = 16

Panel/styles/panel = null
ENDTHEME

  echo "OK: Default UI theme created → $game_name/resources/default_theme.tres"
}

# ─── i18n-scaffold: 다국어 CSV 구조 생성 ───

cmd_i18n_scaffold() {
  local languages="${1:-en,ko,ja}"

  require_progress

  local game_name
  game_name=$(jq -r '.gameName' "$PROGRESS_FILE")

  mkdir -p "$game_name/translation"

  # CSV 헤더: keys,en,ko,ja,...
  local header="keys"
  IFS=',' read -ra langs <<< "$languages"
  for lang in "${langs[@]}"; do
    header="$header,$lang"
  done

  # 기본 키 포함한 CSV 생성
  cat > "$game_name/translation/messages.csv" <<ENDCSV
$header
MENU_START,Start,시작,スタート
MENU_QUIT,Quit,종료,終了
MENU_SETTINGS,Settings,설정,設定
GAME_OVER,Game Over,게임 오버,ゲームオーバー
GAME_SCORE,Score,점수,スコア
ENDCSV

  # project.godot에 locale 설정 추가
  local project_godot="$game_name/project.godot"
  if [[ -f "$project_godot" ]]; then
    if ! grep -q '\[internationalization\]' "$project_godot"; then
      local locale_list=""
      for lang in "${langs[@]}"; do
        locale_list="${locale_list}\"${lang}\", "
      done
      locale_list="${locale_list%, }"

      cat >> "$project_godot" <<ENDI18N

[internationalization]

locale/translations=PackedStringArray("res://translation/messages.csv")
locale/locale_filter_mode=1
locale/locale_filter=PackedStringArray($locale_list)
ENDI18N
    fi
  fi

  echo "OK: i18n scaffold created (languages: $languages)"
}

# ─── next-task: 다음 ready 태스크 ───

cmd_next_task() {
  require_jq
  require_progress

  # status가 "ready"인 첫 번째 태스크 반환
  local next
  next=$(jq -r '
    [.tasks[] | select(.status == "ready")] |
    if length > 0 then .[0] | "\(.id) \(.title)"
    else empty
    end
  ' "$PROGRESS_FILE")

  if [[ -z "$next" ]]; then
    # ready가 없으면 pending 중 deps가 모두 done인 태스크를 ready로 전환
    local promoted=false
    local task_count
    task_count=$(jq '.tasks | length' "$PROGRESS_FILE")

    for i in $(seq 0 $((task_count - 1))); do
      local status deps_met
      status=$(jq -r ".tasks[$i].status" "$PROGRESS_FILE")

      if [[ "$status" != "pending" ]]; then
        continue
      fi

      # 의존성 확인: deps 배열의 모든 태스크가 done인지
      deps_met=$(jq -r "
        .tasks[$i].deps as \$deps |
        if (\$deps == null) or (\$deps | length == 0) then true
        else
          [.tasks[] | select(.id as \$id | \$deps | index(\$id)) | .status == \"done\"] | all
        end
      " "$PROGRESS_FILE")

      if [[ "$deps_met" == "true" ]]; then
        jq_inplace "$PROGRESS_FILE" --argjson idx "$i" '.tasks[$idx].status = "ready"'
        promoted=true
      fi
    done

    if $promoted; then
      next=$(jq -r '[.tasks[] | select(.status == "ready")] | .[0] | "\(.id) \(.title)"' "$PROGRESS_FILE")
    fi
  fi

  if [[ -z "$next" ]]; then
    echo "NO_TASKS_READY"
    return 1
  fi

  echo "$next"
}

# ─── budget-report: 예산 집계 ───

cmd_budget_report() {
  require_jq
  require_progress

  echo "=== Asset Budget Report ==="
  jq -r '
    .assets.budget as $b |
    "Images:  \($b.images) generated",
    "Models:  \($b.models) generated",
    "Sounds:  \($b.sounds) generated",
    "Music:   \($b.music) generated",
    "Total Cost: $\($b.totalCost)",
    "",
    "--- Generated Assets ---",
    if (.assets.generated | length) == 0 then "  (none)"
    else (.assets.generated[] | "  \(.type): \(.path) ($\(.cost // 0))")
    end,
    "",
    "--- Scope Reductions ---",
    if (.scopeReductions | length) == 0 then "  (none)"
    else (.scopeReductions[] | "  [\(.task)]: \(.reason)")
    end
  ' "$PROGRESS_FILE"
}

# ─── record-error: 에러 기록 + 에스컬레이션 ───

cmd_record_error() {
  require_jq
  require_progress

  local file="" type="" msg="" level="" action=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --msg) msg="$2"; shift 2 ;;
      --level) level="$2"; shift 2 ;;
      --action) action="$2"; shift 2 ;;
      *) echo "WARNING: record-error: unknown option '$1'" >&2; shift ;;
    esac
  done

  [[ -n "$msg" ]] || die "record-error: --msg required"
  [[ -n "$level" ]] || level="L0"

  # 레벨 번호 추출
  local level_num
  level_num=$(echo "$level" | grep -oP '\d+' || echo "0")

  # 에러 기록
  jq_inplace "$PROGRESS_FILE" \
    --arg file "$file" \
    --arg type "$type" \
    --arg msg "$msg" \
    --arg level "$level" \
    --arg action "$action" \
    --arg ts "$(timestamp)" \
    '.errors += [{"file": $file, "type": $type, "msg": $msg, "level": $level, "action": $action, "timestamp": $ts}]'

  # 에스컬레이션 체크
  local budget attempts
  budget=$(jq ".escalation.levelBudgets[$level_num]" "$PROGRESS_FILE")
  jq_inplace "$PROGRESS_FILE" --argjson ln "$level_num" '.escalation.levelAttempts[$ln] += 1'
  attempts=$(jq ".escalation.levelAttempts[$level_num]" "$PROGRESS_FILE")

  if [[ $attempts -ge $budget ]]; then
    # 예산 소진 → 다음 레벨로 에스컬레이트
    local next_level=$((level_num + 1))
    jq_inplace "$PROGRESS_FILE" --argjson nl "$next_level" '.escalation.currentLevel = $nl'

    case $next_level in
      2) echo "ESCALATE: L2 reached → codex analysis needed"; return 2 ;;
      5) echo "ESCALATE: L5 reached → user intervention required"; return 3 ;;
      *) echo "ESCALATE: L$level_num budget exhausted → moving to L$next_level"; return 1 ;;
    esac
  fi

  echo "OK: Error recorded (L$level_num, attempt $attempts/$budget)"
  return 0
}

# ─── 메인 디스패처 ───

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    init)             cmd_init "$@" ;;
    init-ralph)       cmd_init_ralph "$@" ;;
    status)           cmd_status "$@" ;;
    update-phase)     cmd_update_phase "$@" ;;
    update-task)      cmd_update_task "$@" ;;
    scaffold)         cmd_scaffold "$@" ;;
    build-order)      cmd_build_order "$@" ;;
    compile-check)    cmd_compile_check "$@" ;;
    plan-gate)        cmd_plan_gate "$@" ;;
    scaffold-gate)    cmd_scaffold_gate "$@" ;;
    impl-gate)        cmd_impl_gate "$@" ;;
    vqa-gate)         cmd_vqa_gate "$@" ;;
    final-gate)       cmd_final_gate "$@" ;;
    asset-integrity)  cmd_asset_integrity "$@" ;;
    scene-integrity)  cmd_scene_integrity "$@" ;;
    find-debug-code)  cmd_find_debug_code "$@" ;;
    collision-setup)  cmd_collision_setup "$@" ;;
    ui-theme)         cmd_ui_theme "$@" ;;
    i18n-scaffold)    cmd_i18n_scaffold "$@" ;;
    next-task)        cmd_next_task "$@" ;;
    budget-report)    cmd_budget_report "$@" ;;
    record-error)     cmd_record_error "$@" ;;
    help|--help|-h)
      echo "Usage: godot-gate.sh <command> [args...]"
      echo ""
      echo "Commands:"
      echo "  init <game_name> <requirement> [dim]  Initialize progress"
      echo "  init-ralph <promise> <progress> [max]  Setup Ralph Loop"
      echo "  status                                  Show status"
      echo "  update-phase <phase> <status>           Update phase"
      echo "  update-task <num> <status>              Update task"
      echo "  scaffold <structure_md>                 Create project"
      echo "  build-order <structure_md>              Scene build order"
      echo "  compile-check                           GDScript validation"
      echo "  plan-gate                               Phase 0 gate"
      echo "  scaffold-gate                           Phase 1 gate"
      echo "  impl-gate                               Phase 2 gate"
      echo "  vqa-gate                                Phase 3 gate"
      echo "  final-gate                              Phase 4 gate"
      echo "  asset-integrity                         Asset validation"
      echo "  scene-integrity                         Scene ref check"
      echo "  find-debug-code [dir]                   Find debug code"
      echo "  collision-setup <structure_md>           Setup collision layers"
      echo "  ui-theme [style]                        Generate UI theme"
      echo "  i18n-scaffold [languages]               Create i18n CSV"
      echo "  next-task                               Next ready task"
      echo "  budget-report                           Asset budget summary"
      echo "  record-error --msg <m> [--level L0-L5]  Record error"
      ;;
    *)
      die "Unknown command: $cmd (try 'help')"
      ;;
  esac
}

main "$@"
