#!/usr/bin/env bash
# plugin-security-scan.sh - marketplace 플러그인 보안 스캔
#
# 사용법: bash scripts/plugin-security-scan.sh [plugin_dir]
#   plugin_dir 미지정 시 plugins/ 하위 모든 플러그인 스캔
#
# 검사 항목:
#   1. 시크릿 패턴 탐지 (API 키, 토큰, 비밀번호)
#   2. 훅 인젝션 분석 (위험한 명령어, 네트워크 호출)
#   3. 위험 명령어 탐지 (rm -rf, curl | bash, eval)
#   4. 퍼미션 감사 (실행 권한 파일 확인)

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SCAN_INPUT="${1:-plugins}"

# 상대 경로를 절대 경로로 변환
if [[ "$SCAN_INPUT" = /* ]]; then
  SCAN_ROOT="$SCAN_INPUT"
else
  SCAN_ROOT="${REPO_ROOT}/${SCAN_INPUT}"
fi

TOTAL_ISSUES=0
CRITICAL_ISSUES=0

log_critical() {
  echo -e "${RED}[CRITICAL]${NC} $1"
  ((TOTAL_ISSUES++)) || true
  ((CRITICAL_ISSUES++)) || true
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
  ((TOTAL_ISSUES++)) || true
}

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
}

echo "=== Plugin Security Scan ==="
echo "Scan target: ${SCAN_ROOT}"
echo ""

# --- 1. 시크릿 패턴 탐지 ---
echo "## 1. Secret Pattern Detection"

SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'                          # AWS Access Key
  'sk-[a-zA-Z0-9]{20,}'                       # OpenAI/Stripe Secret Key
  'ghp_[a-zA-Z0-9]{36}'                       # GitHub Personal Token
  'gho_[a-zA-Z0-9]{36}'                       # GitHub OAuth Token
  'glpat-[a-zA-Z0-9\-]{20,}'                  # GitLab Token
  'xoxb-[0-9]+-[a-zA-Z0-9]+'                  # Slack Bot Token
  'xoxp-[0-9]+-[a-zA-Z0-9]+'                  # Slack User Token
  'SG\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'        # SendGrid API Key
  'AIza[0-9A-Za-z_-]{35}'                     # Google API Key
  'ya29\.[0-9A-Za-z_-]+'                      # Google OAuth Token
  'password\s*[:=]\s*["\x27][^"\x27]{8,}'     # Hardcoded Password
  'secret\s*[:=]\s*["\x27][^"\x27]{8,}'       # Hardcoded Secret
  'api[_-]?key\s*[:=]\s*["\x27][^"\x27]{8,}'  # Hardcoded API Key
  'Bearer\s+[a-zA-Z0-9._\-]+'                 # Bearer Token
)

SECRET_FOUND=0
for pattern in "${SECRET_PATTERNS[@]}"; do
  MATCHES=$(grep -rn \
    --include="*.md" --include="*.sh" --include="*.json" --include="*.js" --include="*.ts" --include="*.py" \
    --include="*.env" --include="*.env.*" --include="*.yml" --include="*.yaml" --include="*.toml" \
    --include="*.pem" --include="*.key" --include="*.cjs" --include="*.mjs" --include="*.cfg" --include="*.ini" \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor --exclude-dir=dist \
    -E "$pattern" "$SCAN_ROOT" 2>/dev/null | grep -v 'example\|sample\|placeholder\|YOUR_\|<.*>\|\.example' || true)
  if [ -n "$MATCHES" ]; then
    log_critical "Secret pattern detected: ${pattern}"
    echo "$MATCHES" | head -5
    echo ""
    SECRET_FOUND=1
  fi
done

if [ "$SECRET_FOUND" -eq 0 ]; then
  log_pass "No secret patterns detected"
fi
echo ""

# --- 2. 훅 인젝션 분석 ---
echo "## 2. Hook Injection Analysis"

# hooks.json에서 command 필드 추출 및 분석
HOOK_FILES=$(find "$SCAN_ROOT" -name "hooks.json" -type f 2>/dev/null || true)
for hf in $HOOK_FILES; do
  echo "Scanning: $hf"

  # hooks.json의 command 값을 직접 파싱하여 검사
  HOOK_DIR=$(dirname "$hf")
  jq -r '.. | .command? // empty' "$hf" 2>/dev/null | tr -d '\r' | while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue

    # 인라인 위험 패턴 검사 (command 값 자체에서)
    if echo "$cmd" | grep -qE 'curl.*\|\s*bash|wget.*\|\s*bash'; then
      log_critical "Pipe-to-bash in hook command: $cmd ($hf)"
    fi
    if echo "$cmd" | grep -qE '\beval\b'; then
      log_critical "eval in hook command: $cmd ($hf)"
    fi

    # 참조된 스크립트 파일 추적 (확장자 무관)
    # ${CLAUDE_PLUGIN_ROOT} 등 변수 치환 후 경로 추출
    SCRIPT_PATH=$(echo "$cmd" | grep -oE '[^ ]*\.(sh|py|js|cjs|mjs|ts|rb|pl)[" ]*' | head -1 | tr -d '"' || true)
    if [ -n "$SCRIPT_PATH" ]; then
      # 변수 치환 시도 (CLAUDE_PLUGIN_ROOT → HOOK_DIR의 상위)
      RESOLVED=$(echo "$SCRIPT_PATH" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$(dirname "$HOOK_DIR")|g")
      if [ -f "$RESOLVED" ]; then
        # 참조된 스크립트 파일 내용 검사
        if grep -nE 'curl\s|wget\s' "$RESOLVED" 2>/dev/null | grep -vE 'localhost|127\.0\.0\.1|example\.com' | head -3; then
          log_warning "External network call in hook script: $RESOLVED"
        fi
        if grep -n '\beval\b' "$RESOLVED" 2>/dev/null | head -3; then
          log_warning "eval usage in hook script: $RESOLVED"
        fi
        if grep -nE '\$\{[A-Z_]+\}.*\|.*sh|\$\([^)]*\$\{' "$RESOLVED" 2>/dev/null | head -3; then
          log_warning "Potential command injection via env var: $RESOLVED"
        fi
      fi
    fi
  done
done

if [ -z "$HOOK_FILES" ]; then
  log_pass "No hook files found"
fi
echo ""

# --- 3. 위험 명령어 탐지 ---
echo "## 3. Dangerous Command Detection"

# 스킬/커맨드 파일에서 위험 명령어 탐지
DANGER_PATTERNS=(
  'rm\s+-rf\s+/'              # Root deletion
  'curl.*\|\s*bash'           # Pipe curl to bash
  'wget.*\|\s*bash'           # Pipe wget to bash
  'eval\s+\$'                 # eval with variable
  'chmod\s+777'               # World-writable
  'dd\s+if='                  # Disk operations
  ':(){.*};:'                  # Fork bomb
  'mkfs\.'                    # Filesystem format
  '>\s*/dev/sd'               # Direct disk write
)

DANGER_FOUND=0
for pattern in "${DANGER_PATTERNS[@]}"; do
  MATCHES=$(grep -rn --include="*.md" --include="*.sh" --include="*.json" -E "$pattern" "$SCAN_ROOT" 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    log_critical "Dangerous command pattern: ${pattern}"
    echo "$MATCHES" | head -5
    echo ""
    DANGER_FOUND=1
  fi
done

if [ "$DANGER_FOUND" -eq 0 ]; then
  log_pass "No dangerous commands detected"
fi
echo ""

# --- 4. 퍼미션 감사 ---
echo "## 4. Permission Audit"

# 실행 권한이 있는 파일 목록 (스크립트 외 실행 권한은 의심)
EXEC_FILES=$(find "$SCAN_ROOT" -type f -executable ! -name "*.sh" ! -name "*.cjs" ! -name "*.mjs" 2>/dev/null || true)
if [ -n "$EXEC_FILES" ]; then
  log_warning "Non-script files with execute permission:"
  echo "$EXEC_FILES"
else
  log_pass "All executable files are scripts"
fi
echo ""

# --- 5. plugin.json 검증 ---
echo "## 5. Plugin Manifest Validation"

PLUGIN_JSONS=$(find "$SCAN_ROOT" -path "*/.claude-plugin/plugin.json" -type f 2>/dev/null || true)
for pj in $PLUGIN_JSONS; do
  PLUGIN_DIR=$(dirname "$(dirname "$pj")")
  PLUGIN_NAME=$(basename "$PLUGIN_DIR")

  # JSON 유효성
  if ! jq empty "$pj" 2>/dev/null; then
    log_critical "Invalid JSON: $pj"
    continue
  fi

  # 참조된 스킬/커맨드 파일 존재 확인
  jq -r '.skills[]? // empty' "$pj" 2>/dev/null | tr -d '\r' | while IFS= read -r sp; do
    [ -z "$sp" ] && continue
    # ./path → path 정규화
    CLEAN_PATH="${sp#./}"
    FULL_PATH="${PLUGIN_DIR}/${CLEAN_PATH}"
    if [ ! -f "$FULL_PATH" ] && [ ! -d "$FULL_PATH" ]; then
      log_warning "Missing skill reference in ${PLUGIN_NAME}: ${sp}"
    fi
  done

  log_pass "Plugin manifest valid: ${PLUGIN_NAME}"
done
echo ""

# --- 결과 요약 ---
echo "=== Scan Summary ==="
echo "Total issues: ${TOTAL_ISSUES}"
echo "Critical: ${CRITICAL_ISSUES}"

if [ "$CRITICAL_ISSUES" -gt 0 ]; then
  echo -e "${RED}FAIL${NC} — Critical security issues found. Fix before publishing."
  exit 2
elif [ "$TOTAL_ISSUES" -gt 0 ]; then
  echo -e "${YELLOW}WARN${NC} — Warnings found. Review before publishing."
  exit 1
else
  echo -e "${GREEN}PASS${NC} — No security issues detected."
  exit 0
fi
