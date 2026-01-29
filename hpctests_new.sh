#!/bin/bash

# ==============================================================================
#
# System Hardware & Performance Test Script (Refactored)
#
# Description:
#   Main orchestrator that loads a test manifest and executes modular test
#   scripts in tests.d/, capturing JSON output and rendering to HTML.
#
# Usage:
#   - Standard run: 'sudo ./hpctests.sh'
#   - Headless (auto-yes): 'sudo ./hpctests.sh --headless'
#   - Skip benchmarks: 'sudo ./hpctests.sh --noburn'
#   - No install mode: 'sudo ./hpctests.sh --noinstall'
#   - Help: 'sudo ./hpctests.sh --help'
#
# ==============================================================================

set -o pipefail

# Source shared config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Export flag variables so test scripts can access them
export NOCHECK_MODE HEADLESS_MODE NOINSTALL_MODE NOBURN_MODE
export HOSTNAME_FQDN PRIMARY_IP OUTPUT_FILE
export MIN_LINK_SPEED_MBPS MIN_DOWNLOAD_MBPS MIN_UPLOAD_MBPS
export SPEEDTEST_SERVER_NEARBY SPEEDTEST_SERVER_EU

# Paths
readonly MANIFEST_FILE="$SCRIPT_DIR/tests.manifest.json"
readonly TESTS_DIR="$SCRIPT_DIR/tests.d"

# ==============================================================================
# Helper Functions
# ==============================================================================

print_usage() {
    cat <<USAGE
Usage: sudo ./hpctests.sh [options]

Options:
  --headless   Run all tests non-interactively, defaulting "yes" to prompts (installs allowed).
  --noburn     Skip Docker-based benchmarks (HPL and GPU-burn). Tests still run; report generated.
  --noinstall  Do not install missing software. Tests still run; report generated.
  --nocheck    Legacy automated mode: skip dependency checks and confirmations.
  --help, -h   Show this help and exit.

Notes:
- All flags can be combined as needed.
- Report is always generated and saved to: ${OUTPUT_FILE}
USAGE
}

# Parse JSON manifest using jq (fallback to simple parsing if jq unavailable)
parse_manifest() {
    if command -v jq &>/dev/null; then
        cat "$MANIFEST_FILE"
    else
        # Simple fallback parsing (very basic)
        cat "$MANIFEST_FILE"
    fi
}

# Execute a single test script
# Scripts now output HTML directly to OUTPUT_FILE
execute_test_script() {
    local script_path="$1"
    local test_id="$2"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Test script not found: $script_path"
        return 1
    fi
    
    # Run the script - it outputs directly to OUTPUT_FILE
    bash "$script_path" 2>&1
    return $?
}

# No JSON parsing needed - scripts output HTML directly

# HTML generation functions
add_html_category_header() {
    local category="$1"
    cat >> "${OUTPUT_FILE}" << EOF
<details open>
    <summary>${category}</summary>
    <table>
        <thead>
            <tr>
                <th>Test</th>
                <th>Command</th>
                <th>Result</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
EOF
}

close_html_category_section() {
    cat >> "${OUTPUT_FILE}" << EOF
        </tbody>
    </table>
</details>
EOF
}

# HTML row output is now handled by output_html_result() in config.sh

# Initialize HTML report with header and styles
initialize_html_report() {
    log "Initializing HTML report file: ${OUTPUT_FILE}"
    cat > "${OUTPUT_FILE}" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="test-run-id" content="${TEST_RUN_ID}" />
    <meta name="test-date" content="${TEST_DATE}" />
    <meta name="hostname" content="${HOSTNAME_FQDN}" />
    <meta name="ip-address" content="${PRIMARY_IP}" />
    <title>System Test Report</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
        :root {
            --bg-color: #1a1b26;
            --card-color: #24283b;
            --text-color: #c0caf5;
            --header-color: #ffffff;
            --accent-color: #00bfff;
            --border-color: #414868;
            --table-header-bg: #2e3452;
            --green: #34d399;
            --yellow: #facc15;
            --red: #f87171;
        }
        body { font-family: 'Inter', sans-serif; background-color: var(--bg-color); color: var(--text-color); margin: 0; padding: 2rem; font-size: 14px; }
        .container { max-width: 1200px; margin: 0 auto; background-color: var(--card-color); border-radius: 12px; padding: 2rem; border: 1px solid var(--border-color); box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
        h1 { color: var(--header-color); text-align: center; border-bottom: 2px solid var(--accent-color); padding-bottom: 1rem; margin-bottom: 0.5rem; font-weight: 700; }
        .report-meta { text-align: center; margin-bottom: 1.5rem; font-size: 0.95rem; color: #7a82ac; }
        .report-host { text-align: center; margin-bottom: 2rem; font-size: 0.95rem; color: #a9b1d6; }
        details { background: var(--bg-color); border-radius: 8px; margin-bottom: 1rem; border: 1px solid var(--border-color); overflow: hidden; }
        summary { font-weight: 600; font-size: 1.2rem; padding: 1rem; cursor: pointer; color: var(--accent-color); background-color: var(--table-header-bg); list-style: none; display: flex; justify-content: space-between; }
        summary::-webkit-details-marker { display: none; }
        summary::after { content: '+'; font-size: 1.5rem; transition: transform 0.2s; }
        details[open] summary::after { transform: rotate(45deg); }
        table { width: 100%; border-collapse: collapse; table-layout: fixed; }
        th, td { padding: 0.8rem 1rem; text-align: left; border-bottom: 1px solid var(--border-color); vertical-align: top; overflow-wrap: anywhere; word-break: break-word; }
        pre { white-space: pre-wrap; word-break: break-word; }
        thead { background-color: var(--table-header-bg); color: #a9b1d6; font-weight: 600; }
        tbody tr:nth-child(even) { background-color: #2e345250; }
        thead th:nth-child(1) { width: 10%; }
        thead th:nth-child(2) { width: 30%; }
        thead th:nth-child(3) { width: 50%; }
        thead th:nth-child(4) { width: 10%; }
        td:nth-child(1) { width: 10%; font-weight: 600; color: #a9b1d6; }
        td:nth-child(2) { width: 30%; font-family: monospace; color: #e0af68; }
        td:nth-child(3) { width: 50%; white-space: pre-wrap; word-break: break-word; font-family: monospace; font-size: 0.85rem; }
        td:nth-child(4) { width: 10%; }
        .status-badge { display: inline-block; padding: 0.2rem 0.5rem; border-radius: 9999px; font-weight: 600; font-size: 0.8rem; }
        .status-pass { background: rgba(52,211,153,0.15); color: var(--green); border: 1px solid rgba(52,211,153,0.4); }
        .status-fail { background: rgba(248,113,113,0.15); color: var(--red); border: 1px solid rgba(248,113,113,0.4); }
        .status-partial { background: rgba(250,204,21,0.15); color: var(--yellow); border: 1px solid rgba(250,204,21,0.4); }
        .status-notes { display: block; margin-top: 0.25rem; font-size: 0.8rem; color: #a9b1d6; white-space: pre-wrap; }
        .footer { text-align: center; margin-top: 2rem; font-size: 0.8rem; color: #7a82ac; }
    </style>
</head>
<body>
    <div class="container">
        <h1>System Hardware & Performance Report</h1>
        <div class="report-meta">Generated on: $(date +"%Y-%m-%d %H:%M:%S")</div>
        <div class="report-host">Hostname: ${HOSTNAME_FQDN} • Primary IP: ${PRIMARY_IP}</div>
EOF
}

# Write follow-up section
write_followup_section() {
    cat >> "${OUTPUT_FILE}" << EOF
    </div>
    <div class="footer">Script by System Test Automation</div>
EOF
}

# Finalize HTML report
finalize_html_report() {
    # Generate JSON test data block
    {
        echo '    <script type="application/json" id="test-data">'
        echo '    {'
        printf '      "test_run_id": %s,\n' "$(printf '%s' "$TEST_RUN_ID" | jq -Rs .)"
        printf '      "test_date": %s,\n' "$(printf '%s' "$TEST_DATE" | jq -Rs .)"
        echo '      "server_info": {'
        printf '        "hostname": %s,\n' "$(printf '%s' "$HOSTNAME_FQDN" | jq -Rs .)"
        printf '        "ip_address": %s\n' "$(printf '%s' "$PRIMARY_IP" | jq -Rs .)"
        echo '      },'
        echo '      "tests": ['
        
        # Generate test entries
        for i in "${!TEST_DATA_IDS[@]}"; do
            [[ $i -gt 0 ]] && echo ','
            echo '        {'
            printf '          "test_id": %s,\n' "$(printf '%s' "${TEST_DATA_IDS[$i]}" | jq -Rs .)"
            printf '          "test_name": %s,\n' "$(printf '%s' "${TEST_DATA_NAMES[$i]}" | jq -Rs .)"
            printf '          "category": %s,\n' "$(printf '%s' "${TEST_DATA_CATEGORIES[$i]}" | jq -Rs .)"
            printf '          "command": %s,\n' "$(printf '%s' "${TEST_DATA_COMMANDS[$i]}" | jq -Rs .)"
            printf '          "result": %s,\n' "$(printf '%s' "${TEST_DATA_RESULTS[$i]}" | jq -Rs .)"
            printf '          "result_type": %s,\n' "$(printf '%s' "${TEST_DATA_TYPES[$i]}" | jq -Rs .)"
            printf '          "status": %s\n' "$(printf '%s' "${TEST_DATA_STATUSES[$i]}" | jq -Rs .)"
            echo -n '        }'
        done
        
        echo ''
        echo '      ]'
        echo '    }'
        echo '    </script>'
    } >> "${OUTPUT_FILE}"
    
    # Close body and HTML
    cat >> "${OUTPUT_FILE}" << 'EOF'
</body>
</html>
EOF
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    if [[ $EUID -ne 0 ]]; then
       log_error "This script must be run as root or with sudo."
       exit 1
    fi
    
    # Check for required dependencies
    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed."
        log_warn "Install it with: sudo apt-get install -y jq"
        exit 1
    fi

    # Parse command-line arguments
    for arg in "$@"; do
        case "$arg" in
            --nocheck)
                NOCHECK_MODE=true
                ;;
            --headless)
                HEADLESS_MODE=true
                ;;
            --noinstall)
                NOINSTALL_MODE=true
                ;;
            --noburn)
                NOBURN_MODE=true
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
        esac
    done
    
    clear
    echo -e "${C_GREEN}===========================================${C_RESET}"
    echo -e "${C_GREEN}  System Hardware & Performance Test Tool  ${C_RESET}"
    echo -e "${C_GREEN}===========================================${C_RESET}"
    echo

    if $NOCHECK_MODE; then
        log_warn "Running in --nocheck mode. Dependency checks and prompts will be skipped."
    fi

    log "Starting all tests. Results will be saved to: ${C_YELLOW}${OUTPUT_FILE}${C_RESET}"
    echo

    # Initialize HTML report
    log "Initializing HTML report..."
    initialize_html_report

    # Load manifest and iterate tests
    log "Loading test manifest..."
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log_error "Manifest file not found: $MANIFEST_FILE"
        exit 1
    fi

# Parse manifest using jq (robust JSON parsing)
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for parsing manifest. Install it: sudo apt-get install jq"
        exit 1
    fi
    
    # Extract tests from manifest as JSON array
    local tests_json
    tests_json=$(jq -c '.tests[]' "$MANIFEST_FILE" 2>/dev/null)
    if [[ -z "$tests_json" ]]; then
        log_error "Failed to parse manifest file: $MANIFEST_FILE"
        exit 1
    fi
    
    local current_category=""
    # Process each test from manifest
    while IFS= read -r test_entry; do
        local script=$(echo "$test_entry" | jq -r '.script')
        local test_id=$(echo "$test_entry" | jq -r '.id')
        local category=$(echo "$test_entry" | jq -r '.category')
        local skip_flags=$(echo "$test_entry" | jq -r '.skip_flags | @csv' | tr -d '"')
        
        # Check if test should be skipped
        local should_skip=false
        if [[ "$skip_flags" != "null" ]] && [[ -n "$skip_flags" ]]; then
            for flag in $skip_flags; do
                if [[ "$flag" == "--noburn" ]] && $NOBURN_MODE; then
                    should_skip=true
                    break
                fi
                if [[ "$flag" == "--noinstall" ]] && $NOINSTALL_MODE; then
                    should_skip=true
                    break
                fi
            done
        fi
        
        if $should_skip; then
            log_warn "Skipping test: $test_id (flag conditions met)"
            continue
        fi

        # Open new category section if changed
        if [[ "$category" != "$current_category" ]]; then
            if [[ -n "$current_category" ]]; then
                close_html_category_section
            fi
            add_html_category_header "$category"
            current_category="$category"
        fi

        # Execute test script - it outputs HTML directly to OUTPUT_FILE
        local script_full_path="$SCRIPT_DIR/$script"
        echo
        echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
        echo -e "${C_GREEN}▶${C_RESET} ${C_CYAN}$test_id${C_RESET}"
        echo -e "${C_YELLOW}[RUNNING]${C_RESET} $script"
        echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
        
        local script_output
        script_output=$(execute_test_script "$script_full_path" "$test_id" 2>&1)
        local script_exit=$?
        
        if [[ $script_exit -eq 0 ]]; then
            # Display test output in a box
            if [[ -n "$script_output" ]]; then
                echo -e "${C_CYAN}┌─ Output ─────────────────────────────────┐${C_RESET}"
                echo "$script_output" | while IFS= read -r line; do
                    printf "${C_CYAN}│${C_RESET} %s\n" "$line"
                done
                echo -e "${C_CYAN}└───────────────────────────────────────────┘${C_RESET}"
            fi
            echo -e "${C_GREEN}✓ COMPLETE${C_RESET} - $test_id"
        else
            echo -e "${C_RED}✗ ERROR${C_RESET} - $test_id (exit code: $script_exit)"
            if [[ -n "$script_output" ]]; then
                echo -e "${C_CYAN}┌─ Error Output ───────────────────────────┐${C_RESET}"
                echo "$script_output" | while IFS= read -r line; do
                    printf "${C_CYAN}│${C_RESET} %s\n" "$line"
                done
                echo -e "${C_CYAN}└───────────────────────────────────────────┘${C_RESET}"
            fi
        fi
    done <<< "$tests_json"

    # Close final category
    if [[ -n "$current_category" ]]; then
        close_html_category_section
    fi

    # Write follow-up section and finalize
    write_followup_section
    finalize_html_report

    echo
    log_success "All tests have been completed."
    log "Report saved to: ${C_YELLOW}${OUTPUT_FILE}${C_RESET}"
    echo
}

main "$@"
