#!/bin/bash

# ==============================================================================
# Test Script: CPU Information
# Category: CPU
# Description: CPU model, cores, NUMA configuration, and lscpu output
# ==============================================================================

source "$(dirname "$0")/../config.sh"
echo "[RUNNING] CPU tests"

# Test: CPU Model
result=$(lscpu 2>&1 | grep 'Model name:' | sed 's/Model name:[[:space:]]*//') || true
if [[ -n "$result" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="Unable to determine CPU model"
fi
output_html_result "CPU Model" "lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//'" "$result" "$status" "$notes" "cpu-model" "CPU" "text"

# Test: CPU Core Count
result=$(lscpu 2>&1 | grep -E '^(Socket|Core)' | tr '\n' ' ' | sed 's/  */ /g') || true
if [[ -n "$result" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="Unable to determine core count"
fi
output_html_result "CPU Core Count" "lscpu | grep -E '^(Socket|Core)'" "$result" "$status" "$notes" "cpu-core-count" "CPU" "numeric"

# Test: NUMA Configuration
result=$(lscpu 2>&1 | grep 'NUMA node' | tr '\n' ' ' | sed 's/  */ /g') || true
if [[ -n "$result" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="Single node system (no NUMA detected)"
fi
output_html_result "NUMA Configuration" "lscpu | grep 'NUMA node'" "$result" "$status" "$notes" "numa-config" "CPU" "text"

# Test: lscpu Summary
lscpu_out=$(lscpu 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$lscpu_out" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="lscpu command failed"
fi
output_html_result "lscpu Summary" "lscpu" "$lscpu_out" "$status" "$notes" "lscpu-summary" "CPU" "text"
