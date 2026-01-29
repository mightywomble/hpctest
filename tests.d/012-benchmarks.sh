#!/bin/bash

# ==============================================================================
# Test Script: Benchmarks
# Category: High-Performance Benchmarks
# Description: Docker-based HPL and GPU-burn benchmarks
# ==============================================================================

source "$(dirname "$0")/../config.sh"

# Check if benchmarks should be skipped based on flags
if should_skip_test "--noburn" "--noinstall"; then
    output_html_result "HPL Single Node" "N/A" "Skipped by flag" "partial" "--noburn/--noinstall" "hpl-single" "High-Performance Benchmarks" "numeric"
    output_html_result "GPU Burn" "N/A" "Skipped by flag" "partial" "--noburn/--noinstall" "gpu-burn" "High-Performance Benchmarks" "numeric"
    exit 0
fi

# Redirect log messages to stderr so they don't interfere with test output
exec 3>&1  # Save stdout
exec 1>&2  # Redirect stdout to stderr for this script

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
    log_warn "Docker is not installed, but it is required for benchmark tests."
    
    # Check if we should auto-install Docker
    if $HEADLESS_MODE; then
        log_warn "--headless specified: attempting automatic Docker CE installation..."
        install_docker_ce() {
            apt-get update >/dev/null 2>&1
            apt-get install -y ca-certificates curl gnupg >/dev/null 2>&1
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update >/dev/null 2>&1
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
        }
        
        if install_docker_ce; then
            log_success "Docker installed"
        else
            exec 1>&3  # Restore stdout
            output_html_result "HPL Single Node" "N/A" "Skipped due to failed Docker installation" "fail" "Docker installation failed" "hpl-single" "High-Performance Benchmarks" "numeric"
            output_html_result "GPU Burn" "N/A" "Skipped due to failed Docker installation" "fail" "Docker installation failed" "gpu-burn" "High-Performance Benchmarks" "numeric"
            exit 0
        fi
    else
        exec 1>&3  # Restore stdout
        output_html_result "HPL Single Node" "N/A" "Skipped - Docker not installed" "partial" "User did not install Docker" "hpl-single" "High-Performance Benchmarks" "numeric"
        output_html_result "GPU Burn" "N/A" "Skipped - Docker not installed" "partial" "User did not install Docker" "gpu-burn" "High-Performance Benchmarks" "numeric"
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

exec 1>&3  # Restore stdout
output_html_result "HPL Single Node" "docker run ... hpl.sh" "$hpl_result" "$hpl_status" "" "hpl-single" "High-Performance Benchmarks" "numeric"
exec 1>&2  # Redirect back to stderr

# Test: GPU Burn
log "Running GPU Burn benchmark..."
gpuburn_result=$(docker run --rm --gpus all oguzpastirmaci/gpu-burn:latest 2>&1)
gpuburn_status="pass"
if [[ -z "$gpuburn_result" ]]; then
    gpuburn_status="partial"
    gpuburn_result="No output received"
fi

exec 1>&3  # Restore stdout
output_html_result "GPU Burn" "docker run ... gpu-burn" "$gpuburn_result" "$gpuburn_status" "" "gpu-burn" "High-Performance Benchmarks" "numeric"
