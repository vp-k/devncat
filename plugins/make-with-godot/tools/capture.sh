#!/usr/bin/env bash
# capture.sh — Xvfb + Godot 스크린샷/비디오 캡처
# 사용법:
#   capture.sh screenshot [--scene <path>] [--wait <sec>] [--output <file>]
#   capture.sh video [--duration <sec>] [--output <file>]

set -euo pipefail

PROGRESS_FILE=".claude-godot-progress.json"

die() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"
}

detect_project_dir() {
  if [[ -f "project.godot" ]]; then
    echo "."
  elif [[ -f "$PROGRESS_FILE" ]]; then
    local game_name
    game_name=$(jq -r '.gameName // empty' "$PROGRESS_FILE" 2>/dev/null)
    if [[ -n "$game_name" ]] && [[ -f "$game_name/project.godot" ]]; then
      echo "$game_name"
    else
      die "Cannot detect project directory"
    fi
  else
    die "Cannot detect project directory"
  fi
}

# Xvfb 시작 (이미 실행 중이면 스킵)
start_xvfb() {
  local display="${1:-:99}"
  if ! pgrep -f "Xvfb $display" > /dev/null 2>&1; then
    echo "Starting Xvfb on $display..."
    Xvfb "$display" -screen 0 1280x720x24 +extension GLX +render -noreset &
    sleep 1
  fi
  export DISPLAY="$display"
}

# ─── screenshot ───

cmd_screenshot() {
  local scene=""
  local wait_time=3
  local output="screenshot_$(date +%s).png"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scene) scene="$2"; shift 2 ;;
      --wait) wait_time="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ "$wait_time" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "--wait must be a number, got: $wait_time"

  require_cmd godot
  require_cmd Xvfb

  local project_dir
  project_dir=$(detect_project_dir)

  start_xvfb ":99"

  echo "Capturing screenshot (wait: ${wait_time}s)..."

  # Godot를 일반 모드로 실행 (렌더링 활성화)
  local -a godot_args=("--path" "$project_dir")
  if [[ -n "$scene" ]]; then
    godot_args+=("--scene" "$scene")
  fi

  # 백그라운드에서 실행
  DISPLAY=:99 godot "${godot_args[@]}" &
  local godot_pid=$!

  # 대기 후 스크린샷
  sleep "$wait_time"

  # xdotool 또는 import (ImageMagick)으로 캡처
  if command -v import >/dev/null 2>&1; then
    DISPLAY=:99 import -window root "$output"
  elif command -v xdotool >/dev/null 2>&1 && command -v scrot >/dev/null 2>&1; then
    DISPLAY=:99 scrot "$output"
  else
    # 대안: Godot의 get_viewport().get_texture() 스크립트 방식
    echo "WARNING: No screenshot tool found. Install imagemagick: sudo apt-get install imagemagick"
    kill "$godot_pid" 2>/dev/null || true
    return 1
  fi

  kill "$godot_pid" 2>/dev/null || true
  wait "$godot_pid" 2>/dev/null || true

  if [[ -f "$output" ]]; then
    echo "OK: Screenshot → $output"
  else
    echo "FAIL: Screenshot not captured"
    return 1
  fi
}

# ─── video ───

cmd_video() {
  local duration=30
  local output="gameplay"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --duration) duration="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ "$duration" =~ ^[0-9]+$ ]] || die "--duration must be an integer, got: $duration"

  require_cmd godot
  require_cmd Xvfb

  local project_dir
  project_dir=$(detect_project_dir)

  start_xvfb ":99"

  echo "Recording gameplay video (${duration}s)..."

  # Godot --write-movie는 AVI로 출력
  local avi_file="${output}.avi"

  DISPLAY=:99 timeout "$((duration + 10))" \
    godot --path "$project_dir" --write-movie "$avi_file" \
    2>/dev/null &
  local godot_pid=$!

  sleep "$duration"
  kill "$godot_pid" 2>/dev/null || true
  wait "$godot_pid" 2>/dev/null || true

  if [[ ! -f "$avi_file" ]]; then
    echo "FAIL: Video not recorded"
    return 1
  fi

  # AVI → MP4 변환
  if command -v ffmpeg >/dev/null 2>&1; then
    local mp4_file="${output}.mp4"
    ffmpeg -y -i "$avi_file" -c:v libx264 -crf 23 -c:a aac "$mp4_file" 2>/dev/null
    rm -f "$avi_file"
    echo "OK: Video → $mp4_file"
  else
    echo "OK: Video → $avi_file (install ffmpeg for MP4 conversion)"
  fi
}

# ─── 메인 ───

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    screenshot) cmd_screenshot "$@" ;;
    video)      cmd_video "$@" ;;
    help|--help|-h)
      echo "Usage: capture.sh <command> [options]"
      echo ""
      echo "Commands:"
      echo "  screenshot [--scene <path>] [--wait <sec>] [--output <file>]"
      echo "  video [--duration <sec>] [--output <file>]"
      ;;
    *) die "Unknown command: $cmd" ;;
  esac
}

main "$@"
