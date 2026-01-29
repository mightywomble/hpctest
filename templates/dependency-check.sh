#!/bin/bash

# ==============================================================================
# Test Script: [TEST_NAME]
# Category: [CATEGORY]
# Description: [DESCRIPTION]
# ==============================================================================
#
# This template tests for presence of required tools/packages.
# Use this when:
# - Checking if required commands are installed
# - Verifying package availability
# - Validating library presence
# - Checking for required utilities
#
# Examples of tests that use this pattern:
# - Check for lshw command
# - Verify jq is installed
# - Check for ethtool
# - Verify git availability
#

source "$(dirname "$0")/../config.sh"

# Array of required commands to check
required_commands=([COMMAND_1] [COMMAND_2] [COMMAND_3])
missing_commands=()

# Check each command
for cmd in "${required_commands[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        # Command found
        result="$cmd found"
        status="pass"
    else
        # Command not found
        missing_commands+=("$cmd")
        status="fail"
        result="$cmd not installed"
    fi
done

# Determine overall status
if [[ ${#missing_commands[@]} -eq 0 ]]; then
    # All commands present
    status="pass"
    result="All required commands installed"
    notes=""
else
    # Some commands missing
    status="fail"
    result="Missing: ${missing_commands[*]}"
    notes="Install with: apt install [PACKAGE_NAME]"
fi

# Output the result
output_html_result "[TEST_NAME]" "command -v [COMMANDS]" "$result" "$status" "$notes" "[TEST_ID]" "[CATEGORY]" "text"

# ============================================================================
# UNDERSTANDING THE DIFFERENCE:
# ============================================================================
# REQUIRED COMMANDS (failure if missing):
# - Commands that should always be present on the system
# - Examples: lshw, free, ls, grep, awk
# - Status: fail if not present
#
# OPTIONAL COMMANDS (pass if missing):
# - Commands that may not be needed on all systems
# - Examples: nvidia-smi, ibstatus, speedtest-cli
# - Status: pass if not present (use optional-feature.sh template)
#
# When deciding if dependency is required or optional:
# - Required: "Should this always work?"
# - Optional: "Is it OK if this isn't available?"
#
# For required dependencies, use this template.
# For optional features, use optional-feature.sh template.
