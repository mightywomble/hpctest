#!/bin/bash

# ==============================================================================
# Test Script: GPU Information
# Category: GPU
# Description: GPU type, VRAM, NVIDIA drivers, and NVLink status
# ==============================================================================

source "$(dirname "$0")/../config.sh"
echo "[RUNNING] GPU tests"

# Test: GPU Type
result=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "GPU Type" "nvidia-smi --query-gpu=gpu_name --format=csv,noheader" "$result" "pass" "" "gpu-type" "GPU" "text"
else
    output_html_result "GPU Type" "nvidia-smi --query-gpu=gpu_name --format=csv,noheader" "No NVIDIA GPU detected" "pass" "(Not present)" "gpu-type" "GPU" "text"
fi

# Test: VRAM per GPU
result=$(nvidia-smi --query-gpu=memory.total --format=csv 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "VRAM per GPU" "nvidia-smi --query-gpu=memory.total --format=csv" "$result" "pass" "" "gpu-vram" "GPU" "numeric"
else
    output_html_result "VRAM per GPU" "nvidia-smi --query-gpu=memory.total --format=csv" "No NVIDIA GPU detected" "pass" "(Not present)" "gpu-vram" "GPU" "numeric"
fi

# Test: NVIDIA Peermem
result=$(lsmod 2>&1 | grep -i nvidia_peermem || true)
if [[ -n "$result" ]]; then
    output_html_result "NVIDIA Peermem" "lsmod | grep -i nvidia_peermem" "$result" "pass" "" "nvidia-peermem" "GPU" "text"
else
    output_html_result "NVIDIA Peermem" "lsmod | grep -i nvidia_peermem" "nvidia_peermem module not loaded" "pass" "(Not present)" "nvidia-peermem" "GPU" "text"
fi

# Test: NVLink Fabric Manager
result=$(nv-fabricmanager --version 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "NVLink Fabric Manager" "nv-fabricmanager --version" "$result" "pass" "" "nvlink-fm" "GPU" "text"
else
    output_html_result "NVLink Fabric Manager" "nv-fabricmanager --version" "Not installed" "pass" "(Not present)" "nvlink-fm" "GPU" "text"
fi

# Test: NVLink Status
result=$(nvidia-smi nvlink -s 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$result" ]]; then
    output_html_result "NVLink Status" "nvidia-smi nvlink -s" "$result" "pass" "" "nvlink-status" "GPU" "text"
else
    output_html_result "NVLink Status" "nvidia-smi nvlink -s" "No NVLink detected" "pass" "(Not present)" "nvlink-status" "GPU" "text"
fi

# Test: Driver Version
result=$(nvidia-smi 2>&1 | grep -i 'Driver Version' || true)
if [[ -n "$result" ]]; then
    output_html_result "Driver Version" "nvidia-smi | grep -i 'Driver Version'" "$result" "pass" "" "driver-version" "GPU" "text"
else
    output_html_result "Driver Version" "nvidia-smi | grep -i 'Driver Version'" "No driver installed" "pass" "(Not present)" "driver-version" "GPU" "text"
fi

# Test: nvidia-smi Full Output
nsmi=$(nvidia-smi 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 && -n "$nsmi" ]]; then
    output_html_result "nvidia-smi Full Output" "nvidia-smi" "$nsmi" "pass" "" "nvidia-smi-output" "GPU" "text"
else
    output_html_result "nvidia-smi Full Output" "nvidia-smi" "NVIDIA tools not installed" "pass" "(Not present)" "nvidia-smi-output" "GPU" "text"
fi
