#!/bin/bash

# ==============================================================================
# Shared Configuration & Utility Functions
#
# This file is sourced by all test scripts and the main hpctests.sh orchestrator.
# It provides:
#   - Global configuration variables
#   - Logging functions with color codes
#   - Helper functions for common operations
#   - Shared state (OUTPUT_FILE, HOSTNAME_FQDN, PRIMARY_IP)
#
# ==============================================================================

# --- Globals and Configuration ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
readonly FILENAME_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="${OUTPUT_FILE:-system_test_report_${FILENAME_TIMESTAMP}.html}"
NOCHECK_MODE=${NOCHECK_MODE:-false}
HEADLESS_MODE=${HEADLESS_MODE:-false}
NOINSTALL_MODE=${NOINSTALL_MODE:-false}
NOBURN_MODE=${NOBURN_MODE:-false}

# Host identification (best-effort)
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)
PRIMARY_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if ($i=="src"){print $(i+1); exit}}')
if [[ -z "$PRIMARY_IP" ]]; then
    PRIMARY_IP=$(ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}' | head -n1 | cut -d'/' -f1)
fi

# Thresholds and Speedtest server pins (configurable via env)
MIN_LINK_SPEED_MBPS=${MIN_LINK_SPEED_MBPS:-0}
MIN_DOWNLOAD_MBPS=${MIN_DOWNLOAD_MBPS:-0}
MIN_UPLOAD_MBPS=${MIN_UPLOAD_MBPS:-0}
SPEEDTEST_SERVER_NEARBY=${SPEEDTEST_SERVER_NEARBY:-}
SPEEDTEST_SERVER_EU=${SPEEDTEST_SERVER_EU:-}

# --- Color Codes for Verbose Console Output ---
readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'

# ==============================================================================
# Logging Functions
# ==============================================================================

log() {
    echo -e "${C_CYAN}[$(date +"%T")]${C_RESET} $1"
}

log_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

log_warn() {
    echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"
}

# ==============================================================================
# Helper Functions
# ==============================================================================

# Check if a command exists on the system
check_command_exists() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Safely run a command and capture output + exit code
# Usage: result=$(safe_run "command here"); exit_code=$?
safe_run() {
    local cmd="$1"
    eval "$cmd" 2>&1
}

# Output JSON for a single test result
# Usage: output_test_result "Test Name" "command" "result output" "pass|fail|partial" "optional notes"
output_test_result() {
    local test_name="$1"
    local command="$2"
    local result="$3"
    local status="${4:-N/A}"
    local notes="${5:-}"
    
    # Escape special characters for JSON - must handle newlines, tabs, backslashes, and quotes
    local escaped_name=$(printf '%s' "$test_name" | sed 's/\\/\\\\/g; s/	/\\t/g; s/"/\\"/g; s/$//' | awk '{printf "%s", $0}' RS=$'\n' ORS='\\n')
    local escaped_cmd=$(printf '%s' "$command" | sed 's/\\/\\\\/g; s/	/\\t/g; s/"/\\"/g; s/$//' | awk '{printf "%s", $0}' RS=$'\n' ORS='\\n')
    local escaped_result=$(printf '%s' "$result" | sed 's/\\/\\\\/g; s/	/\\t/g; s/"/\\"/g; s/$//' | awk '{printf "%s", $0}' RS=$'\n' ORS='\\n')
    local escaped_notes=$(printf '%s' "$notes" | sed 's/\\/\\\\/g; s/	/\\t/g; s/"/\\"/g; s/$//' | awk '{printf "%s", $0}' RS=$'\n' ORS='\\n')
    
    cat <<EOF
  {
    "test_name": "$escaped_name",
    "command": "$escaped_cmd",
    "result": "$escaped_result",
    "status": "$status",
    "notes": "$escaped_notes"
  }
EOF
}

# Output JSON for a single test result with HTML content in result field
# Usage: output_test_result_html "Test Name" "command" "<html content>" "pass|fail|partial" "optional notes"
output_test_result_html() {
    local test_name="$1"
    local command="$2"
    local result_html="$3"
    local status="${4:-N/A}"
    local notes="${5:-}"
    
    # Escape special characters for JSON (for test name, command, notes only; HTML goes as-is)
    local escaped_name=$(printf '%s\n' "$test_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    local escaped_cmd=$(printf '%s\n' "$command" | sed 's/\\/\\\\/g; s/"/\\"/g')
    local escaped_notes=$(printf '%s\n' "$notes" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    cat <<EOF
  {
    "test_name": "$escaped_name",
    "command": "$escaped_cmd",
    "result_html": true,
    "result": $result_html,
    "status": "$status",
    "notes": "$escaped_notes"
  }
EOF
}

# Start JSON output array for a test script
start_json_output() {
    echo "["
}

# Finish JSON output array for a test script
finish_json_output() {
    echo "]"
}

# ==============================================================================
# Utility functions for test scripts
# ==============================================================================

# Check if script should be skipped based on flags
# Usage: should_skip_test "--noburn" "--noinstall"
should_skip_test() {
    local skip_flags=("$@")
    for flag in "${skip_flags[@]}"; do
        if [[ "$flag" == "--noburn" ]] && $NOBURN_MODE; then
            return 0
        fi
        if [[ "$flag" == "--noinstall" ]] && $NOINSTALL_MODE; then
            return 0
        fi
        if [[ "$flag" == "--nocheck" ]] && $NOCHECK_MODE; then
            return 0
        fi
        if [[ "$flag" == "--headless" ]] && ! $HEADLESS_MODE; then
            return 1
        fi
    done
    return 1
}

# Run a test and collect results
# This is a helper for the common pattern of running a command, checking exit code, and recording output
run_single_test() {
    local test_name="$1"
    local cmd="$2"
    
    local result
    local exit_code
    result=$(eval "$cmd" 2>&1)
    exit_code=$?
    
    local status="pass"
    local note=""
    
    if [[ $exit_code -ne 0 ]]; then
        status="fail"
        note="Exit code ${exit_code}"
    elif [[ -z "$result" ]]; then
        status="partial"
        note="No output"
        result="No output"
    fi
    
    output_test_result "$test_name" "$cmd" "$result" "$status" "$note"
}

# Helper function: NIC info per IPv4 (driver, vendor, product)
nic_info_per_ipv4() {
  ip -o -4 addr show primary scope global | while read -r idx iface fam cidr rest; do
    ip_addr="${cidr}"
    drv=$(ethtool -i "$iface" 2>/dev/null | awk -F': ' '/driver/ {gsub(/^ +| +$/, "", $2); print $2}')
    ven=$(lshw -C network 2>/dev/null | awk -v IF="$iface" '$1=="logical"&&$2=="name:"&&$3==IF{f=1} f&&$1=="vendor:"{sub(/^vendor: /,""); print; exit}')
    prod=$(lshw -C network 2>/dev/null | awk -v IF="$iface" '$1=="logical"&&$2=="name:"&&$3==IF{f=1} f&&$1=="product:"{sub(/^product: /,""); print; exit}')
    echo "$iface ${ip_addr} driver=${drv:-unknown} vendor=${ven:-unknown} product=${prod:-unknown}"
  done
}

export -f log log_error log_success log_warn
export -f check_command_exists safe_run output_test_result output_test_result_html
export -f start_json_output finish_json_output should_skip_test run_single_test
export -f nic_info_per_ipv4
