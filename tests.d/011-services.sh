#!/bin/bash

# ==============================================================================
# Test Script: Services & Mounts
# Category: Services & Mounts
# Description: System services and mount point tests
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Test: SSH Access
if command -v systemctl &>/dev/null; then
    result=$(systemctl status sshd 2>&1 | grep 'Active:' | sed 's/^[ \t]*//')
    status="pass"
else
    result=$(service sshd status 2>&1)
    status="pass"
fi
notes=""
output_test_result "SSH Access" "systemctl status sshd | grep 'Active:' | sed 's/^[ \\t]*//'" "$result" "$status" "$notes"
echo ","

# Test: IPMI Access
if command -v ipmitool &>/dev/null; then
    result=$(ipmitool lan print 2>&1)
    status="pass"
    notes=""
else
    result="ipmitool command not found"
    status="partial"
    notes="Install ipmitool to enable IPMI access checks"
fi
output_test_result "IPMI Access" "ipmitool lan print" "$result" "$status" "$notes"
echo ","

# Test: NFS Mounts
result=$(mount 2>&1 | grep nfs)
if [[ -z "$result" ]]; then
    result="No NFS mounts detected"
    status="pass"
    notes="System has no NFS mounts"
else
    status="pass"
    notes="NFS mounts found"
fi
output_test_result "NFS Mounts" "mount | grep nfs" "$result" "$status" "$notes"

finish_json_output
