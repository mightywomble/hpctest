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

# Execute a single test script and capture JSON output
execute_test_script() {
    local script_path="$1"
    local test_id="$2"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Test script not found: $script_path"
        echo "[]"
        return 1
    fi
    
    local output
    local exit_code
    
    # Run the script and capture output
    output=$(bash "$script_path" 2>&1)
    exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Test $test_id failed with exit code $exit_code"
        echo "$output"
        return 1
    fi
    
    # Return the JSON output
    echo "$output"
}

# Parse JSON test result and render to HTML
render_test_result_html() {
    local test_json="$1"
    
    # Use jq if available for reliable parsing, otherwise use basic parsing
    if command -v jq &>/dev/null; then
        local test_name=$(echo "$test_json" | jq -r '.test_name // ""' 2>/dev/null)
        local command=$(echo "$test_json" | jq -r '.command // ""' 2>/dev/null)
        local result=$(echo "$test_json" | jq -r '.result // ""' 2>/dev/null)
        local status=$(echo "$test_json" | jq -r '.status // ""' 2>/dev/null)
        local notes=$(echo "$test_json" | jq -r '.notes // ""' 2>/dev/null)
        local result_html=$(echo "$test_json" | jq -r '.result_html // false' 2>/dev/null)
        
        if [[ "$result_html" == "true" ]]; then
            # Result field contains HTML/JSON object, display as-is
            add_row_to_html_report "$test_name" "$command" "$result" "$status" "$notes"
        else
            # Regular text result
            add_row_to_html_report "$test_name" "$command" "$result" "$status" "$notes"
        fi
    else
        # Fallback: basic parsing without jq
        local test_name=$(echo "$test_json" | grep -o '"test_name"\s*:\s*"[^"]*"' | head -1 | sed 's/.*:\s*"\(.*\)"/\1/')
        local command=$(echo "$test_json" | grep -o '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*:\s*"\(.*\)"/\1/')
        local result=$(echo "$test_json" | grep -o '"result"\s*:\s*"[^"]*"' | head -1 | sed 's/.*:\s*"\(.*\)"/\1/')
        local status=$(echo "$test_json" | grep -o '"status"\s*:\s*"[^"]*"' | head -1 | sed 's/.*:\s*"\(.*\)"/\1/')
        local notes=$(echo "$test_json" | grep -o '"notes"\s*:\s*"[^"]*"' | head -1 | sed 's/.*:\s*"\(.*\)"/\1/')
        
        add_row_to_html_report "$test_name" "$command" "$result" "$status" "$notes"
    fi
}

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

add_row_to_html_report() {
    local test_name="$1"
    local command="$2"
    local result="$3"
    local status_raw="${4:-N/A}"
    local notes_text="${5:-}"

    local status_lower=$(echo "$status_raw" | tr '[:upper:]' '[:lower:]')
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

    local sanitized_cmd
    sanitized_cmd=$(echo "$command" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
    local sanitized_result
    sanitized_result=$(echo "$result" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')

    local status_cell=""
    if [[ -n "$status_label" ]]; then
        if [[ -n "$notes_text" ]]; then
            local sanitized_notes
            sanitized_notes=$(echo "$notes_text" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span><span class=\"status-notes\">${sanitized_notes}</span>"
        else
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span>"
        fi
    else
        status_cell=""
    fi

    echo "<tr><td>${test_name}</td><td>${sanitized_cmd}</td><td><pre>${sanitized_result}</pre></td><td>${status_cell}</td></tr>" >> "${OUTPUT_FILE}"
}

add_row_to_html_report_html() {
    local test_name="$1"
    local command="$2"
    local result_html="$3"
    local status_raw="${4:-N/A}"
    local notes_text="${5:-}"

    local status_lower=$(echo "$status_raw" | tr '[:upper:]' '[:lower:]')
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

    local sanitized_cmd
    sanitized_cmd=$(echo "$command" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')

    local status_cell=""
    if [[ -n "$status_label" ]]; then
        if [[ -n "$notes_text" ]]; then
            local sanitized_notes
            sanitized_notes=$(echo "$notes_text" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span><span class=\"status-notes\">${sanitized_notes}</span>"
        else
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span>"
        fi
    else
        status_cell=""
    fi

    echo "<tr><td>${test_name}</td><td>${sanitized_cmd}</td><td>${result_html}</td><td>${status_cell}</td></tr>" >> "${OUTPUT_FILE}"
}

# Initialize HTML report with header and styles
initialize_html_report() {
    log "Initializing HTML report file: ${OUTPUT_FILE}"
    cat > "${OUTPUT_FILE}" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
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

    # Simple iteration through manifest using grep and sed (jq-free approach)
    # Extract test scripts in order from manifest
    local test_scripts=($(grep -o '"script"\s*:\s*"[^"]*"' "$MANIFEST_FILE" | sed 's/.*:\s*"\(.*\)"/\1/'))
    local test_ids=($(grep -o '"id"\s*:\s*"[^"]*"' "$MANIFEST_FILE" | sed 's/.*:\s*"\(.*\)"/\1/'))
    local test_categories=($(grep -o '"category"\s*:\s*"[^"]*"' "$MANIFEST_FILE" | sed 's/.*:\s*"\(.*\)"/\1/'))

    local current_category=""
    for i in "${!test_scripts[@]}"; do
        local script="${test_scripts[$i]}"
        local test_id="${test_ids[$i]}"
        local category="${test_categories[$i]}"

        # Open new category section if changed
        if [[ "$category" != "$current_category" ]]; then
            if [[ -n "$current_category" ]]; then
                close_html_category_section
            fi
            add_html_category_header "$category"
            current_category="$category"
        fi

        # Execute test script and capture JSON output
        local script_full_path="$SCRIPT_DIR/$script"
        echo -e "${C_CYAN}[START]${C_RESET} $test_id"
        
        # Separate the JSON from any intermediate output
        local json_output
        local full_output
        full_output=$(execute_test_script "$script_full_path" "$test_id" 2>&1)
        local script_exit=$?

        if [[ $script_exit -eq 0 ]]; then
            json_output="$full_output"
            
            # Extract and display non-JSON output for visibility
            echo -e "${C_CYAN}[OUTPUT]${C_RESET}"
            echo "$json_output" | grep -v -E '^(\[|\]|  \{|^\}|^,$)' | sed '/^$/d' || true
            
            # Parse JSON array and render each test result
            if command -v jq &>/dev/null; then
                echo "$json_output" | jq -c '.[]' 2>/dev/null | while read -r obj; do
                    render_test_result_html "$obj"
                done
            else
                # Fallback: simple line-by-line parsing for small JSON objects
                local in_obj=false
                local obj=""
                while IFS= read -r line; do
                    if [[ "$line" =~ ^[[:space:]]*\{ ]]; then
                        in_obj=true
                        obj="$line"
                    elif [[ $in_obj == true ]]; then
                        obj+=$'\n'"$line"
                        if [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*,?[[:space:]]*$ ]]; then
                            in_obj=false
                            render_test_result_html "$obj"
                            obj=""
                        fi
                    fi
                done <<< "$json_output"
            fi
            
            echo -e "${C_GREEN}[COMPLETE]${C_RESET} $test_id"
        else
            echo -e "${C_RED}[ERROR]${C_RESET} $test_id failed with exit code $script_exit"
            echo "$full_output"
        fi
    done

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
