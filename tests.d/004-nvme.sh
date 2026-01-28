#!/bin/bash

# ==============================================================================
# Test Script: NVMe Storage
# Category: NVMe Storage
# Description: Block devices, lsblk overview, and filesystem usage
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Test: Block Devices
result=$(lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS 2>&1)
status="pass"
notes=""
output_test_result "Block Devices" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$result" "$status" "$notes"
echo ","

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

# Create chips HTML for disk list
chips_html="{\"disks\": ["
first=true
while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        if [[ "$first" == true ]]; then
            first=false
        else
            chips_html+=","
        fi
        chips_html+="{\"name\": \"$line\"}"
    fi
done <<< "$disks_list"
chips_html+="], \"lsblk\": \"$(printf '%s\n' "$lsblk_out" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/ /g')\"}"

output_test_result_html "lsblk Overview" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$chips_html" "$disk_status" "$disk_note"
echo ","

# Test: Filesystem Usage
result=$(df -h 2>&1)
status="pass"
notes=""
output_test_result "Filesystem Usage" "df -h" "$result" "$status" "$notes"

finish_json_output
