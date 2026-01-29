#!/bin/bash

# ==============================================================================
# Test Script: [TEST_NAME]
# Category: [CATEGORY]
# Description: [DESCRIPTION]
# ==============================================================================
#
# This template tests values against minimum/maximum thresholds.
# Use this when:
# - Checking network link speed meets minimum
# - Verifying available disk space
# - Validating network bandwidth
# - Confirming memory or CPU capacity
#
# Examples of tests that use this pattern:
# - Ethernet link speed >= 10Gbps
# - Available disk >= 100GB
# - Memory capacity >= 256GB
# - Network bandwidth meets SLA
#

source "$(dirname "$$0")/../config.sh"

# Extract the value from command output
# Example: get memory size in GB
raw_output=$(command 2>&1)
value=$(echo "$raw_output" | sed -E 's/[^0-9.]+//g')

# Define thresholds (adjust based on your needs)
min_threshold=[MIN_VALUE]
max_threshold=[MAX_VALUE]

# Initialize result
status="pass"
notes=""
result="$value [UNITS]"

# Check against minimum threshold
if (( ${value%.*} < min_threshold )); then
    status="fail"
    notes="Below minimum threshold: $value < $min_threshold"
fi

# Check against maximum threshold (if applicable)
if (( ${value%.*} > max_threshold )); then
    status="fail"
    notes="Above maximum threshold: $value > $max_threshold"
fi

# Output the result
output_html_result "[TEST_NAME]" "command" "$result" "$status" "$notes" "[TEST_ID]" "[CATEGORY]" "numeric"

# ============================================================================
# IMPORTANT NOTES ON NUMBER EXTRACTION:
# ============================================================================
# Bash arithmetic only works with integers, so:
# - Use ${var%.*} to get integer part: 123.456 → 123
# - Or use bc for decimal math: (( $(echo "$value > 100" | bc) ))
#
# Common extraction patterns:
#   value=$(echo "123GB" | grep -o -E '[0-9]+' | head -1)
#   value=$(free -h | grep Mem: | awk '{print $2}' | grep -o -E '[0-9]+')
#   value=$(ethtool eth0 | grep Speed | grep -o -E '[0-9]+')
#
# Number comparison in bash:
#   (( $value < 100 ))    # Less than
#   (( $value > 100 ))    # Greater than
#   (( $value == 100 ))   # Equals
#   (( $value != 100 ))   # Not equals
#   (( $value <= 100 ))   # Less than or equal
#   (( $value >= 100 ))   # Greater than or equal
