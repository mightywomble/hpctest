#!/bin/bash

# ==============================================================================
# Test Script: System Information
# Category: System
# Description: Basic system information tests
# ==============================================================================

source "$(dirname "$0")/../config.sh"

# Test: System Name
result=$(cat /sys/devices/virtual/dmi/id/product_name 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="Unable to read product name"
fi
output_html_result "System Name" "cat /sys/devices/virtual/dmi/id/product_name" "$result" "$status" "$notes" "system-name" "System" "text"

# Test: OS Version
result=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="Unable to determine OS version"
fi
output_html_result "OS Version" "grep PRETTY_NAME /etc/os-release | cut -d '\"' -f 2" "$result" "$status" "$notes" "os-version" "System" "text"

# Test: OS Full Version (lsb_release -a)
if command -v lsb_release &>/dev/null; then
    result=$(lsb_release -a 2>&1)
    exit_code=$?
    if [[ $exit_code -eq 0 && -n "$result" ]]; then
        status="pass"
        notes=""
    else
        status="fail"
        notes="lsb_release command failed"
    fi
else
    result="lsb_release command not found"
    status="fail"
    notes="Install lsb-release package"
fi
output_html_result "OS Full Version (lsb_release -a)" "lsb_release -a" "$result" "$status" "$notes" "os-full-version" "System" "text"
