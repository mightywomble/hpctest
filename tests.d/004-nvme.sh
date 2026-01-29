#!/bin/bash

# ==============================================================================
# Test Script: NVMe Storage
# Category: NVMe Storage
# Description: Block devices, lsblk overview, and filesystem usage
# ==============================================================================

source "$(dirname "$0")/../config.sh"
echo "[RUNNING] NVMe Storage tests"

# Test: Block Devices
result=$(lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "Block Devices" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$result" "pass" "" "block-devices" "NVMe Storage" "text"
else
    output_html_result "Block Devices" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$result" "fail" "Unable to enumerate block devices" "block-devices" "NVMe Storage" "text"
fi

# Test: lsblk Overview with disk chips
lsblk_out=$(lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$lsblk_out" ]]; then
    output_html_result "lsblk Overview" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$lsblk_out" "pass" "" "lsblk-overview" "NVMe Storage" "text"
else
    output_html_result "lsblk Overview" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$lsblk_out" "fail" "Unable to enumerate lsblk" "lsblk-overview" "NVMe Storage" "text"
fi

# Test: Filesystem Usage
result=$(df -h 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "Filesystem Usage" "df -h" "$result" "pass" "" "filesystem-usage" "NVMe Storage" "text"
else
    output_html_result "Filesystem Usage" "df -h" "$result" "fail" "Unable to determine filesystem usage" "filesystem-usage" "NVMe Storage" "text"
fi
