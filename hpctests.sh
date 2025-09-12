#!/bin/bash

# ==============================================================================
#
# System Hardware & Performance Test Script
#
# Description:
#   This script automates a series of system checks, providing verbose
#   real-time feedback. The results are compiled into a single, self-contained,
#   and styled HTML report file.
#
# Usage:
#   - Standard run (interactive):
#     'sudo ./system_tests.sh'
#   - Automated run (skips all checks and prompts):
#     'sudo ./system_tests.sh --nocheck'
#
# ==============================================================================

# --- Globals and Configuration ---
readonly SCRIPT_NAME=$(basename "$0")
readonly TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
readonly FILENAME_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
readonly OUTPUT_FILE="system_test_report_${FILENAME_TIMESTAMP}.html"
NOCHECK_MODE=false # This flag will be set to true if --nocheck is passed

# --- Color Codes for Verbose Console Output ---
readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'

# ==============================================================================
# Helper Functions
# ==============================================================================

log() {
    echo -e "${C_CYAN}[$(date +"%T")]${C_RESET} $1"
}

log_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

log_warn() {
    echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"
}

# --- HTML Report Generation Functions ---
initialize_html_report() {
    log "Initializing HTML report file: ${OUTPUT_FILE}"
    cat > "${OUTPUT_FILE}" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Test Report</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
        :root {
            --bg-color: #1a1b26;
            --card-color: #24283b;
            --text-color: #c0caf5;
            --header-color: #ffffff;
            --accent-color: #00bfff; /* DeepSkyBlue/Cyan accent */
            --border-color: #414868;
            --table-header-bg: #2e3452;
        }
        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            margin: 0;
            padding: 2rem;
            font-size: 14px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: var(--card-color);
            border-radius: 12px;
            padding: 2rem;
            border: 1px solid var(--border-color);
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 {
            color: var(--header-color);
            text-align: center;
            border-bottom: 2px solid var(--accent-color);
            padding-bottom: 1rem;
            margin-bottom: 1rem;
            font-weight: 700;
        }
        .report-meta {
            text-align: center;
            margin-bottom: 2rem;
            font-size: 0.9rem;
            color: #7a82ac;
        }
        details {
            background: var(--bg-color);
            border-radius: 8px;
            margin-bottom: 1rem;
            border: 1px solid var(--border-color);
            overflow: hidden;
        }
        summary {
            font-weight: 600;
            font-size: 1.2rem;
            padding: 1rem;
            cursor: pointer;
            color: var(--accent-color);
            background-color: var(--table-header-bg);
            list-style: none;
            display: flex;
            justify-content: space-between;
        }
        summary::-webkit-details-marker { display: none; }
        summary::after {
            content: '+';
            font-size: 1.5rem;
            transition: transform 0.2s;
        }
        details[open] summary::after {
            transform: rotate(45deg);
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 0.8rem 1rem;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
        }
        thead {
            background-color: var(--table-header-bg);
            color: #a9b1d6;
            font-weight: 600;
        }
        tbody tr:nth-child(even) {
            background-color: #2e345250;
        }
        td:nth-child(1) { width: 25%; font-weight: 600; color: #a9b1d6;}
        td:nth-child(2) { width: 35%; font-family: monospace; color: #e0af68; }
        td:nth-child(3) { width: 40%; white-space: pre-wrap; word-break: break-all; font-family: monospace; font-size: 0.85rem;}
        .footer {
            text-align: center;
            margin-top: 2rem;
            font-size: 0.8rem;
            color: #7a82ac;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>System Hardware & Performance Report</h1>
        <div class="report-meta">Generated on: ${TIMESTAMP}</div>
EOF
    log_success "HTML report file initialized."
}

add_html_category_header() {
    local category="$1"
    cat >> "${OUTPUT_FILE}" << EOF
<details open>
    <summary>${category} Tests</summary>
    <table>
        <thead>
            <tr>
                <th>Test</th>
                <th>Command</th>
                <th>Result</th>
            </tr>
        </thead>
        <tbody>
EOF
}

close_html_category_section() {
    cat >> "${OUTPUT_FILE}" << EOF
        </tbody>
    </table>
</details>
EOF
}

add_row_to_html_report() {
    local test_name="$1"
    local command="$2"
    local result="$3"
    local sanitized_cmd
    sanitized_cmd=$(echo "$command" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
    local sanitized_result
    sanitized_result=$(echo "$result" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
    echo "<tr><td>${test_name}</td><td>${sanitized_cmd}</td><td><pre>${sanitized_result}</pre></td></tr>" >> "${OUTPUT_FILE}"
}

finalize_html_report() {
    cat >> "${OUTPUT_FILE}" << EOF
    </div>
    <div class="footer">Script by System Test Automation</div>
</body>
</html>
EOF
    log_success "HTML report has been finalized."
}

run_test() {
    local category="$1"
    local test_name="$2"
    local cmd="$3"
    log "Running Test: ${C_YELLOW}${test_name}${C_RESET}..."
    log "  -> Command: ${cmd}"
    local result
    result=$(eval "${cmd}" 2>&1)
    if [[ -z "$result" ]]; then
        result="No output or command not found."
        log_warn "  -> No output received for '${test_name}'"
    fi
    add_row_to_html_report "$test_name" "$cmd" "$result"
    log_success "  -> Test '${test_name}' complete."
    echo
}

# ==============================================================================
# Pre-flight Checks
# ==============================================================================
check_and_install_dependencies() {
    log "Checking for required command-line tools..."
    declare -A standard_packages
    standard_packages=(
        [lshw]="lshw" [ethtool]="ethtool" [ipmitool]="ipmitool"
        [ibstatus]="ibutils" [ibdev2netdev]="ibutils" [iblinkinfo]="ibutils"
    )
    declare -A complex_commands
    complex_commands=(
        [nvidia-smi]="NVIDIA drivers" [nv-fabricmanager]="NVIDIA Fabric Manager" [ofed_info]="Mellanox OFED drivers"
    )
    declare -A complex_command_instructions
    complex_command_instructions=(
        [nvidia-smi]="
    How to install:
      1. Visit the NVIDIA driver download page: https://www.nvidia.com/Download/index.aspx
      2. On Ubuntu, you can also use the 'Additional Drivers' utility or run: sudo ubuntu-drivers autoinstall"
        [nv-fabricmanager]="
    How to install:
      1. This tool is typically installed from the NVIDIA CUDA repository.
      2. E.g., for Ubuntu: sudo apt-get install nvidia-fabricmanager-535"
        [ofed_info]="
    How to install:
      1. Download the correct driver for your OS from the NVIDIA Networking website.
      2. Unpack and follow the installation guide (e.g., sudo ./mlnxofedinstall)"
    )
    local packages_to_install=()
    log "Scanning for missing standard packages..."
    for cmd in "${!standard_packages[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            local package=${standard_packages[$cmd]}
            if [[ ! " ${packages_to_install[@]} " =~ " ${package} " ]]; then
                packages_to_install+=("$package")
            fi
        fi
    done
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log_warn "The following standard packages appear to be missing:"
        for pkg in "${packages_to_install[@]}"; do echo -e "  - ${C_YELLOW}${pkg}${C_RESET}"; done; echo
        read -p "Do you want to attempt to install them using 'apt'? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            log "Updating and installing packages..."
            apt-get update && apt-get install -y "${packages_to_install[@]}" || { log_error "Package installation failed."; exit 1; }
        else
            log_error "Cannot proceed without required packages. Aborting."; exit 1
        fi
    fi
    log "Scanning for complex drivers and tools..."
    local any_complex_missing=false
    for cmd in "${!complex_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            if ! $any_complex_missing; then
                log_warn "----------------------------------------------------------------"
                log_warn "ATTENTION: Manual installation required for the following:"
                any_complex_missing=true
            fi
            echo -e "\n  -> Missing: ${C_YELLOW}${complex_commands[$cmd]}${C_RESET} (command: ${C_YELLOW}${cmd}${C_RESET})"
            echo -e "${C_YELLOW}${complex_command_instructions[$cmd]}${C_RESET}"
        fi
    done
    if $any_complex_missing; then
        log_warn "\nTests for these components will report 'command not found'."
        log_warn "----------------------------------------------------------------"
        read -p "Do you want to continue with the tests? (Y/n): " continue_choice
        [[ "${continue_choice:-y}" =~ ^[Nn]$ ]] && { log_error "Aborting as requested."; exit 1; }
    fi
    log_success "Dependency check complete." && echo
}

# ==============================================================================
# Test Functions
# ==============================================================================

run_system_info_tests() {
    add_html_category_header "System"
    run_test "System" "System Name" "cat /sys/devices/virtual/dmi/id/product_name"
    run_test "System" "OS Version" "grep PRETTY_NAME /etc/os-release | cut -d '\"' -f 2"
    close_html_category_section
}

run_cpu_tests() {
    add_html_category_header "CPU"
    run_test "CPU" "CPU Model" "lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//'"
    run_test "CPU" "CPU Core Count" "lscpu | grep -E '^(Socket|Core)' | tr '\n' ' ' | sed 's/  */ /g'"
    run_test "CPU" "NUMA Configuration" "lscpu | grep 'NUMA node' | tr '\n' ' ' | sed 's/  */ /g'"
    close_html_category_section
}

run_ram_tests() {
    add_html_category_header "RAM"
    run_test "RAM" "RAM Size" "free -h | grep Mem: | awk '{print \$2}'"
    close_html_category_section
}

run_nvme_tests() {
    add_html_category_header "NVMe Storage"
    run_test "NVMe" "Block Devices" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS"
    run_test "NVMe" "Filesystem Usage" "df -h"
    close_html_category_section
}

run_gpu_tests() {
    add_html_category_header "GPU"
    run_test "GPU" "GPU Type" "nvidia-smi --query-gpu=gpu_name --format=csv,noheader"
    run_test "GPU" "VRAM per GPU" "nvidia-smi --query-gpu=memory.total --format=csv"
    run_test "GPU" "NVIDIA Peermem" "lsmod | grep -i nvidia_peermem"
    run_test "GPU" "NVLink Fabric Manager" "nv-fabricmanager --version"
    run_test "GPU" "NVLink Status" "nvidia-smi nvlink -s"
    run_test "GPU" "Driver Version" "nvidia-smi | grep -i 'Driver Version'"
    close_html_category_section
}

run_ethernet_tests() {
    add_html_category_header "Ethernet Network"
    run_test "Ethernet" "Ethernet NICs" "lshw -C network -short"
    run_test "Ethernet" "Ethernet Links" "ip -br a"
    if ip link show bond0 > /dev/null 2>&1; then
        run_test "Ethernet" "Bond Speed" "ethtool bond0 | grep -i Speed"
        run_test "Ethernet" "Bond Type" "cat /proc/net/bonding/bond0 | grep 'Bonding Mode'"
    else
        add_row_to_html_report "Bond Speed" "ethtool bond0" "Device not found"
        add_row_to_html_report "Bond Type" "cat /proc/net/bonding/bond0" "Device not found"
    fi
    close_html_category_section
}

run_infiniband_tests() {
    add_html_category_header "InfiniBand Network"
    run_test "InfiniBand" "IB Links Speed" "ibstatus | grep -e 'rate:' -e 'device'"
    run_test "InfiniBand" "IB Links Status" "ibstatus | grep -e 'link_layer:' -e 'phys state:'"
    run_test "InfiniBand" "OFED Version" "ofed_info -s"
    run_test "InfiniBand" "IBoIP Enabled" "ibdev2netdev"
    run_test "InfiniBand" "IB Fabric" "iblinkinfo --switches-only"
    close_html_category_section
}

install_docker_ce() {
    log "Starting Docker CE installation..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        log_error "Docker CE installation failed."; return 1
    fi
    log_success "Docker CE installed successfully."
    log "Verifying Docker installation with 'docker ps'..."
    docker ps
    return 0
}

run_benchmark_tests() {
    add_html_category_header "High-Performance Benchmarks"
    if ! command -v docker &> /dev/null; then
        log_warn "Docker is not installed, but it is required for benchmark tests."
        # In --nocheck mode, we can't ask, so we must assume Docker is present or fail.
        if $NOCHECK_MODE; then
             add_row_to_html_report "Benchmarks" "N/A" "Skipped - Docker not installed and running in --nocheck mode"; close_html_category_section; return
        fi
        read -p "Do you want to install Docker CE now? (y/N): " docker_choice
        if [[ "$docker_choice" =~ ^[Yy]$ ]]; then
            install_docker_ce || { add_row_to_html_report "Benchmarks" "N/A" "Skipped due to failed Docker installation"; close_html_category_section; return; }
        else
            add_row_to_html_report "Benchmarks" "N/A" "Skipped - Docker not installed"; close_html_category_section; return;
        fi
    fi
    
    local choice
    if $NOCHECK_MODE; then
        log_warn "Auto-accepting benchmarks due to --nocheck flag."
        choice="y"
    else
        read -p "Run long-running Docker benchmarks (HPL/GPU-burn)? (y/N): " choice
    fi

    if [[ "$choice" =~ ^[Yy]$ ]]; then
        run_test "Benchmark" "HPL Single Node" "docker run --gpus all --rm --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 nvcr.io/nvidia/hpc-benchmarks:24.05 mpirun -np 8 --bind-to none --map-by ppr:8:node /hpl.sh --dat /hpl-linux-x86_64/sample-dat/HPL-dgx-h100-1N.dat"
        run_test "Benchmark" "GPU Burn" "docker run --rm --gpus all oguzpastirmaci/gpu-burn:latest"
    else
        add_row_to_html_report "HPL Single Node" "N/A" "Skipped by user"
        add_row_to_html_report "GPU Burn" "N/A" "Skipped by user"
    fi
    close_html_category_section
}

run_misc_tests() {
    add_html_category_header "Services & Mounts"
    run_test "Services" "SSH Access" "systemctl status sshd | grep 'Active:' | sed 's/^[ \t]*//'"
    run_test "Services" "IPMI Access" "ipmitool lan print"
    run_test "Mounts" "NFS Mounts" "mount | grep nfs"
    close_html_category_section
}

# ==============================================================================
# Main Execution Logic
# ==============================================================================

main() {
    if [[ $EUID -ne 0 ]]; then
       log_error "This script must be run as root or with sudo."; exit 1
    fi

    # --- Parse Command-Line Arguments ---
    for arg in "$@"; do
        if [[ "$arg" == "--nocheck" ]]; then
            NOCHECK_MODE=true
            break
        fi
    done
    
    clear
    echo -e "${C_GREEN}===========================================${C_RESET}"
    echo -e "${C_GREEN}  System Hardware & Performance Test Tool  ${C_RESET}"
    echo -e "${C_GREEN}===========================================${C_RESET}"
    echo

    if $NOCHECK_MODE; then
        log_warn "Running in --nocheck mode. All dependency checks and prompts will be skipped."
    else
        check_and_install_dependencies
    fi

    log "Starting all tests. The results will be saved to: ${C_YELLOW}${OUTPUT_FILE}${C_RESET}"
    echo
    
    initialize_html_report
    
    run_system_info_tests
    run_cpu_tests
    run_ram_tests
    run_nvme_tests
    run_gpu_tests
    run_ethernet_tests
    run_infiniband_tests
    run_misc_tests
    run_benchmark_tests
    
    finalize_html_report
    
    echo
    log_success "All tests have been completed."
    log "Report saved successfully to: ${C_YELLOW}${OUTPUT_FILE}${C_RESET}"
    echo
}

# Pass all script arguments to the main function
main "$@"


