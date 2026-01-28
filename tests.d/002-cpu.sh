#!/bin/bash

# ==============================================================================
# Test Script: CPU Information
# Category: CPU
# Description: CPU model, cores, NUMA configuration, and lscpu output
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Test: CPU Model
result=$(lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//')
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="Unable to determine CPU model"
    result="Unknown"
fi
output_test_result "CPU Model" "lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//" "$result" "$status" "$notes"
echo ","

# Test: CPU Core Count
result=$(lscpu | grep -E '^(Socket|Core)' | tr '\n' ' ' | sed 's/  */ /g')
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="Unable to determine core count"
    result="Unknown"
fi
output_test_result "CPU Core Count" "lscpu | grep -E '^(Socket|Core)' | tr '\\n' ' ' | sed 's/  */ /g'" "$result" "$status" "$notes"
echo ","

# Test: NUMA Configuration
result=$(lscpu | grep 'NUMA node' | tr '\n' ' ' | sed 's/  */ /g')
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="No NUMA configuration detected"
    result="Single node system"
fi
output_test_result "NUMA Configuration" "lscpu | grep 'NUMA node' | tr '\\n' ' ' | sed 's/  */ /g'" "$result" "$status" "$notes"
echo ","

# Test: lscpu Summary (as collapsible HTML)
lscpu_out=$(lscpu 2>&1)
lscpu_sanitized=$(printf '%s\n' "$lscpu_out" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
lscpu_html="{\"details\": \"lscpu output\", \"content\": \"$(printf '%s\n' "$lscpu_out" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/ /g')\", \"type\": \"pre\"}"
output_test_result_html "lscpu Summary" "lscpu" "$lscpu_html" "pass" "Complete lscpu output"

finish_json_output
