#!/bin/bash

# ==============================================================================
# Test Script: InfiniBand Network
# Category: InfiniBand Network
# Description: InfiniBand status, OFED drivers, and fabric information
# ==============================================================================

source "$(dirname "$0")/../config.sh"
echo "[RUNNING] InfiniBand Network tests"

# Test: IB Links Speed
result=$(ibstatus 2>&1 | grep -e 'rate:' -e 'device' || true)
if [[ -n "$result" ]]; then
    output_html_result "IB Links Speed" "ibstatus | grep -e 'rate:' -e 'device'" "$result" "pass" "" "ib-links-speed" "InfiniBand Network" "text"
else
    output_html_result "IB Links Speed" "ibstatus | grep -e 'rate:' -e 'device'" "InfiniBand not detected" "pass" "(Not present)" "ib-links-speed" "InfiniBand Network" "text"
fi

# Test: IB Links Status
result=$(ibstatus 2>&1 | grep -e 'link_layer:' -e 'phys state:' || true)
if [[ -n "$result" ]]; then
    output_html_result "IB Links Status" "ibstatus | grep -e 'link_layer:' -e 'phys state:'" "$result" "pass" "" "ib-links-status" "InfiniBand Network" "text"
else
    output_html_result "IB Links Status" "ibstatus | grep -e 'link_layer:' -e 'phys state:'" "InfiniBand not detected" "pass" "(Not present)" "ib-links-status" "InfiniBand Network" "text"
fi

# Test: OFED Version
result=$(ofed_info -s 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "OFED Version" "ofed_info -s" "$result" "pass" "" "ofed-version" "InfiniBand Network" "text"
else
    output_html_result "OFED Version" "ofed_info -s" "OFED not installed" "pass" "(Not present)" "ofed-version" "InfiniBand Network" "text"
fi

# Test: IBoIP Enabled
result=$(ibdev2netdev 2>&1 || true)
if [[ -n "$result" ]]; then
    output_html_result "IBoIP Enabled" "ibdev2netdev" "$result" "pass" "" "iboip-enabled" "InfiniBand Network" "text"
else
    output_html_result "IBoIP Enabled" "ibdev2netdev" "No IB devices found" "pass" "(Not present)" "iboip-enabled" "InfiniBand Network" "text"
fi

# Test: IB Fabric
result=$(iblinkinfo --switches-only 2>&1 || true)
if [[ -n "$result" ]]; then
    output_html_result "IB Fabric" "iblinkinfo --switches-only" "$result" "pass" "" "ib-fabric" "InfiniBand Network" "text"
else
    output_html_result "IB Fabric" "iblinkinfo --switches-only" "No switches detected" "pass" "(Not present)" "ib-fabric" "InfiniBand Network" "text"
fi
