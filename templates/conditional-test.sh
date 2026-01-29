#!/bin/bash

# ==============================================================================
# Test Script: [TEST_NAME]
# Category: [CATEGORY]
# Description: [DESCRIPTION]
# ==============================================================================
#
# This template is for tests with conditional logic (if/else).
# Use this when:
# - You need to check if something exists or has a property
# - You have different outputs for pass vs fail
# - You need to evaluate multiple conditions
#
# Examples of tests that use this pattern:
# - Check if a service is running
# - Check if a file exists
# - Verify a configuration value matches expected
# - Check if a threshold is met
#

source "$(dirname "$0")/../config.sh"

# Check your condition
if [[ [CONDITION] ]]; then
    # Condition is true - test passes
    result="[PASS_MESSAGE]"
    status="pass"
    notes="[PASS_NOTES]"
else
    # Condition is false - test fails
    result="[FAIL_MESSAGE]"
    status="fail"
    notes="[FAIL_NOTES]"
fi

# Output the result
output_html_result "[TEST_NAME]" "[YOUR_COMMAND]" "$result" "$status" "$notes" "[TEST_ID]" "[CATEGORY]" "text"

# ============================================================================
# COMMON CONDITION EXAMPLES:
# ============================================================================
# File exists:              [[ -f /path/to/file ]]
# Directory exists:         [[ -d /path/to/dir ]]
# String is not empty:      [[ -n "$variable" ]]
# String is empty:          [[ -z "$variable" ]]
# String equals value:      [[ "$variable" == "value" ]]
# String contains:          [[ "$variable" == *"substring"* ]]
# Number comparison:        (( number > 100 ))
# Command success:          command_name &>/dev/null
# File readable:            [[ -r /path/to/file ]]
