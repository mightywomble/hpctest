#!/bin/bash

# ==============================================================================
# Test Script: InfiniBand Network
# Category: InfiniBand Network
# Description: InfiniBand status, OFED drivers, and fabric information
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Test: IB Links Speed
if command -v ibstatus &>/dev/null; then
    result=$(ibstatus 2>&1 | grep -e 'rate:' -e 'device')
    status="pass"
else
    result="ibstatus command not found"
    status="partial"
fi
notes=""
output_test_result "IB Links Speed" "ibstatus | grep -e 'rate:' -e 'device'" "$result" "$status" "$notes"
echo ","

# Test: IB Links Status
if command -v ibstatus &>/dev/null; then
    result=$(ibstatus 2>&1 | grep -e 'link_layer:' -e 'phys state:')
    status="pass"
else
    result="ibstatus command not found"
    status="partial"
fi
notes=""
output_test_result "IB Links Status" "ibstatus | grep -e 'link_layer:' -e 'phys state:'" "$result" "$status" "$notes"
echo ","

# Test: OFED Version
if command -v ofed_info &>/dev/null; then
    result=$(ofed_info -s 2>&1)
    status="pass"
else
    result="ofed_info command not found"
    status="partial"
fi
notes=""
output_test_result "OFED Version" "ofed_info -s" "$result" "$status" "$notes"
echo ","

# Test: IBoIP Enabled
if command -v ibdev2netdev &>/dev/null; then
    result=$(ibdev2netdev 2>&1)
    status="pass"
else
    result="ibdev2netdev command not found"
    status="partial"
fi
notes=""
output_test_result "IBoIP Enabled" "ibdev2netdev" "$result" "$status" "$notes"
echo ","

# Test: IB Fabric
if command -v iblinkinfo &>/dev/null; then
    result=$(iblinkinfo --switches-only 2>&1)
    status="pass"
else
    result="iblinkinfo command not found"
    status="partial"
fi
notes=""
output_test_result "IB Fabric" "iblinkinfo --switches-only" "$result" "$status" "$notes"

finish_json_output
