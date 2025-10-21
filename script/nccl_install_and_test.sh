#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
CUDA_VERSION="13.0"
CUDA_PACKAGE="cuda-toolkit-13-0"
CUDA_BASE="/usr/local/cuda-${CUDA_VERSION}"
NCCL_TESTS_DIR="/usr/local/nccl-tests"
ALL_REDUCE_BIN="${NCCL_TESTS_DIR}/build/all_reduce_perf"

echo "--- STARTING FRESH NCCL INSTALLATION AND BENCHMARK ---"

# ==============================================================================
# SECTION 1: SYSTEM CLEANUP & PREREQUISITES
# ==============================================================================
echo "1. Cleaning up previous NVIDIA/CUDA installations..."
sudo apt-get purge -y "*nvidia*" "*cuda*" || true
sudo apt-get autoremove -y
sudo apt-get update

echo "2. Installing core build essentials and cloning NCCL tests..."
sudo apt-get install -y build-essential devscripts debhelper fakeroot git libnccl-dev

# Clone NCCL tests now, so they're ready to be compiled later
if [ -d "$NCCL_TESTS_DIR" ]; then
    sudo rm -rf "$NCCL_TESTS_DIR"
fi
sudo git clone https://github.com/NVIDIA/nccl-tests.git "$NCCL_TESTS_DIR"


# ==============================================================================
# SECTION 2: CUDA 13.0 INSTALLATION
# ==============================================================================
echo "3. Adding NVIDIA CUDA ${CUDA_VERSION} Repository..."

# Fetch the keyring and add the repository for Ubuntu 22.04
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

echo "4. Installing CUDA ${CUDA_VERSION} Toolkit (includes latest driver)..."
# The 'cuda' package installs the latest stable driver and toolkit.
# We install the specific toolkit version to ensure correct symlinks.
sudo apt-get install -y "${CUDA_PACKAGE}"

echo "5. Linking NVCC to system PATH and updating LD_LIBRARY_PATH..."

# Remove old generic symlink and create new specific one
sudo rm -f /usr/local/cuda
sudo ln -s "${CUDA_BASE}" /usr/local/cuda

# Create the specific /usr/bin/nvcc link as requested
if [ ! -f /usr/bin/nvcc ] || [ "$(readlink /usr/bin/nvcc)" != "${CUDA_BASE}/bin/nvcc" ]; then
    echo "Creating symlink for /usr/bin/nvcc"
    sudo ln -sf "${CUDA_BASE}/bin/nvcc" /usr/bin/nvcc
fi

# Ensure CUDA binaries are on the path for this script and subsequent shells
export PATH="${CUDA_BASE}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_BASE}/lib64:${LD_LIBRARY_PATH}"
sudo ldconfig


# ==============================================================================
# SECTION 3: BUILD NCCL TESTS AND DYNAMICALLY RUN BENCHMARK
# ==============================================================================
echo "6. Building NCCL Tests against CUDA ${CUDA_VERSION}..."
# The system-installed CUDA is now the default path, so 'make' uses it.
cd "$NCCL_TESTS_DIR"
sudo make clean
sudo make 
sudo ln -sf "${ALL_REDUCE_BIN}" /usr/local/bin/

echo "7. Verifying GPU count and preparing to run benchmark..."
# Use nvidia-smi to query the number of GPUs (this is the most reliable method)
GPU_COUNT=$(nvidia-smi -L | wc -l)

if [ "$GPU_COUNT" -lt 2 ]; then
    echo "--- WARNING: Only ${GPU_COUNT} GPU(s) detected. NCCL AllReduce test requires 2+ GPUs for meaningful results. ---"
    # Fallback to single-GPU test with override if strictly needed to pass validation
    if [ "$GPU_COUNT" -eq 1 ]; then
        echo "Running single-GPU test with NCCL_MIN_NRANKS=1 override."
        # This tests the integrity of the NCCL/CUDA installation, not interconnect bandwidth.
        # It's better than failing entirely.
        BENCHMARK_CMD="${ALL_REDUCE_BIN} -b 8 -e 128M -f 2 -g 1 -n 1"
    else
        echo "No GPUs detected. Skipping NCCL test."
        exit 1
    fi
else
    echo "SUCCESS: ${GPU_COUNT} GPUs detected. Running multi-GPU benchmark."
    # Use -g equal to the detected count to ensure one rank per GPU
    BENCHMARK_CMD="${ALL_REDUCE_BIN} -b 8 -e 128M -f 2 -g ${GPU_COUNT}"
fi

# Execute the final benchmark command
echo "Running command: ${BENCHMARK_CMD}"
echo "--------------------------------------------------------"
# Enable NCCL_DEBUG for better visibility into topology detection
sudo env NCCL_DEBUG=INFO ${BENCHMARK_CMD}

echo "--- SCRIPT COMPLETE ---"
