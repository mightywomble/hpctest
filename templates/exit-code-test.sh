#!/bin/bash

# ==============================================================================
# Test Script: [TEST_NAME]
# Category: [CATEGORY]
# Description: [DESCRIPTION]
# ==============================================================================
#
# This template uses exit codes to determine pass/fail.
# Use this when:
# - A command either succeeds (exit 0) or fails (exit != 0)
# - You need to distinguish between command success and no output
# - You want to capture both stdout and stderr
#
# Examples of tests that use this pattern:
# - Run a system command and check if it worked
# - Execute a tool and verify it runs successfully
# - Check if a command produced valid output
#

source "$(dirname "$0")/../config.sh"

# Run command and capture both output and exit code
result=$([YOUR_COMMAND] 2>&1)
exit_code=$?

# Check the exit code
if [[ $exit_code -eq 0 ]]; then
    # Command succeeded
    if [[ -n "$result" ]]; then
        status="pass"
        notes="Command executed successfully"
    else
        status="pass"
        result="(No output)"
        notes="Command succeeded with no output"
    fi
else
    # Command failed
    status="fail"
    notes="Command failed with exit code $exit_code"
fi

# Output the result
output_html_result "[TEST_NAME]" "[YOUR_COMMAND]" "$result" "$status" "$notes" "[TEST_ID]" "[CATEGORY]" "text"

# ============================================================================
# HOW TO USE EXIT CODES:
# ============================================================================
# Most Linux commands return:
# - 0 = success
# - 1 = general error
# - 2 = misuse of shell command
# - 126 = command found but not executable
# - 127 = command not found
#
# Always capture the exit code immediately after running a command:
# result=$(your_command 2>&1)
# exit_code=$?
#
# The "2>&1" redirects stderr to stdout, so you capture error messages too.
