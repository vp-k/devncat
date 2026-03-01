#!/usr/bin/env bash
# shared-gate.sh — 모든 auto-complete-loop 스킬용 범용 품질 게이트 + 유틸리티
# 토큰 절약: Claude가 직접 하면 토큰 소비되는 반복 작업을 스크립트로 대체
#
# 서브커맨드:
#   init [--template <type>] [project] [requirement]  - progress JSON 초기화
#   init-ralph <promise> <progress_file> [max_iter]    - Ralph Loop 파일 생성
#   status [--progress-file <path>]                    - 현재 상태 요약 출력
#   update-step <step_name> <status> [--progress-file] - 단계 상태 전이
#   quality-gate [--progress-file <path>]              - 빌드/타입/린트/테스트 일괄 실행
#   record-error --file <f> --type <t> --msg <m> [--progress-file] - 에러 반복 판별
#   check-tools                                         - codex/gemini CLI 존재 확인
#   find-debug-code [dir]                              - console.log/print/debugger 탐색
#   doc-consistency [docs_dir]                         - 문서 간 일관성 검사
#   doc-code-check [docs_dir]                          - 문서↔코드 매칭

set -euo pipefail

VERIFICATION_FILE=".claude-verification.json"

# ─── 유틸리티 ───

die() { echo "ERROR: $*" >&2; exit 1; }

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
}

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ"; }

# 안전한 jq 인플레이스 업데이트 (temp 파일 자동 정리)
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

# Progress 파일 자동 탐지
detect_progress_file() {
  for f in .claude-full-auto-progress.json .claude-progress.json \
           .claude-plan-progress.json .claude-polish-progress.json \
           .claude-review-loop-progress.json; do
    [[ -f "$f" ]] && echo "$f" && return 0
  done
  return 1
}

# --progress-file 인수 파싱 (글로벌)
PROGRESS_FILE=""
parse_progress_file_arg() {
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --progress-file)
        PROGRESS_FILE="${2:?--progress-file requires a path}"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done
  # PROGRESS_FILE이 설정되지 않았으면 자동 탐지
  if [[ -z "$PROGRESS_FILE" ]]; then
    PROGRESS_FILE=$(detect_progress_file) || true
  fi
  # 나머지 인수를 REMAINING_ARGS에 저장
  REMAINING_ARGS=("${args[@]+"${args[@]}"}")
}

require_progress() {
  [[ -n "$PROGRESS_FILE" ]] && [[ -f "$PROGRESS_FILE" ]] || die "Progress file not found. Specify --progress-file or run 'init' first."
}

# ─── init: progress JSON 초기화 ───

cmd_init() {
  local template="full-auto"
  local project="unnamed"
  local requirement=""

  # 인수 파싱
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template)
        template="${2:?--template requires a type}"
        shift 2
        ;;
      *)
        if [[ "$project" == "unnamed" ]]; then
          project="$1"
        else
          requirement="$1"
        fi
        shift
        ;;
    esac
  done

  require_jq

  # 템플릿별 파일명 결정
  local target_file
  case "$template" in
    full-auto)  target_file=".claude-full-auto-progress.json" ;;
    plan)       target_file=".claude-plan-progress.json" ;;
    implement)  target_file=".claude-progress.json" ;;
    review)     target_file=".claude-review-loop-progress.json" ;;
    polish)     target_file=".claude-polish-progress.json" ;;
    *)          die "Unknown template: $template. Valid: full-auto, plan, implement, review, polish" ;;
  esac

  if [[ -f "$target_file" ]]; then
    echo "WARNING: $target_file already exists. Skipping init."
    return 0
  fi

  local safe_project safe_requirement
  safe_project=$(jq -Rn --arg v "$project" '$v')
  safe_requirement=$(jq -Rn --arg v "$requirement" '$v')

  case "$template" in
    full-auto)
      cat > "$target_file" <<ENDJSON
{
  "project": $safe_project,
  "userRequirement": $safe_requirement,
  "status": "in_progress",
  "currentPhase": "phase_0",
  "steps": [
    {"name": "phase_0", "label": "PM Planning", "status": "in_progress"},
    {"name": "phase_1", "label": "Planning", "status": "pending"},
    {"name": "phase_2", "label": "Implementation", "status": "pending"},
    {"name": "phase_3", "label": "Code Review", "status": "pending"},
    {"name": "phase_4", "label": "Verification", "status": "pending"}
  ],
  "phases": {
    "phase_0": { "outputs": { "definitionDoc": null, "readmePath": null, "techStack": null, "rounds": [] } },
    "phase_1": { "documents": [], "currentDocument": null },
    "phase_2": { "documents": [], "currentDocument": null, "errorHistory": {}, "completedFiles": [], "context": {}, "documentSummaries": {} },
    "phase_3": { "currentRound": 0, "roundResults": [], "findingHistory": [] },
    "phase_4": { "verificationSteps": [] }
  },
  "consistencyChecks": {
    "doc_vs_doc": { "checked": false, "evidence": null },
    "doc_vs_code": { "checked": false, "evidence": null },
    "code_quality": { "checked": false, "evidence": null }
  },
  "dod": {
    "pm_approved": { "checked": false, "evidence": null },
    "all_docs_complete": { "checked": false, "evidence": null },
    "all_code_implemented": { "checked": false, "evidence": null },
    "build_pass": { "checked": false, "evidence": null },
    "test_pass": { "checked": false, "evidence": null },
    "code_review_pass": { "checked": false, "evidence": null },
    "security_review": { "checked": false, "evidence": null }
  },
  "handoff": {
    "lastIteration": null,
    "currentPhase": "phase_0",
    "completedInThisIteration": "",
    "nextSteps": "",
    "keyDecisions": [],
    "warnings": ""
  }
}
ENDJSON
      ;;
    plan)
      cat > "$target_file" <<ENDJSON
{
  "project": $safe_project,
  "created": "$(timestamp)",
  "status": "in_progress",
  "definitionDoc": null,
  "readmePath": null,
  "documents": [],
  "currentDocument": null,
  "turnCount": 0,
  "lastCompactAt": 0,
  "dod": {
    "user_story": { "checked": false, "evidence": null },
    "data_model": { "checked": false, "evidence": null },
    "api_contract": { "checked": false, "evidence": null },
    "error_scenarios": { "checked": false, "evidence": null },
    "no_definition_conflict": { "checked": false, "evidence": null }
  },
  "handoff": {
    "lastIteration": null,
    "completedInThisIteration": "",
    "nextSteps": "",
    "keyDecisions": [],
    "warnings": "",
    "currentApproach": ""
  }
}
ENDJSON
      ;;
    implement)
      cat > "$target_file" <<ENDJSON
{
  "project": $safe_project,
  "created": "$(timestamp)",
  "status": "in_progress",
  "documents": [],
  "dod": {
    "build_success": { "checked": false, "evidence": null },
    "type_check": { "checked": false, "evidence": null },
    "lint_pass": { "checked": false, "evidence": null },
    "test_pass": { "checked": false, "evidence": null },
    "code_review": { "checked": false, "evidence": null }
  },
  "currentDocument": null,
  "lastCommitSha": null,
  "errorHistory": {
    "currentError": null,
    "attempts": []
  },
  "completedFiles": [],
  "context": {
    "architecture": null,
    "patterns": null
  },
  "documentSummaries": {},
  "lastVerifiedAt": null,
  "handoff": {
    "lastIteration": null,
    "completedInThisIteration": "",
    "nextSteps": "",
    "keyDecisions": [],
    "warnings": "",
    "currentApproach": ""
  }
}
ENDJSON
      ;;
    review)
      cat > "$target_file" <<ENDJSON
{
  "mode": "rounds",
  "targetRounds": 3,
  "goal": null,
  "goalMet": false,
  "scope": $safe_requirement,
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
ENDJSON
      ;;
    polish)
      cat > "$target_file" <<ENDJSON
{
  "project": $safe_project,
  "created": "$(timestamp)",
  "status": "in_progress",
  "definitionDoc": null,
  "readmePath": null,
  "steps": [
    {"name": "프로젝트 분석", "status": "pending", "group": 1, "evidence": {}},
    {"name": "기획 대비 검토", "status": "pending", "group": 1, "evidence": {}},
    {"name": "빌드 검증", "status": "pending", "group": 2, "evidence": {}},
    {"name": "테스트 검증", "status": "pending", "group": 2, "evidence": {}},
    {"name": "보안 검토", "status": "pending", "group": 3, "evidence": {}},
    {"name": "문서화 확인", "status": "pending", "group": 3, "evidence": {}},
    {"name": "릴리즈 체크리스트", "status": "pending", "group": 4, "evidence": {}},
    {"name": "최종 검증", "status": "pending", "group": 4, "evidence": {}}
  ],
  "currentStep": null,
  "turnCount": 0,
  "lastCompactAt": 0,
  "dod": {
    "build_pass": { "checked": false, "evidence": null },
    "test_pass": { "checked": false, "evidence": null },
    "security_review": { "checked": false, "evidence": null },
    "docs_complete": { "checked": false, "evidence": null },
    "final_verification": { "checked": false, "evidence": null }
  },
  "handoff": {
    "lastIteration": null,
    "completedInThisIteration": "",
    "nextSteps": "",
    "keyDecisions": [],
    "warnings": "",
    "currentApproach": ""
  }
}
ENDJSON
      ;;
  esac

  echo "OK: $target_file initialized (template: $template)"
}

# ─── init-ralph: Ralph Loop 파일 생성 ───

cmd_init_ralph() {
  local promise="${1:?Usage: init-ralph <promise> <progress_file> [max_iter]}"
  local progress_file="${2:?Usage: init-ralph <promise> <progress_file> [max_iter]}"
  local max_iter="${3:-0}"

  mkdir -p .claude

  local ralph_file=".claude/ralph-loop.local.md"

  if [[ -f "$ralph_file" ]]; then
    echo "WARNING: $ralph_file already exists. Skipping."
    return 0
  fi

  local now
  now=$(timestamp)

  cat > "$ralph_file" <<ENDRALPH
---
active: true
iteration: 1
max_iterations: $max_iter
completion_promise: "$promise"
started_at: "$now"
---

이전 작업을 이어서 진행합니다.
\`$progress_file\`을 읽고 상태를 확인하세요.
특히 \`handoff\` 필드를 먼저 읽어 이전 iteration의 맥락을 복구하세요.

1. completed 단계는 건너뛰세요
2. in_progress 단계가 있으면 해당 단계부터 재개
3. pending 단계가 있으면 다음 pending 단계 시작
4. 모든 단계가 completed이고 검증을 통과하면 <promise>$promise</promise> 출력

검증 규칙:
- $progress_file의 모든 단계/문서 status가 completed여야 함
- dod 체크리스트가 모두 checked여야 함
- 조건 미충족 시 절대 <promise> 태그를 출력하지 마세요
ENDRALPH

  echo "OK: $ralph_file created (promise: $promise, progress: $progress_file, max_iter: $max_iter)"
}

# ─── status: 현재 상태 요약 출력 ───

cmd_status() {
  require_jq
  require_progress

  echo "=== Progress Status ($PROGRESS_FILE) ==="

  # steps 배열이 있는 경우
  local has_steps
  has_steps=$(jq 'has("steps")' "$PROGRESS_FILE")
  if [[ "$has_steps" == "true" ]]; then
    # 현재 단계 (currentPhase 또는 currentStep 사용)
    local current
    current=$(jq -r '.currentPhase // .currentStep // "unknown"' "$PROGRESS_FILE")
    echo "Current: $current"

    # 완료된 단계
    local completed
    completed=$(jq -r '[.steps[] | select(.status == "completed") | (.label // .name)] | join(", ")' "$PROGRESS_FILE")
    [[ -n "$completed" ]] && echo "Completed: $completed"

    # 진행 중인 단계
    local in_progress
    in_progress=$(jq -r '[.steps[] | select(.status == "in_progress") | (.label // .name)] | join(", ")' "$PROGRESS_FILE")
    [[ -n "$in_progress" ]] && echo "In Progress: $in_progress"

    # 대기 중인 단계
    local pending_count
    pending_count=$(jq '[.steps[] | select(.status == "pending")] | length' "$PROGRESS_FILE")
    echo "Pending: $pending_count steps"
  fi

  # documents 배열이 있는 경우
  local has_docs
  has_docs=$(jq 'has("documents")' "$PROGRESS_FILE")
  if [[ "$has_docs" == "true" ]]; then
    local total_docs done_docs cur_doc
    total_docs=$(jq '.documents | length' "$PROGRESS_FILE")
    done_docs=$(jq '[.documents[] | select(.status == "completed")] | length' "$PROGRESS_FILE")
    cur_doc=$(jq -r '.currentDocument // "none"' "$PROGRESS_FILE")
    echo "Documents: $done_docs / $total_docs completed"
    echo "Current Document: $cur_doc"
  fi

  # DoD 상태
  local has_dod
  has_dod=$(jq 'has("dod")' "$PROGRESS_FILE")
  if [[ "$has_dod" == "true" ]]; then
    local dod_total dod_checked
    dod_total=$(jq '.dod | to_entries | length' "$PROGRESS_FILE")
    dod_checked=$(jq '[.dod | to_entries[].value | select(.checked == true)] | length' "$PROGRESS_FILE")
    echo "DoD: $dod_checked / $dod_total checked"
  fi

  # Handoff 요약
  local next_steps
  next_steps=$(jq -r '.handoff.nextSteps // ""' "$PROGRESS_FILE")
  [[ -n "$next_steps" ]] && echo "Next Steps: $next_steps"

  echo "========================"
}

# ─── update-step: 단계 상태 전이 (동적 검증) ───

cmd_update_step() {
  local step_name="${1:?Usage: update-step <step_name> <status>}"
  local new_status="${2:?Usage: update-step <step_name> <status>}"

  require_jq
  require_progress

  # 유효한 상태 값 확인
  local valid_statuses="pending in_progress completed"
  echo "$valid_statuses" | grep -qw "$new_status" || die "Invalid status: $new_status. Valid: $valid_statuses"

  # progress 파일에서 해당 step이 존재하는지 동적으로 확인
  local step_exists
  step_exists=$(jq --arg name "$step_name" '[.steps[] | select(.name == $name)] | length' "$PROGRESS_FILE")
  [[ "$step_exists" -gt 0 ]] || die "Step not found: $step_name. Available steps: $(jq -r '[.steps[].name] | join(", ")' "$PROGRESS_FILE")"

  # steps 배열에서 해당 step 상태 업데이트 + top-level 갱신
  jq_inplace "$PROGRESS_FILE" --arg name "$step_name" --arg status "$new_status" '
    (.steps[] | select(.name == $name)).status = $status
    | if $status == "in_progress" then
        (if has("currentPhase") then .currentPhase = $name else . end)
        | (if has("currentStep") then .currentStep = $name else . end)
      else . end
    | if has("handoff") and (.handoff | has("currentPhase")) then
        .handoff.currentPhase = (.currentPhase // null)
      else . end
    | .status = (if ([.steps[].status] | all(. == "completed")) then "completed" else "in_progress" end)
  '

  echo "OK: $step_name -> $new_status"
}

# ─── quality-gate: 빌드/타입/린트/테스트 일괄 실행 ───

cmd_quality_gate() {
  require_jq

  echo "=== Quality Gate ==="

  # 프로젝트 유형 자동 감지 + 명령어 결정
  local build_cmd="" type_cmd="" lint_cmd="" test_cmd=""

  if [[ -f "package.json" ]]; then
    local pm="npm"
    [[ -f "pnpm-lock.yaml" ]] && pm="pnpm"
    [[ -f "yarn.lock" ]] && pm="yarn"
    [[ -f "bun.lockb" ]] && pm="bun"

    if jq -e '.scripts.build' package.json >/dev/null 2>&1; then
      build_cmd="$pm run build"
    fi
    if jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
      type_cmd="$pm run typecheck"
    elif jq -e '.scripts["type-check"]' package.json >/dev/null 2>&1; then
      type_cmd="$pm run type-check"
    elif command -v tsc >/dev/null 2>&1 && [[ -f "tsconfig.json" ]]; then
      type_cmd="npx tsc --noEmit"
    fi
    if jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
      lint_cmd="$pm run lint"
    fi
    if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
      test_cmd="$pm run test"
    elif jq -e '.scripts["test:run"]' package.json >/dev/null 2>&1; then
      test_cmd="$pm run test:run"
    fi
  elif [[ -f "pubspec.yaml" ]]; then
    if command -v flutter >/dev/null 2>&1; then
      build_cmd="flutter build apk --debug 2>&1 || flutter analyze"
      type_cmd="dart analyze"
      lint_cmd="dart analyze"
      test_cmd="flutter test"
    else
      build_cmd="dart compile exe lib/main.dart 2>/dev/null || dart analyze"
      type_cmd="dart analyze"
      lint_cmd="dart analyze"
      test_cmd="dart test"
    fi
  elif [[ -f "go.mod" ]]; then
    build_cmd="go build ./..."
    type_cmd="go vet ./..."
    lint_cmd="golangci-lint run 2>/dev/null || go vet ./..."
    test_cmd="go test ./..."
  elif [[ -f "Cargo.toml" ]]; then
    build_cmd="cargo build"
    type_cmd="cargo check"
    lint_cmd="cargo clippy 2>/dev/null || cargo check"
    test_cmd="cargo test"
  elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
    if [[ -f "pyproject.toml" ]] && grep -q "ruff" pyproject.toml 2>/dev/null; then
      lint_cmd="ruff check ."
    elif command -v flake8 >/dev/null 2>&1; then
      lint_cmd="flake8 ."
    fi
    if command -v mypy >/dev/null 2>&1; then
      type_cmd="mypy ."
    fi
    if command -v pytest >/dev/null 2>&1; then
      test_cmd="pytest"
    fi
  fi

  # 결과 수집
  local ts
  ts=$(timestamp)
  local results="{\"timestamp\": \"$ts\""
  local all_pass=true
  local gate_summary=""

  run_gate() {
    local name="$1" cmd="$2"
    if [[ -z "$cmd" ]]; then
      echo "[$name] SKIP (no command detected)"
      results="$results, \"$name\": {\"command\": null, \"exitCode\": null, \"summary\": \"skipped\"}"
      return
    fi

    echo "[$name] Running: $cmd"
    local output exit_code
    output=$(eval "$cmd" 2>&1) && exit_code=0 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      echo "[$name] PASS (exit 0)"
      results="$results, \"$name\": {\"command\": $(jq -Rn --arg c "$cmd" '$c'), \"exitCode\": 0, \"summary\": \"pass\"}"
    else
      echo "[$name] FAIL (exit $exit_code)"
      echo "$output" | tail -5
      all_pass=false
      local summary
      summary=$(echo "$output" | tail -1 | head -c 200)
      results="$results, \"$name\": {\"command\": $(jq -Rn --arg c "$cmd" '$c'), \"exitCode\": $exit_code, \"summary\": $(jq -Rn --arg s "$summary" '$s')}"
      gate_summary="${gate_summary}$name FAIL; "
    fi
  }

  run_gate "build" "$build_cmd"
  run_gate "typeCheck" "$type_cmd"
  run_gate "lint" "$lint_cmd"
  run_gate "test" "$test_cmd"

  results="$results}"

  # verification.json 기록
  echo "$results" | jq '.' > "$VERIFICATION_FILE"
  echo ""
  echo "Results saved to $VERIFICATION_FILE"

  # progress 파일 DoD 업데이트 (존재하는 경우)
  if [[ -n "$PROGRESS_FILE" ]] && [[ -f "$PROGRESS_FILE" ]]; then
    local has_dod
    has_dod=$(jq 'has("dod")' "$PROGRESS_FILE")
    if [[ "$has_dod" == "true" ]]; then
      local build_exit test_exit
      build_exit=$(echo "$results" | jq '.build.exitCode // null')
      test_exit=$(echo "$results" | jq '.test.exitCode // null')

      # build_pass / test_pass 필드가 존재하는 경우만 업데이트
      jq_inplace "$PROGRESS_FILE" --argjson be "$build_exit" --argjson te "$test_exit" --arg ev "quality-gate at $(timestamp)" '
        # null (skipped)은 neutral — 기존 checked 값 유지
        (if .dod | has("build_pass") then
          .dod.build_pass.checked = (if $be == null then .dod.build_pass.checked else ($be == 0) end)
          | .dod.build_pass.evidence = (if $be == null then .dod.build_pass.evidence elif $be == 0 then "build pass " + $ev else "build fail " + $ev end)
        else . end)
        | (if .dod | has("test_pass") then
          .dod.test_pass.checked = (if $te == null then .dod.test_pass.checked else ($te == 0) end)
          | .dod.test_pass.evidence = (if $te == null then .dod.test_pass.evidence elif $te == 0 then "test pass " + $ev else "test fail " + $ev end)
        else . end)
        | (if has("consistencyChecks") then
          .consistencyChecks.code_quality.checked = (($be == 0 or $be == null) and ($te == 0 or $te == null))
          | .consistencyChecks.code_quality.evidence = $ev
        else . end)
      '
    fi
  fi

  if [[ "$all_pass" == "true" ]]; then
    echo "=== ALL GATES PASSED ==="
    return 0
  else
    echo "=== GATE FAILED: ${gate_summary} ==="
    return 1
  fi
}

# ─── record-error: 에러 반복 판별 + errorHistory 업데이트 ───

cmd_record_error() {
  local err_file="" err_type="" err_msg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) err_file="${2:?--file requires a value}"; shift 2 ;;
      --type) err_type="${2:?--type requires a value}"; shift 2 ;;
      --msg)  err_msg="${2:?--msg requires a value}"; shift 2 ;;
      *)      shift ;;
    esac
  done

  [[ -n "$err_file" ]] || die "Usage: record-error --file <f> --type <t> --msg <m>"
  [[ -n "$err_type" ]] || die "Usage: record-error --file <f> --type <t> --msg <m>"
  [[ -n "$err_msg" ]]  || die "Usage: record-error --file <f> --type <t> --msg <m>"

  require_jq
  require_progress

  # 현재 errorHistory 읽기
  local current_err_type current_err_file current_count
  current_err_type=$(jq -r '.errorHistory.currentError.type // ""' "$PROGRESS_FILE")
  current_err_file=$(jq -r '.errorHistory.currentError.file // ""' "$PROGRESS_FILE")
  current_count=$(jq '.errorHistory.currentError.count // 0' "$PROGRESS_FILE")

  # 동일 에러 판별 (type + file 일치)
  if [[ "$current_err_type" == "$err_type" ]] && [[ "$current_err_file" == "$err_file" ]]; then
    current_count=$((current_count + 1))
  else
    current_count=1
  fi

  # errorHistory 업데이트
  jq_inplace "$PROGRESS_FILE" \
    --arg type "$err_type" \
    --arg file "$err_file" \
    --arg msg "$err_msg" \
    --argjson count "$current_count" '
    .errorHistory.currentError = {
      "type": $type,
      "file": $file,
      "message": $msg,
      "count": $count
    }
    | .errorHistory.attempts += [$msg]
  '

  echo "Error recorded: $err_type in $err_file (count: $current_count)"

  # exit code로 결과 전달
  if [[ $current_count -ge 5 ]]; then
    echo "ACTION: 5회 초과 → 사용자 개입 필요"
    exit 3
  elif [[ $current_count -ge 3 ]]; then
    echo "ACTION: 3회 초과 → codex 해결 요청 필요"
    exit 2
  else
    echo "ACTION: 계속 시도 ($current_count/3)"
    exit 0
  fi
}

# ─── check-tools: codex/gemini CLI 존재 확인 ───

cmd_check_tools() {
  local has_codex=false has_gemini=false

  if command -v codex >/dev/null 2>&1; then
    has_codex=true
    echo "[codex] Available: $(command -v codex)"
  else
    echo "[codex] Not found"
  fi

  if command -v gemini >/dev/null 2>&1; then
    has_gemini=true
    echo "[gemini] Available: $(command -v gemini)"
  else
    echo "[gemini] Not found"
  fi

  # JSON 출력
  echo ""
  echo "{\"codex\": $has_codex, \"gemini\": $has_gemini}"
}

# ─── find-debug-code: 디버그 코드 탐색 ───

cmd_find_debug_code() {
  local search_dir="${1:-.}"

  echo "=== Debug Code Scan ==="
  echo "Scanning: $search_dir"

  local found=0

  # 언어별 디버그 패턴
  # JavaScript/TypeScript
  if ls "$search_dir"/**/*.{js,ts,jsx,tsx} 2>/dev/null | head -1 >/dev/null 2>&1 || \
     find "$search_dir" -maxdepth 5 -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" 2>/dev/null | head -1 >/dev/null 2>&1; then
    echo ""
    echo "[JS/TS] console.log/debug/debugger:"
    local js_debug
    js_debug=$(grep -rn --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
      -e 'console\.log' -e 'console\.debug' -e 'console\.warn' -e 'debugger' \
      "$search_dir" 2>/dev/null | grep -v node_modules | grep -v '.test.' | grep -v '.spec.' | head -20 || true)
    if [[ -n "$js_debug" ]]; then
      echo "$js_debug"
      found=$((found + $(echo "$js_debug" | wc -l)))
    else
      echo "  None found"
    fi
  fi

  # Python
  if find "$search_dir" -maxdepth 5 -name "*.py" 2>/dev/null | head -1 >/dev/null 2>&1; then
    echo ""
    echo "[Python] print/pdb/breakpoint:"
    local py_debug
    py_debug=$(grep -rn --include="*.py" \
      -e '^[[:space:]]*print(' -e 'pdb\.set_trace' -e 'breakpoint()' -e 'import pdb' \
      "$search_dir" 2>/dev/null | grep -v __pycache__ | grep -v test_ | head -20 || true)
    if [[ -n "$py_debug" ]]; then
      echo "$py_debug"
      found=$((found + $(echo "$py_debug" | wc -l)))
    else
      echo "  None found"
    fi
  fi

  # Dart
  if find "$search_dir" -maxdepth 5 -name "*.dart" 2>/dev/null | head -1 >/dev/null 2>&1; then
    echo ""
    echo "[Dart] print/debugPrint:"
    local dart_debug
    dart_debug=$(grep -rn --include="*.dart" \
      -e '^[[:space:]]*print(' -e 'debugPrint(' \
      "$search_dir" 2>/dev/null | grep -v _test.dart | head -20 || true)
    if [[ -n "$dart_debug" ]]; then
      echo "$dart_debug"
      found=$((found + $(echo "$dart_debug" | wc -l)))
    else
      echo "  None found"
    fi
  fi

  # Go
  if find "$search_dir" -maxdepth 5 -name "*.go" 2>/dev/null | head -1 >/dev/null 2>&1; then
    echo ""
    echo "[Go] fmt.Print/log.Print:"
    local go_debug
    go_debug=$(grep -rn --include="*.go" \
      -e 'fmt\.Print' -e 'log\.Print' \
      "$search_dir" 2>/dev/null | grep -v _test.go | head -20 || true)
    if [[ -n "$go_debug" ]]; then
      echo "$go_debug"
      found=$((found + $(echo "$go_debug" | wc -l)))
    else
      echo "  None found"
    fi
  fi

  echo ""
  echo "=== Debug code instances found: $found ==="
  [[ "$found" -eq 0 ]] && return 0 || return 1
}

# ─── doc-consistency: 문서 간 일관성 검사 ───

cmd_doc_consistency() {
  local docs_dir="${1:-.}"

  echo "=== Document Consistency Check ==="
  echo "Scanning: $docs_dir"

  local issues=0

  # 1. 데이터 모델 용어 추출 및 교차 검증
  echo ""
  echo "[1] Data Model Terms"
  local models
  models=$(grep -rh -oP '(?<=###?\s)([\w]+(?:\s?(?:Model|Schema|Table|Entity|Type|Interface)))' "$docs_dir"/*.md 2>/dev/null | sort -u || true)
  if [[ -n "$models" ]]; then
    while IFS= read -r model; do
      local count
      count=$(grep -rl "$model" "$docs_dir"/*.md 2>/dev/null | wc -l)
      if [[ "$count" -eq 1 ]]; then
        echo "  WARNING: '$model' only referenced in 1 document"
        ((issues++)) || true
      fi
    done <<< "$models"
  else
    echo "  No model definitions found"
  fi

  # 2. API 엔드포인트 일관성
  echo ""
  echo "[2] API Endpoints"
  local endpoints
  endpoints=$(grep -rhoP '(GET|POST|PUT|PATCH|DELETE)\s+/[\w/{}:-]+' "$docs_dir"/*.md 2>/dev/null | sort -u || true)
  if [[ -n "$endpoints" ]]; then
    local ep_count
    ep_count=$(echo "$endpoints" | wc -l)
    echo "  Found $ep_count unique endpoints"

    local paths
    paths=$(echo "$endpoints" | awk '{print $2}' | sort | uniq -d)
    if [[ -n "$paths" ]]; then
      echo "  Multi-method paths (verify intentional):"
      echo "$paths" | while read -r p; do
        echo "    $p: $(echo "$endpoints" | grep "$p" | awk '{print $1}' | tr '\n' ' ')"
      done
    fi
  else
    echo "  No API endpoints found"
  fi

  # 3. 용어 일관성 (camelCase vs snake_case 혼용)
  echo ""
  echo "[3] Naming Convention"
  local camel snake
  camel=$(grep -rhoP '\b[a-z]+[A-Z][a-zA-Z]*\b' "$docs_dir"/*.md 2>/dev/null | sort -u | head -10 || true)
  snake=$(grep -rhoP '\b[a-z]+_[a-z_]+\b' "$docs_dir"/*.md 2>/dev/null | sort -u | head -10 || true)
  if [[ -n "$camel" ]] && [[ -n "$snake" ]]; then
    echo "  Mixed conventions detected (may be intentional):"
    echo "  camelCase samples: $(echo "$camel" | head -3 | tr '\n' ', ')"
    echo "  snake_case samples: $(echo "$snake" | head -3 | tr '\n' ', ')"
  else
    echo "  Consistent naming or insufficient data"
  fi

  # 4. 상호 참조 검증
  echo ""
  echo "[4] Cross-references"
  local refs
  refs=$(grep -rhoP '(?:참조|see|ref):\s*[\w-]+\.md' "$docs_dir"/*.md 2>/dev/null || true)
  if [[ -n "$refs" ]]; then
    echo "$refs" | while read -r ref; do
      local target
      target=$(echo "$ref" | grep -oP '[\w-]+\.md')
      if [[ ! -f "$docs_dir/$target" ]]; then
        echo "  BROKEN REF: $ref -> $docs_dir/$target not found"
        ((issues++)) || true
      fi
    done
  else
    echo "  No explicit cross-references found"
  fi

  echo ""
  echo "=== Issues found: $issues ==="
  [[ "$issues" -eq 0 ]] && return 0 || return 1
}

# ─── doc-code-check: SPEC/문서 vs 실제 코드 매칭 ───

cmd_doc_code_check() {
  local docs_dir="${1:-docs}"

  echo "=== Doc-Code Consistency Check ==="

  local issues=0

  # 1. 라우트/엔드포인트 매칭
  echo ""
  echo "[1] Route Matching"
  local doc_routes
  doc_routes=$(grep -rhoP '(GET|POST|PUT|PATCH|DELETE)\s+/[\w/{}:-]+' "$docs_dir"/*.md SPEC.md 2>/dev/null | sort -u || true)
  if [[ -n "$doc_routes" ]]; then
    while IFS= read -r route; do
      local method path
      method=$(echo "$route" | awk '{print $1}')
      path=$(echo "$route" | awk '{print $2}' | sed 's/{[^}]*}//g' | sed 's|//|/|g' | sed 's|/$||')
      local found
      found=$(grep -rl "$path" src/ app/ lib/ server/ api/ routes/ 2>/dev/null | head -1 || true)
      if [[ -z "$found" ]]; then
        echo "  MISSING: $method $path (not found in code)"
        ((issues++)) || true
      else
        echo "  OK: $method $path -> $found"
      fi
    done <<< "$doc_routes"
  else
    echo "  No routes in docs to verify"
  fi

  # 2. 모델/스키마 매칭
  echo ""
  echo "[2] Model Matching"
  local doc_models
  doc_models=$(grep -rhoP '(?:model|schema|table|interface|type)\s+(\w+)' "$docs_dir"/*.md SPEC.md 2>/dev/null | awk '{print $2}' | sort -u || true)
  if [[ -n "$doc_models" ]]; then
    while IFS= read -r model; do
      local found
      found=$(grep -rl "class $model\|interface $model\|type $model\|model $model\|table.*$model" src/ app/ lib/ server/ prisma/ 2>/dev/null | head -1 || true)
      if [[ -z "$found" ]]; then
        echo "  MISSING: model $model (not found in code)"
        ((issues++)) || true
      else
        echo "  OK: $model -> $found"
      fi
    done <<< "$doc_models"
  else
    echo "  No models in docs to verify"
  fi

  # 3. 테스트 존재 여부
  echo ""
  echo "[3] Test Coverage"
  local test_dirs
  test_dirs=$(find . -type d \( -name "test" -o -name "tests" -o -name "__tests__" -o -name "spec" \) 2>/dev/null | head -5 || true)
  if [[ -n "$test_dirs" ]]; then
    local test_count
    test_count=$(find $test_dirs -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" -o -name "test_*" \) 2>/dev/null | wc -l)
    echo "  Test files found: $test_count"
  else
    echo "  WARNING: No test directories found"
    ((issues++)) || true
  fi

  echo ""
  echo "=== Issues found: $issues ==="
  [[ "$issues" -eq 0 ]] && return 0 || return 1
}

# ─── 메인 디스패치 ───

main() {
  local subcmd="${1:-help}"
  shift || true

  # --progress-file를 글로벌로 파싱
  parse_progress_file_arg "$@"
  set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"

  case "$subcmd" in
    init)              cmd_init "$@" ;;
    init-ralph)        cmd_init_ralph "$@" ;;
    status)            cmd_status "$@" ;;
    update-step)       cmd_update_step "$@" ;;
    # 하위 호환: update-phase도 update-step으로 처리
    update-phase)      cmd_update_step "$@" ;;
    quality-gate)      cmd_quality_gate "$@" ;;
    record-error)      cmd_record_error "$@" ;;
    check-tools)       cmd_check_tools "$@" ;;
    find-debug-code)   cmd_find_debug_code "$@" ;;
    doc-consistency)   cmd_doc_consistency "$@" ;;
    doc-code-check)    cmd_doc_code_check "$@" ;;
    help|--help|-h)
      echo "Usage: shared-gate.sh <subcommand> [--progress-file <path>] [args]"
      echo ""
      echo "Subcommands:"
      echo "  init [--template <type>] [project] [req]  - Initialize progress JSON"
      echo "    Templates: full-auto, plan, implement, review, polish"
      echo "  init-ralph <promise> <progress_file> [max] - Create Ralph Loop file"
      echo "  status                                     - Show current status"
      echo "  update-step <step> <status>                - Transition step state"
      echo "  quality-gate                               - Run build/type/lint/test"
      echo "  record-error --file <f> --type <t> --msg <m> - Record error + check repeat"
      echo "  check-tools                                - Check codex/gemini availability"
      echo "  find-debug-code [dir]                      - Find debug code"
      echo "  doc-consistency [docs_dir]                 - Check doc consistency"
      echo "  doc-code-check [docs_dir]                  - Check doc-code matching"
      echo ""
      echo "Global options:"
      echo "  --progress-file <path>  Specify progress file (auto-detected if omitted)"
      ;;
    *)
      die "Unknown subcommand: $subcmd. Run with 'help' for usage."
      ;;
  esac
}

main "$@"
