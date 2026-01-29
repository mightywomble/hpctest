#!/bin/bash

# ==============================================================================
# Test Script: [TEST_NAME]
# Category: [CATEGORY]
# Description: [DESCRIPTION]
# ==============================================================================
#
# This template is for testing optional/not-required features.
# Use this when:
# - Testing for presence of optional software (GPU, InfiniBand)
# - Absence of the feature is normal and expected
# - You need to distinguish: "not installed" vs "installed but broken"
#
# Examples of tests that use this pattern:
# - GPU detection (nvidia-smi)
# - InfiniBand stack (ibstatus, ofed_info)
# - Optional packages (speedtest-cli)
# - Optional services
#
# KEY PRINCIPLE: If a feature is optional, absence = PASS, not FAIL
#

source "$(dirname "$0")/../config.sh"

# Check if the command/tool exists
if command -v [COMMAND] &>/dev/null; then
    # Tool is installed, now try to use it
    result=$([COMMAND] [ARGS] 2>&1)
    exit_code=$?
    
    if [[ $exit_code -eq 0 && -n "$result" ]]; then
        # Tool exists and works correctly
        status="pass"
        notes="Feature installed and working"
    else
        # Tool exists but failed - this is a real failure
        status="fail"
        notes="Tool installed but failed with exit code $exit_code"
    fi
else
    # Tool is not installed
    # For optional features, this is NOT a failure
    status="pass"
    result="Not installed"
    notes="(Optional feature not present)"
fi

# Output the result
output_html_result "[TEST_NAME]" "[COMMAND]" "$result" "$status" "$notes" "[TEST_ID]" "[CATEGORY]" "text"

# ============================================================================
# IMPORTANT: Understanding Optional vs Required
# ============================================================================
# OPTIONAL FEATURE (like GPU):
#   - Not installed → PASS (that's fine, not required)
#   - Installed but broken → FAIL (should work if present)
#   - Working → PASS
#
# REQUIRED FEATURE (like lsblk for storage):
#   - Not installed → FAIL (should always be available)
#   - Installed but broken → FAIL
#   - Working → PASS
#
# Determine if a feature is optional by asking:
# "Is it OK if this is not present on the system?"
# - GPU: YES (many systems don't have GPU)
# - InfiniBand: YES (not required on all systems)
# - /etc/hostname: NO (always required)
# - free command: NO (always required)
