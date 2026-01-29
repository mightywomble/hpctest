#!/bin/bash

# ==============================================================================
# Test Script: [TEST_NAME]
# Category: [CATEGORY]
# Description: [DESCRIPTION]
# ==============================================================================
#
# This template searches for specific content in command output.
# Use this when:
# - Looking for specific text or patterns
# - Checking if something is present in output
# - Detecting specific configuration values
# - Verifying expected behavior from command output
#
# Examples of tests that use this pattern:
# - Search for NFS mounts (mount | grep nfs)
# - Look for specific driver in lsmod output
# - Find configuration lines in files
# - Detect service status in output
#

source "$(dirname "$0")/../config.sh"

# Run command and search for pattern
# The "|| true" prevents script exit if grep finds nothing
result=$(command 2>&1 | grep -i "[PATTERN]" || true)

# Check if pattern was found
if [[ -n "$result" ]]; then
    # Pattern found
    status="pass"
    notes="[FOUND_MESSAGE]"
else
    # Pattern not found
    # Decide if this is pass or fail based on context:
    # - For optional features: pass (not finding them is OK)
    # - For required features: fail (should always be there)
    status="pass"  # Change to "fail" if this is required
    result="Not found"
    notes="[NOT_FOUND_MESSAGE]"
fi

# Output the result
output_html_result "[TEST_NAME]" "command | grep -i [PATTERN]" "$result" "$status" "$notes" "[TEST_ID]" "[CATEGORY]" "text"

# ============================================================================
# COMMON GREP PATTERNS:
# ============================================================================
# Case-insensitive search:     grep -i "pattern"
# Exact line match:            grep "^pattern\$"
# Search in file:              grep "pattern" /path/to/file
# Inverse search (NOT):        grep -v "pattern"
# Count occurrences:           grep -c "pattern"
# Show line numbers:           grep -n "pattern"
# Multiple patterns (OR):      grep -e "pattern1" -e "pattern2"
# 
# REMEMBER:
# - Always use || true after grep if you expect it might not find anything
# - This prevents the script from exiting with error
# - Example: result=$(mount | grep nfs || true)
