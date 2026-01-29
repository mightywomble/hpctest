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

# Test data collection for JSON block
declare -a TEST_DATA_IDS
declare -a TEST_DATA_NAMES
declare -a TEST_DATA_CATEGORIES
declare -a TEST_DATA_COMMANDS
declare -a TEST_DATA_RESULTS
declare -a TEST_DATA_TYPES
declare -a TEST_DATA_STATUSES
TEST_RUN_ID=$(uuidgen 2>/dev/null || echo "$(date +%s)-$(shuf -i 1000-9999 -n 1)")
TEST_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

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

# Output HTML table row for a test result
# Usage: output_html_result "Test Name" "command" "result output" "pass|fail|partial" "optional notes" "test_id" "category" "result_type"
output_html_result() {
    local test_name="$1"
    local command="$2"
    local result="$3"
    local status="${4:-N/A}"
    local notes="${5:-}"
    local test_id="${6:-}"
    local category="${7:-}"
    local result_type="${8:-text}"
    
    # Escape HTML special characters
    local escaped_name=$(printf '%s' "$test_name" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    local escaped_cmd=$(printf '%s' "$command" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    local escaped_result=$(printf '%s' "$result" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    local escaped_notes=$(printf '%s' "$notes" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    local escaped_test_id=$(printf '%s' "$test_id" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    local escaped_category=$(printf '%s' "$category" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    
    # Determine status class and label
    local status_lower=$(echo "$status" | tr '[:upper:]' '[:lower:]')
    local status_class=""
    local status_label=""
    case "$status_lower" in
        pass)
            status_class="status-pass"; status_label="PASS";;
        partial)
            status_class="status-partial"; status_label="PARTIAL";;
        fail)
            status_class="status-fail"; status_label="FAIL";;
        *)
            status_class=""; status_label="";;
    esac
    
    # Build status cell
    local status_cell=""
    if [[ -n "$status_label" ]]; then
        if [[ -n "$escaped_notes" ]]; then
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span><span class=\"status-notes\">${escaped_notes}</span>"
        else
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span>"
        fi
    fi
    
    # Build data attributes for rows
    local data_attrs=""
    if [[ -n "$escaped_test_id" ]]; then
        data_attrs="data-test-id=\"${escaped_test_id}\" data-test-name=\"${escaped_name}\" data-category=\"${escaped_category}\" data-result=\"${escaped_result}\" data-result-type=\"${result_type}\" data-status=\"${status_lower}\""
        # Collect data for JSON block
        TEST_DATA_IDS+=("$test_id")
        TEST_DATA_NAMES+=("$test_name")
        TEST_DATA_CATEGORIES+=("$category")
        TEST_DATA_COMMANDS+=("$command")
        TEST_DATA_RESULTS+=("$result")
        TEST_DATA_TYPES+=("$result_type")
        TEST_DATA_STATUSES+=("$status_lower")
    fi
    
    # Output HTML table row directly to report file
    echo "<tr ${data_attrs}><td>${escaped_name}</td><td>${escaped_cmd}</td><td><pre>${escaped_result}</pre></td><td>${status_cell}</td></tr>" >> "${OUTPUT_FILE}"
}

# ==============================================================================
# Utility functions for test scripts
# ==============================================================================

# Log test progress to console
log_test_progress() {
    local test_name="$1"
    echo -e "  ${C_CYAN}•${C_RESET} $test_name..."
}

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
export -f check_command_exists safe_run output_html_result should_skip_test run_single_test
export -f log_test_progress nic_info_per_ipv4
export TEST_DATA_IDS TEST_DATA_NAMES TEST_DATA_CATEGORIES TEST_DATA_COMMANDS TEST_DATA_RESULTS TEST_DATA_TYPES TEST_DATA_STATUSES
export TEST_RUN_ID TEST_DATE
