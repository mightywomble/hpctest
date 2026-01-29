#!/bin/bash

# ==============================================================================
# Test Script: GPU Information
# Category: GPU
# Description: GPU type, VRAM, NVIDIA drivers, and NVLink status
# ==============================================================================

source "$(dirname "$0")/../config.sh"

# Test: GPU Type
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes="NVIDIA GPU detection"
output_html_result "GPU Type" "nvidia-smi --query-gpu=gpu_name --format=csv,noheader" "$result" "$status" "$notes" "gpu-type" "GPU" "text"

# Test: VRAM per GPU
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi --query-gpu=memory.total --format=csv 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes=""
output_html_result "VRAM per GPU" "nvidia-smi --query-gpu=memory.total --format=csv" "$result" "$status" "$notes" "gpu-vram" "GPU" "numeric"

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
output_html_result "NVIDIA Peermem" "lsmod | grep -i nvidia_peermem" "$result" "$status" "$notes" "nvidia-peermem" "GPU" "text"

# Test: NVLink Fabric Manager
if command -v nv-fabricmanager &>/dev/null; then
    result=$(nv-fabricmanager --version 2>&1)
    status="pass"
else
    result="nv-fabricmanager command not found"
    status="partial"
fi
notes="NVIDIA Fabric Manager for NVLink"
output_html_result "NVLink Fabric Manager" "nv-fabricmanager --version" "$result" "$status" "$notes" "nvlink-fm" "GPU" "text"

# Test: NVLink Status
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi nvlink -s 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes=""
output_html_result "NVLink Status" "nvidia-smi nvlink -s" "$result" "$status" "$notes" "nvlink-status" "GPU" "text"

# Test: Driver Version
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi | grep -i 'Driver Version' 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes=""
output_html_result "Driver Version" "nvidia-smi | grep -i 'Driver Version'" "$result" "$status" "$notes" "driver-version" "GPU" "text"

# Test: nvidia-smi Full Output
if command -v nvidia-smi &>/dev/null; then
    nsmi=$(nvidia-smi 2>&1)
    output_html_result "nvidia-smi Full Output" "nvidia-smi" "$nsmi" "pass" "" "nvidia-smi-output" "GPU" "text"
else
    output_html_result "nvidia-smi Full Output" "nvidia-smi" "nvidia-smi not installed" "partial" "Install NVIDIA drivers" "nvidia-smi-output" "GPU" "text"
fi
