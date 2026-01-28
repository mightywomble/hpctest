#!/bin/bash

# ==============================================================================
# Test Script: Network Speed Tests
# Category: Network Speed Tests
# Description: Internet bandwidth tests using speedtest-cli
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

log_warn "Network speed tests can take 1-3 minutes. We will discover servers and run two tests (Nearby, Europe). Please wait..."

if ! command -v speedtest-cli &>/dev/null; then
    output_test_result "Speedtest Nearby" "speedtest-cli --simple" "speedtest-cli not installed" "partial" "Install speedtest-cli to enable"
    echo ","
    output_test_result "Speedtest Europe" "speedtest-cli --simple" "speedtest-cli not installed" "partial" "Install speedtest-cli to enable"
    finish_json_output
    exit 0
fi

# Discover servers
log "Discovering Speedtest servers..."
list_all=$(speedtest-cli --list 2>/dev/null)

# Find nearby server (default: first in list)
sid_near=""
label_near=""
if [[ -n "$SPEEDTEST_SERVER_NEARBY" ]]; then
    sid_near="$SPEEDTEST_SERVER_NEARBY"
    label_near=$(echo "$list_all" | grep -E "^\\s*${sid_near}\\)" | sed 's/^ *[0-9]\\+) //')
else
    sid_near=$(echo "$list_all" | grep -Eo '^[[:space:]]*[0-9]+' | head -n 1 | tr -d ' ')
    label_near=$(echo "$list_all" | grep -E "^\\s*${sid_near}\\)" | sed 's/^ *[0-9]\\+) //')
fi

# Find EU server
sid_eu=""
label_eu=""
if [[ -n "$SPEEDTEST_SERVER_EU" ]]; then
    sid_eu="$SPEEDTEST_SERVER_EU"
    label_eu=$(echo "$list_all" | grep -E "^\\s*${sid_eu}\\)" | sed 's/^ *[0-9]\\+) //')
else
    local EU_PATTERN="Germany|France|Netherlands|United Kingdom|UK|Sweden|Spain|Italy|Switzerland|Norway|Denmark|Finland|Poland|Ireland|Belgium|Austria|Czech|Portugal|Hungary|Romania|Greece|Iceland|Luxembourg|Slovakia|Slovenia|Lithuania|Latvia|Estonia|Bulgaria|Croatia|Serbia"
    sid_eu=$(echo "$list_all" | grep -E "$EU_PATTERN" | head -n 1 | grep -Eo '^[[:space:]]*[0-9]+' | tr -d ' ')
    label_eu=$(echo "$list_all" | grep -E "^\\s*${sid_eu}\\)" | sed 's/^ *[0-9]\\+) //')
fi

# Helper function to run one speedtest
run_speedtest_server() {
    local sid="$1"
    local label="$2"
    local tag="$3"
    
    if [[ -z "$sid" ]]; then
        output_test_result "Speedtest ${tag}" "speedtest-cli --simple" "No matching server" "partial" "No server ID for ${tag}"
        return
    fi
    
    log "Running Speedtest (${tag})..."
    local out ec
    out=$(speedtest-cli --server "$sid" --simple 2>&1)
    ec=$?
    
    local status="pass"
    local note="${label}"
    
    if [[ $ec -ne 0 ]]; then
        status="fail"
        note="${label:+${label} - }Exit code $ec"
    else
        # Parse speeds
        local dl=$(echo "$out" | head -n1)
        local ul=$(echo "$out" | tail -n1)
        
        local dl_ok=1
        local ul_ok=1
        if (( ${MIN_DOWNLOAD_MBPS:-0} > 0 )) && [[ -n "$dl" ]] && (( ${dl%.*} < MIN_DOWNLOAD_MBPS )); then
            dl_ok=0
        fi
        if (( ${MIN_UPLOAD_MBPS:-0} > 0 )) && [[ -n "$ul" ]] && (( ${ul%.*} < MIN_UPLOAD_MBPS )); then
            ul_ok=0
        fi
        
        if (( ${MIN_DOWNLOAD_MBPS:-0} > 0 || ${MIN_UPLOAD_MBPS:-0} > 0 )); then
            if (( dl_ok==0 || ul_ok==0 )); then
                status="fail"
                note="${label:+${label} - }Thresholds DL>=${MIN_DOWNLOAD_MBPS} UL>=${MIN_UPLOAD_MBPS} (got DL=${dl:-N/A}, UL=${ul:-N/A})"
            else
                note="${label:+${label} - }DL=${dl:-N/A} UL=${ul:-N/A} (thresholds DL>=${MIN_DOWNLOAD_MBPS} UL>=${MIN_UPLOAD_MBPS})"
            fi
        else
            note="${label:+${label} - }DL=${dl:-N/A} UL=${ul:-N/A}"
        fi
    fi
    
    output_test_result "Speedtest ${tag}" "speedtest-cli --server ${sid} --simple" "$out" "$status" "$note"
}

run_speedtest_server "$sid_near" "$label_near" "Nearby"
echo ","
run_speedtest_server "$sid_eu" "$label_eu" "Europe"

finish_json_output
