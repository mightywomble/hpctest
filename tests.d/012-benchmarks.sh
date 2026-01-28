#!/bin/bash

# ==============================================================================
# Test Script: Benchmarks
# Category: High-Performance Benchmarks
# Description: Docker-based HPL and GPU-burn benchmarks
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Check if benchmarks should be skipped based on flags
if should_skip_test "--noburn" "--noinstall"; then
    output_test_result "HPL Single Node" "N/A" "Skipped by flag" "partial" "--noburn/--noinstall"
    echo ","
    output_test_result "GPU Burn" "N/A" "Skipped by flag" "partial" "--noburn/--noinstall"
    finish_json_output
    exit 0
fi

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
    log_warn "Docker is not installed, but it is required for benchmark tests."
    
    # Check if we should auto-install Docker
    if $HEADLESS_MODE; then
        log_warn "--headless specified: attempting automatic Docker CE installation..."
        install_docker_ce() {
            apt-get update
            apt-get install -y ca-certificates curl gnupg
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        }
        
        if install_docker_ce; then
            log_success "Docker installed"
        else
            output_test_result "Benchmarks" "N/A" "Skipped due to failed Docker installation" "fail" "Docker installation failed"
            finish_json_output
            exit 0
        fi
    else
        output_test_result "HPL Single Node" "N/A" "Skipped - Docker not installed" "partial" "User did not install Docker"
        echo ","
        output_test_result "GPU Burn" "N/A" "Skipped - Docker not installed" "partial" "User did not install Docker"
        finish_json_output
        exit 0
    fi
fi

# Docker is available, proceed with benchmarks
log "Running Docker-based benchmarks..."

# Test: HPL Single Node
log "Running HPL benchmark..."
hpl_result=$(docker run --gpus all --rm --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 nvcr.io/nvidia/hpc-benchmarks:24.05 mpirun -np 8 --bind-to none --map-by ppr:8:node /hpl.sh --dat /hpl-linux-x86_64/sample-dat/HPL-dgx-h100-1N.dat 2>&1)
hpl_status="pass"
if [[ -z "$hpl_result" ]]; then
    hpl_status="partial"
    hpl_result="No output received"
fi
output_test_result "HPL Single Node" "docker run ... hpl.sh" "$hpl_result" "$hpl_status" ""
echo ","

# Test: GPU Burn
log "Running GPU Burn benchmark..."
gpuburn_result=$(docker run --rm --gpus all oguzpastirmaci/gpu-burn:latest 2>&1)
gpuburn_status="pass"
if [[ -z "$gpuburn_result" ]]; then
    gpuburn_status="partial"
    gpuburn_result="No output received"
fi
output_test_result "GPU Burn" "docker run ... gpu-burn" "$gpuburn_result" "$gpuburn_status" ""

finish_json_output
