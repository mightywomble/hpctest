#!/bin/bash

# ==============================================================================
# Test Script: CPU Information
# Category: CPU
# Description: CPU model, cores, NUMA configuration, and lscpu output
# ==============================================================================

source "$(dirname "$0")/../config.sh"
echo "[RUNNING] CPU tests"
result=$(lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//')
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="Unable to determine CPU model"
    result="Unknown"
fi
output_html_result "CPU Model" "lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//'" "$result" "$status" "$notes" "cpu-model" "CPU" "text"

# Test: CPU Core Count
result=$(lscpu | grep -E '^(Socket|Core)' | tr '\n' ' ' | sed 's/  */ /g')
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="Unable to determine core count"
    result="Unknown"
fi
output_html_result "CPU Core Count" "lscpu | grep -E '^(Socket|Core)'" "$result" "$status" "$notes" "cpu-core-count" "CPU" "numeric"

# Test: NUMA Configuration
result=$(lscpu | grep 'NUMA node' | tr '\n' ' ' | sed 's/  */ /g')
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="No NUMA configuration detected"
    result="Single node system"
fi
output_html_result "NUMA Configuration" "lscpu | grep 'NUMA node'" "$result" "$status" "$notes" "numa-config" "CPU" "text"

# Test: lscpu Summary
lscpu_out=$(lscpu 2>&1)
output_html_result "lscpu Summary" "lscpu" "$lscpu_out" "pass" "Complete lscpu output" "lscpu-summary" "CPU" "text"
