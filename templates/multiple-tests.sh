#!/bin/bash

# ==============================================================================
# Test Script: [TEST_NAME]
# Category: [CATEGORY]
# Description: [DESCRIPTION]
# ==============================================================================
#
# This template runs multiple related tests in one script.
# Use this when:
# - You have several related tests (e.g., multiple system metrics)
# - Tests are related and should appear together in the report
# - It's more efficient to run them in one script
#
# Examples of tests that use this pattern:
# - Test multiple CPU properties (cores, sockets, frequencies)
# - Check multiple memory metrics (total, available, swap)
# - Verify multiple service statuses
#

source "$(dirname "$0")/../config.sh"

# ============================================================================
# TEST 1: [TEST_NAME_1]
# ============================================================================
result=$(command1 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="Command failed or returned no output"
fi
output_html_result "[TEST_NAME_1]" "command1" "$result" "$status" "$notes" "[TEST_ID_1]" "[CATEGORY]" "text"

# Output a comma between tests (required for JSON format)
echo ","

# ============================================================================
# TEST 2: [TEST_NAME_2]
# ============================================================================
result=$(command2 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="Command failed or returned no output"
fi
output_html_result "[TEST_NAME_2]" "command2" "$result" "$status" "$notes" "[TEST_ID_2]" "[CATEGORY]" "text"

# Output a comma between tests
echo ","

# ============================================================================
# TEST 3: [TEST_NAME_3]
# ============================================================================
# Note: NO comma after the last test!
result=$(command3 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    status="pass"
    notes=""
else
    status="fail"
    notes="Command failed or returned no output"
fi
output_html_result "[TEST_NAME_3]" "command3" "$result" "$status" "$notes" "[TEST_ID_3]" "[CATEGORY]" "text"

# ============================================================================
# IMPORTANT NOTES:
# ============================================================================
# 1. Use 'echo ","' between tests (except after the last one)
# 2. Each test must have a unique [TEST_ID]
# 3. All tests should use the same [CATEGORY]
# 4. The JSON output is an array of test results
# 5. You can have as many tests as you want in one script
#
# Example with start/finish functions for cleaner JSON:
#   start_json_output
#   # Test 1
#   output_html_result ...
#   echo ","
#   # Test 2
#   output_html_result ...
#   finish_json_output
