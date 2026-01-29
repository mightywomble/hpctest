#!/bin/bash

# ==============================================================================
# Test Script: RAM Information
# Category: RAM
# Description: System RAM and memory information
# ==============================================================================

source "$(dirname "$0")/../config.sh"
echo "[RUNNING] RAM tests"

# Test: RAM Size
result=$(free -h | grep Mem: | awk '{print $2}')
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="Unable to determine RAM size"
    result="Unknown"
fi
output_html_result "RAM Size" "free -h | grep Mem: | awk '{print $2}'" "$result" "$status" "$notes" "ram-size" "RAM" "text"
