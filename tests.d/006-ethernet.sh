#!/bin/bash

# ==============================================================================
# Test Script: Ethernet Network
# Category: Ethernet Network
# Description: Network interfaces, IP addresses, link speeds, bonding
# ==============================================================================

source "$(dirname "$0")/../config.sh"
echo "[RUNNING] Ethernet Network tests"

# Test: Ethernet NICs
result=$(lshw -C network -short 2>&1)
status="pass"
notes=""
output_html_result "Ethernet NICs" "lshw -C network -short" "$result" "$status" "$notes" "ethernet-nics" "Ethernet Network" "text"

# Test: Ethernet Links
result=$(ip -br a 2>&1)
status="pass"
notes=""
output_html_result "Ethernet Links" "ip -br a" "$result" "$status" "$notes" "ethernet-links" "Ethernet Network" "text"

# Test: All IP Addresses (IPv4 & IPv6)
result=$(ip -o addr show primary scope global | awk '{print $2, $3, $4}' 2>&1)
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="No global scope addresses found"
fi
output_html_result "All IP Addresses (IPv4 & IPv6)" "ip -o addr show primary scope global" "$result" "$status" "$notes" "ip-addresses" "Ethernet Network" "text"

# Test: NIC Type per IPv4
result=$(nic_info_per_ipv4 2>&1)
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="No IPv4 interfaces found"
fi
output_html_result "NIC Type per IPv4" "nic_info_per_ipv4" "$result" "$status" "$notes" "nic-type" "Ethernet Network" "text"

# Test: Link Speed Check
check_link_speed() {
    local min=${MIN_LINK_SPEED_MBPS:-0}
    local overall_status="pass"
    local notes=""
    local lines=""
    mapfile -t ifaces < <(ip -o -4 addr show primary scope global | awk '{print $2}' | sort -u)
    
    if [[ ${#ifaces[@]} -eq 0 ]]; then
        lines="No IPv4 interfaces with global scope found"
        overall_status="partial"
        notes="No interfaces"
    else
        for iface in "${ifaces[@]}"; do
            local raw
            raw=$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Speed/{print $2}')
            local spd
            spd=$(echo "$raw" | sed -E 's/[^0-9.]+//g')
            local entry
            if [[ -z "$spd" ]]; then
                entry="$iface speed=unknown"
                if (( min > 0 )); then overall_status="fail"; fi
            else
                entry="$iface speed=${spd}Mb/s"
                if (( min > 0 )) && (( ${spd%.*} < min )); then
                    overall_status="fail"
                    entry+=" (below ${min}Mb/s)"
                fi
            fi
            lines+="$entry"$'\n'
        done
        if (( min == 0 )) && [[ "$overall_status" == "pass" ]]; then
            notes="No minimum threshold configured"
        else
            notes="Minimum: ${min} Mb/s"
        fi
    fi
    output_html_result "Link Speed Check (>= ${MIN_LINK_SPEED_MBPS} Mb/s)" "ethtool <each iface>" "$lines" "$overall_status" "$notes" "link-speed" "Ethernet Network" "text"
}
check_link_speed

# Test: Bond Speed (if bond0 exists)
if ip link show bond0 > /dev/null 2>&1; then
    result=$(ethtool bond0 | grep -i Speed 2>&1)
    status="pass"
    notes=""
    output_html_result "Bond Speed" "ethtool bond0 | grep -i Speed" "$result" "$status" "$notes" "bond-speed" "Ethernet Network" "text"
    result=$(cat /proc/net/bonding/bond0 | grep 'Bonding Mode' 2>&1)
    status="pass"
    output_html_result "Bond Type" "cat /proc/net/bonding/bond0 | grep 'Bonding Mode'" "$result" "$status" "$notes" "bond-type" "Ethernet Network" "text"
else
    output_html_result "Bond Speed" "ethtool bond0" "Device not found" "partial" "bond0 not present" "bond-speed" "Ethernet Network" "text"
    output_html_result "Bond Type" "cat /proc/net/bonding/bond0" "Device not found" "partial" "bond0 not present" "bond-type" "Ethernet Network" "text"
fi
