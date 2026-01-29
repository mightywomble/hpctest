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
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "Ethernet NICs" "lshw -C network -short" "$result" "pass" "" "ethernet-nics" "Ethernet Network" "text"
else
    output_html_result "Ethernet NICs" "lshw -C network -short" "$result" "fail" "lshw not available or no NICs" "ethernet-nics" "Ethernet Network" "text"
fi

# Test: Ethernet Links
result=$(ip -br a 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "Ethernet Links" "ip -br a" "$result" "pass" "" "ethernet-links" "Ethernet Network" "text"
else
    output_html_result "Ethernet Links" "ip -br a" "$result" "fail" "Unable to enumerate links" "ethernet-links" "Ethernet Network" "text"
fi

# Test: All IP Addresses (IPv4 & IPv6)
result=$(ip -o addr show primary scope global 2>&1 | awk '{print $2, $3, $4}')
if [[ -n "$result" ]]; then
    output_html_result "All IP Addresses (IPv4 & IPv6)" "ip -o addr show primary scope global" "$result" "pass" "" "ip-addresses" "Ethernet Network" "text"
else
    output_html_result "All IP Addresses (IPv4 & IPv6)" "ip -o addr show primary scope global" "No global scope addresses found" "pass" "(Not configured)" "ip-addresses" "Ethernet Network" "text"
fi

# Test: NIC Type per IPv4
result=$(nic_info_per_ipv4 2>&1)
if [[ -n "$result" ]]; then
    output_html_result "NIC Type per IPv4" "nic_info_per_ipv4" "$result" "pass" "" "nic-type" "Ethernet Network" "text"
else
    output_html_result "NIC Type per IPv4" "nic_info_per_ipv4" "No IPv4 interfaces found" "pass" "(Not configured)" "nic-type" "Ethernet Network" "text"
fi

# Test: Link Speed Check
check_link_speed() {
    local min=${MIN_LINK_SPEED_MBPS:-0}
    local overall_status="pass"
    local notes=""
    local lines=""
    mapfile -t ifaces < <(ip -o -4 addr show primary scope global | awk '{print $2}' | sort -u)
    
    if [[ ${#ifaces[@]} -eq 0 ]]; then
        lines="No IPv4 interfaces with global scope found"
        overall_status="pass"
        notes="(Not configured)"
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
    result=$(ethtool bond0 2>&1 | grep -i Speed || true)
    if [[ -n "$result" ]]; then
        output_html_result "Bond Speed" "ethtool bond0 | grep -i Speed" "$result" "pass" "" "bond-speed" "Ethernet Network" "text"
    else
        output_html_result "Bond Speed" "ethtool bond0 | grep -i Speed" "Speed not detected" "pass" "(Not available)" "bond-speed" "Ethernet Network" "text"
    fi
    result=$(cat /proc/net/bonding/bond0 2>&1 | grep 'Bonding Mode' || true)
    if [[ -n "$result" ]]; then
        output_html_result "Bond Type" "cat /proc/net/bonding/bond0 | grep 'Bonding Mode'" "$result" "pass" "" "bond-type" "Ethernet Network" "text"
    else
        output_html_result "Bond Type" "cat /proc/net/bonding/bond0 | grep 'Bonding Mode'" "Mode not detected" "pass" "(Not available)" "bond-type" "Ethernet Network" "text"
    fi
else
    output_html_result "Bond Speed" "ethtool bond0" "Device not found" "pass" "(Not present)" "bond-speed" "Ethernet Network" "text"
    output_html_result "Bond Type" "cat /proc/net/bonding/bond0" "Device not found" "pass" "(Not present)" "bond-type" "Ethernet Network" "text"
fi
