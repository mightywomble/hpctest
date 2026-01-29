#!/bin/bash

# ==============================================================================
# Test Script: [TEST_NAME]
# Category: [CATEGORY]
# Description: [DESCRIPTION]
# ==============================================================================
# 
# This is a simple single-test template. Use this when:
# - Running one command and checking the result
# - The command either succeeds or fails
# - You want to report a simple pass/fail status
#
# Examples of tests that use this pattern:
# - Get OS version
# - Check system uptime
# - Read a configuration value
# - Display a simple metric
#

source "$(dirname "$0")/../config.sh"

# Run your command and capture the result
result=$([YOUR_COMMAND] 2>&1)

# Determine if it passed or failed
# You can use simple logic here
status="pass"
notes="[NOTES]"

# If you need conditional logic based on the result, do it here:
# if [[ -z "$result" ]]; then
#     status="fail"
#     notes="Command returned no output"
# fi

# Output the test result
output_html_result "[TEST_NAME]" "[YOUR_COMMAND]" "$result" "$status" "$notes" "[TEST_ID]" "[CATEGORY]" "text"
