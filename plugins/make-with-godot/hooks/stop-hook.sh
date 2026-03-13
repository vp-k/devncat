#!/usr/bin/env bash
# Make with Godot — Ralph Loop 완주 보장 stop hook
# auto-complete-loop의 stop-hook.sh 패턴 기반

set -euo pipefail

# jq 의존성
if ! command -v jq &>/dev/null; then
  echo '{"decision": "allow"}'
  exit 0
fi

RALPH_STATE_FILE=".claude/ralph-loop.local.md"

# 상태 파일 없으면 정상 종료
if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  exit 0
fi

# 프론트매터 파싱
FRONTMATTER=$(awk '/^---$/{i++; if(i==2) exit; next} i==1{print}' "$RALPH_STATE_FILE")

ITERATION=$(echo "$FRONTMATTER" | grep "^iteration:" | sed 's/iteration: *//' | tr -d '\r' || true)
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep "^max_iterations:" | sed 's/max_iterations: *//' | tr -d '\r' || true)
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep "^completion_promise:" | sed 's/completion_promise: *//' | sed 's/^"//' | sed 's/"$//' | tr -d '\r' || true)
PROGRESS_FILE_FROM_FRONTMATTER=$(echo "$FRONTMATTER" | grep "^progress_file:" | sed 's/progress_file: *//' | sed 's/^"//' | sed 's/"$//' | tr -d '\r' || true)

# 데이터 검증
if ! [[ "$ITERATION" =~ ^[0-9]+$ ]] || ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Make with Godot: WARNING - Ralph loop state file is corrupted"
  exit 0
fi

# max_iterations 도달
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Ralph loop: Max iterations ($MAX_ITERATIONS) reached."
  rm -f "$RALPH_STATE_FILE" ".claude/ralph-loop-failure-history.local"
  exit 0
fi

# 트랜스크립트에서 마지막 assistant 메시지 추출
TRANSCRIPT_PATH=""
if [[ -n "${CLAUDE_HOOK_INPUT:-}" ]]; then
  TRANSCRIPT_PATH=$(echo "$CLAUDE_HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
fi

LAST_OUTPUT=""
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  LAST_ASSISTANT_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1 || true)
  if [[ -n "$LAST_ASSISTANT_LINE" ]]; then
    LAST_OUTPUT=$(echo "$LAST_ASSISTANT_LINE" | jq -r '
      if .message.content then
        [.message.content[] | select(.type == "text") | .text] | join("\n")
      else
        ""
      end
    ' 2>/dev/null || true)
  fi
fi

# 완료 Promise 검사
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=""
  if [[ -n "$LAST_OUTPUT" ]] && echo "$LAST_OUTPUT" | grep -q '<promise>' 2>/dev/null; then
    PROMISE_TEXT=$(echo "$LAST_OUTPUT" | sed -n 's/.*<promise>\(.*\)<\/promise>.*/\1/p' | head -1 | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  fi

  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    # Promise 감지 → 추가 검증
    VERIFICATION_PASSED="true"
    FAILURE_REASONS=""

    # 1. progress 파일 검증 — 모든 Phase completed
    if [[ -f "$PROGRESS_FILE_FROM_FRONTMATTER" ]]; then
      ALL_PHASES_DONE=$(jq '
        [.phases | to_entries[] | .value.status] | all(. == "completed")
      ' "$PROGRESS_FILE_FROM_FRONTMATTER" 2>/dev/null || echo "false")

      if [[ "$ALL_PHASES_DONE" != "true" ]]; then
        VERIFICATION_PASSED="false"
        FAILURE_REASONS="${FAILURE_REASONS}Not all phases completed. "
      fi

      # DoD 체크리스트 검증
      ALL_DOD_CHECKED=$(jq '
        [.dod | to_entries[] | .value.checked] | all(. == true)
      ' "$PROGRESS_FILE_FROM_FRONTMATTER" 2>/dev/null || echo "false")

      if [[ "$ALL_DOD_CHECKED" != "true" ]]; then
        VERIFICATION_PASSED="false"
        FAILURE_REASONS="${FAILURE_REASONS}DoD checklist incomplete. "
      fi
    else
      VERIFICATION_PASSED="false"
      FAILURE_REASONS="${FAILURE_REASONS}Progress file not found: $PROGRESS_FILE_FROM_FRONTMATTER. "
    fi

    # 검증 결과에 따른 분기
    if [[ "$VERIFICATION_PASSED" = "true" ]]; then
      echo "Make with Godot: Promise verified. All conditions met. Game complete!"
      rm -f "$RALPH_STATE_FILE" ".claude/ralph-loop-failure-history.local"
      exit 0
    else
      echo "Make with Godot: Promise detected but verification failed: ${FAILURE_REASONS}"

      # 무한 루프 감지
      FAILURE_HISTORY_FILE=".claude/ralph-loop-failure-history.local"
      if command -v md5sum >/dev/null 2>&1; then
        CURRENT_FAILURE_HASH=$(echo "$FAILURE_REASONS" | md5sum | cut -d' ' -f1)
      elif command -v md5 >/dev/null 2>&1; then
        CURRENT_FAILURE_HASH=$(echo "$FAILURE_REASONS" | md5 -q)
      else
        CURRENT_FAILURE_HASH=$(echo "$FAILURE_REASONS" | shasum -a 256 | cut -d' ' -f1)
      fi
      REPEAT_COUNT=0
      if [[ -f "$FAILURE_HISTORY_FILE" ]]; then
        REPEAT_COUNT=$(grep -c "^${CURRENT_FAILURE_HASH}$" "$FAILURE_HISTORY_FILE" 2>/dev/null || echo "0")
      fi
      echo "$CURRENT_FAILURE_HASH" >> "$FAILURE_HISTORY_FILE"
      REPEAT_COUNT=$((REPEAT_COUNT + 1))

      if [[ $REPEAT_COUNT -ge 3 ]]; then
        echo "Make with Godot: Breaking loop — unresolvable verification failures."
        rm -f "$RALPH_STATE_FILE" "$FAILURE_HISTORY_FILE"
        exit 0
      fi
    fi
  fi
fi

# 루프 계속
NEXT_ITERATION=$((ITERATION + 1))
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

# iteration 업데이트
TEMP_FILE=$(mktemp)
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPH_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$RALPH_STATE_FILE"

SYSTEM_MSG="Make with Godot iteration $NEXT_ITERATION | $(date '+%H:%M:%S')"
if [[ -n "${FAILURE_REASONS:-}" ]]; then
  SYSTEM_MSG="${SYSTEM_MSG} | Verification failed: ${FAILURE_REASONS}"
fi

jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'
