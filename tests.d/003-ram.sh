#!/bin/bash

# ==============================================================================
# Test Script: RAM Information
# Category: RAM
# Description: System RAM and memory information
# ==============================================================================

source "$(dirname "$0")/../config.sh"
echo "[RUNNING] RAM tests"

# Test: RAM Size
result=$(free -h 2>&1 | grep Mem: | awk '{print $2}')
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "RAM Size" "free -h | grep Mem: | awk '{print $2}'" "$result" "pass" "" "ram-size" "RAM" "text"
else
    output_html_result "RAM Size" "free -h | grep Mem: | awk '{print $2}'" "Unknown" "fail" "Unable to determine RAM size" "ram-size" "RAM" "text"
fi
