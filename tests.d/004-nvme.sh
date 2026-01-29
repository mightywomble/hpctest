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
status="pass"
notes=""
output_html_result "Block Devices" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$result" "$status" "$notes" "block-devices" "NVMe Storage" "text"

# Test: lsblk Overview with disk chips
disks_list=$(lsblk -dn -o NAME,SIZE,MODEL,TYPE 2>/dev/null | awk '$4=="disk" {print $1" ("$2") "$3}')
if [[ -n "$disks_list" ]]; then
    disk_status="pass"
    disk_note="Disks highlighted"
else
    disk_status="fail"
    disk_note="No disks detected"
fi

lsblk_out=$(lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS 2>&1)
output_html_result "lsblk Overview" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$lsblk_out" "$disk_status" "$disk_note" "lsblk-overview" "NVMe Storage" "text"

# Test: Filesystem Usage
result=$(df -h 2>&1)
status="pass"
notes=""
output_html_result "Filesystem Usage" "df -h" "$result" "$status" "$notes" "filesystem-usage" "NVMe Storage" "text"
