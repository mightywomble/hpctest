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
    
    log "Running test: $test_id..."
    local output
    output=$(bash "$script_path" 2>&1)
    
    # Return the JSON output
    echo "$output"
}

# Parse JSON test result and render to HTML
render_test_result_html() {
    local test_json="$1"
    local has_html=$(echo "$test_json" | grep -o '"result_html"\s*:\s*true' | head -1)
    
    if [[ -n "$has_html" ]]; then
        # This is an HTML result, extract and pass directly
        local test_name=$(echo "$test_json" | grep -o '"test_name"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        local command=$(echo "$test_json" | grep -o '"command"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        local status=$(echo "$test_json" | grep -o '"status"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        local notes=$(echo "$test_json" | grep -o '"notes"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        
        # Extract HTML result (everything between "result": and next comma/bracket)
        local result_html=$(echo "$test_json" | sed -n '/"result":/,/},\?$/p' | head -n 1 | sed 's/"result":\s*//;s/\s*},\?$//')
        
        add_row_to_html_report_html "$test_name" "$command" "$result_html" "$status" "$notes"
    else
        # Regular JSON result
        local test_name=$(echo "$test_json" | grep -o '"test_name"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        local command=$(echo "$test_json" | grep -o '"command"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        local result=$(echo "$test_json" | grep -o '"result"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        local status=$(echo "$test_json" | grep -o '"status"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        local notes=$(echo "$test_json" | grep -o '"notes"\s*:\s*"[^"]*"' | sed 's/.*:\s*"\(.*\)"/\1/')
        
        add_row_to_html_report "$test_name" "$command" "$result" "$status" "$notes"
    fi
}

# Source HTML generation functions from backup (or include them)
# These are extracted from the original hpctests.sh.backup
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

    # Load and execute HTML initialization (from backup script)
    log "Initializing HTML report..."
    # Source the HTML initialization code from backup
    source <(sed -n '/^initialize_html_report()/,/^}/p' "$SCRIPT_DIR/hpctests.sh.backup")
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
        local json_output=$(execute_test_script "$script_full_path" "$test_id")

        # Parse JSON array and render each test result
        # Simple JSON parsing for each test object
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*\{ ]]; then
                # Start of a test object
                local obj="$line"
                while IFS= read -r subline && [[ ! "$subline" =~ ^[[:space:]]*\} ]]; do
                    obj+=$'\n'"$subline"
                done
                obj+=$'\n'"$subline"  # Add closing brace
                
                render_test_result_html "$obj"
            fi
        done <<< "$json_output"

        log_success "Completed: $test_id"
    done

    # Close final category
    if [[ -n "$current_category" ]]; then
        close_html_category_section
    fi

    # Write follow-up section and finalize (source from backup)
    source <(sed -n '/^write_followup_section()/,/^}/p' "$SCRIPT_DIR/hpctests.sh.backup")
    source <(sed -n '/^finalize_html_report()/,/^}/p' "$SCRIPT_DIR/hpctests.sh.backup")
    
    write_followup_section
    finalize_html_report

    echo
    log_success "All tests have been completed."
    log "Report saved to: ${C_YELLOW}${OUTPUT_FILE}${C_RESET}"
    echo
}

main "$@"
