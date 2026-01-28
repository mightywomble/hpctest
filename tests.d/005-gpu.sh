#!/bin/bash

# ==============================================================================
# Test Script: GPU Information
# Category: GPU
# Description: GPU type, VRAM, NVIDIA drivers, and NVLink status
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Test: GPU Type
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes="NVIDIA GPU detection"
output_test_result "GPU Type" "nvidia-smi --query-gpu=gpu_name --format=csv,noheader" "$result" "$status" "$notes"
echo ","

# Test: VRAM per GPU
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi --query-gpu=memory.total --format=csv 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes=""
output_test_result "VRAM per GPU" "nvidia-smi --query-gpu=memory.total --format=csv" "$result" "$status" "$notes"
echo ","

# Test: NVIDIA Peermem
if command -v lsmod &>/dev/null; then
    result=$(lsmod | grep -i nvidia_peermem 2>&1)
    if [[ -z "$result" ]]; then
        result="nvidia_peermem module not loaded"
        status="partial"
    else
        status="pass"
    fi
else
    result="lsmod command not available"
    status="partial"
fi
notes=""
output_test_result "NVIDIA Peermem" "lsmod | grep -i nvidia_peermem" "$result" "$status" "$notes"
echo ","

# Test: NVLink Fabric Manager
if command -v nv-fabricmanager &>/dev/null; then
    result=$(nv-fabricmanager --version 2>&1)
    status="pass"
else
    result="nv-fabricmanager command not found"
    status="partial"
fi
notes="NVIDIA Fabric Manager for NVLink"
output_test_result "NVLink Fabric Manager" "nv-fabricmanager --version" "$result" "$status" "$notes"
echo ","

# Test: NVLink Status
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi nvlink -s 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes=""
output_test_result "NVLink Status" "nvidia-smi nvlink -s" "$result" "$status" "$notes"
echo ","

# Test: Driver Version
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi | grep -i 'Driver Version' 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes=""
output_test_result "Driver Version" "nvidia-smi | grep -i 'Driver Version'" "$result" "$status" "$notes"
echo ","

# Test: nvidia-smi Full Output (as collapsible)
if command -v nvidia-smi &>/dev/null; then
    nsmi=$(nvidia-smi 2>&1)
    nsmi_html="{\"output\": \"$(printf '%s\n' "$nsmi" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/ /g')\"}"
    output_test_result_html "nvidia-smi Full Output" "nvidia-smi" "$nsmi_html" "pass" ""
else
    output_test_result "nvidia-smi Full Output" "nvidia-smi" "nvidia-smi not installed" "partial" "Install NVIDIA drivers"
fi

finish_json_output
