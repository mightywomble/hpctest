
# System Hardware & Performance Test Script

A comprehensive bash script designed to automate the auditing and performance testing of high-performance computing (HPC) nodes. It runs a series of hardware and software checks and compiles the results into a clean, self-contained, and professional HTML report.

![Web Output](interface.png)


## Features

-   **Automated System Checks**: Gathers detailed information on the OS, CPU, RAM, NVMe storage, GPUs, Ethernet, and InfiniBand configurations.
    
-   **Self-Contained HTML Reports**: Generates a single, beautifully styled HTML file with collapsible sections for easy navigation. No external dependencies are needed to view the report.
    
-   **Intelligent Dependency Handling**: Automatically detects and offers to install missing standard packages. For complex drivers (NVIDIA, Mellanox), it provides clear manual installation instructions.
    
-   **Optional Performance Benchmarks**: Includes long-running HPL and GPU-burn benchmarks via Docker, with interactive prompts to run or skip them.
    
-   **Automated Mode**: A `--nocheck` flag allows the script to run non-interactively, skipping all prompts, making it ideal for automated CI/CD pipelines or batch testing.
    

## Sample Report

The script generates an HTML report with a dark, modern theme. Here is a sample of what the interface looks like:

## Requirements

-   **Operating System**: Ubuntu 24.04 LTS (or a similar Debian-based distribution).
    
-   **Privileges**: The script must be run as `root` or with `sudo` privileges to access hardware information.
    

## Installation

1.  **Save the script**: Save the script content to a file named `hpctests.sh`.
    
2.  **Make it executable**: Open your terminal and run the following command:
    
    ```
    chmod +x hpctests.sh
    
    ```
    

## Dependencies

The script will check for required software and assist with installation.

#### 1. Standard Packages (Automatic Installation)

If the following tools are missing, the script will prompt you to install them automatically using `apt`:

-   `lshw`
    
-   `ethtool`
    
-   `ipmitool`
    
-   `ibutils` (for InfiniBand tools like `ibstatus`)
    
-   `docker-ce` (only if you choose to run the performance benchmarks)
    

#### 2. Complex Drivers (Manual Installation)

For specialized HPC drivers, the script will detect if they are missing and provide instructions. Manual installation is required for:

-   **NVIDIA Drivers (`nvidia-smi`)**:
    
    -   **Method**: Use Ubuntu's built-in tool or download from the official NVIDIA site.
        
    -   **Command**: `sudo ubuntu-drivers autoinstall`
        
-   **Mellanox OFED Drivers (`ofed_info`)**:
    
    -   **Method**: These must be downloaded directly from the NVIDIA Networking website (formerly Mellanox). Follow the installation guide included with the driver package.
        
-   **NVIDIA Fabric Manager (`nv-fabricmanager`)**:
    
    -   **Method**: This is typically installed via the NVIDIA CUDA repository.
        
    -   **Command**: `sudo apt install nvidia-fabricmanager-535` (version may vary)
        

## Usage

You can run the script with the following flags to control behavior.

- Interactive (prompts):
  ```bash path=null start=null
  sudo ./hpctests.sh
  ```

- Headless (auto-yes to prompts; installs allowed):
  ```bash path=null start=null
  sudo ./hpctests.sh --headless
  ```

- Skip Docker benchmarks:
  ```bash path=null start=null
  sudo ./hpctests.sh --noburn
  ```

- Do not install anything (skip installs and skip benchmarks), but still run tests and generate report:
  ```bash path=null start=null
  sudo ./hpctests.sh --noinstall
  ```

- Legacy non-interactive mode (skips dependency prompts and confirmations; runs all tests):
  ```bash path=null start=null
  sudo ./hpctests.sh --nocheck
  ```

- Show help:
  ```bash path=null start=null
  sudo ./hpctests.sh --help
  ```

### Flag interactions
- --headless may be combined with --noburn to run tests non-interactively while skipping benchmarks.
- --noinstall implies no Docker installation and benchmarks are skipped.

## Tests Run and Expected Output (overview)

- System
  - What: DMI product name, OS version (short and full)
  - Expect: Strings identifying platform and distribution
- CPU
  - What: Model, core/socket topology, NUMA info, full lscpu output (collapsible)
  - Expect: Vendor/model line, counts match hardware; NUMA lines present on NUMA systems
- RAM
  - What: Total memory (free -h)
  - Expect: Human-readable total (e.g., 251G)
- NVMe Storage
  - What: lsblk overview with device chips; filesystem usage (df -h)
  - Expect: Disks listed as chips; lsblk table; mounted filesystems in df
- GPU
  - What: Names, VRAM, peermem module, Fabric Manager, NVLink status, driver version; full nvidia-smi (collapsible)
  - Expect: PASS when nvidia-smi is available; otherwise partial with install guidance
- Ethernet Network
  - What: NIC inventory, IPs, per-interface link speeds vs threshold, bond details if present
  - Expect: Link speeds visible; PASS/FAIL depends on MIN_LINK_SPEED_MBPS
- InfiniBand Network
  - What: Rate/status, OFED version, IBoIP mapping, fabric switches
  - Expect: Outputs if IB stack present; otherwise partial/fail where missing
- Security & Accounts
  - What: MOTD files, SSH key metadata (no secrets), /etc/passwd, shadow status summary, home directories
  - Expect: Collapsible sections with sanitized content; no secrets revealed
- Network Speed Tests
  - What: Two runs via speedtest-cli (Nearby, Europe)
  - Expect: Download/Upload values; PASS/FAIL/Partial depends on thresholds and availability
- Software & Packages
  - What: Process list; Installed packages; Manually installed packages
  - Expect: Searchable tables; may be partial on minimal systems
- Services & Mounts
  - What: sshd status, IPMI access, NFS mounts
  - Expect: PASS where services/mounts are present
- High-Performance Benchmarks (Docker)
  - What: HPL single-node; GPU-burn
  - Expect: Run only if Docker present/installed and not skipped by --noburn/--noinstall; otherwise recorded as skipped

## Using the HTML report
- Single, self-contained HTML file with collapsible sections per category
- Two export buttons at the top:
  - Export Checklist CSV: condensed checklist with statuses
  - Export Full Results CSV: full table content
- Status badges:
  - PASS: Green
  - PARTIAL: Yellow
  - FAIL: Red
- Notes field explains why a test is partial/fail and any thresholds used

## Running remotely over SSH and saving the HTML locally

Example: run on a remote HPC node, then copy the newest report back to your local machine.

```bash path=null start=null
# 1) Run remotely (auto-yes for prompts, skip benchmarks)
ssh user@remote-host 'cd ~/code/hpctest && sudo ./hpctests.sh --headless --noburn'

# 2) Find latest report on remote and copy it back
LATEST=$(ssh user@remote-host 'ls -t system_test_report_*.html 2>/dev/null | head -n1')
scp user@remote-host:"$LATEST" ./

# 3) Open locally (macOS example)
open "$(basename "$LATEST")"
```

Notes:
- Ensure the script resides on the remote host and is executable (chmod +x hpctests.sh).
- You can combine flags as needed (e.g., --noinstall to avoid any package installs).

## Output

The script generates a single HTML file in the same directory, named with a timestamp (e.g., `system_test_report_2025-09-12_15-30-00.html`). This file is self-contained and can be opened in any modern web browser to view the full report.
