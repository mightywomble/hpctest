#!/bin/bash

# ==============================================================================
# Test Script: RAM Information
# Category: RAM
# Description: System RAM and memory information
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Test: RAM Size
result=$(free -h | grep Mem: | awk '{print $2}')
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="Unable to determine RAM size"
    result="Unknown"
fi
output_test_result "RAM Size" "free -h | grep Mem: | awk '{print \$2}'" "$result" "$status" "$notes"

finish_json_output
