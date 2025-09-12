
# System Hardware & Performance Test Script

A comprehensive bash script designed to automate the auditing and performance testing of high-performance computing (HPC) nodes. It runs a series of hardware and software checks and compiles the results into a clean, self-contained, and professional HTML report.

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

1.  **Save the script**: Save the script content to a file named `system_tests.sh`.
    
2.  **Make it executable**: Open your terminal and run the following command:
    
    ```
    chmod +x system_tests.sh
    
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

You can run the script in two modes from your terminal.

#### 1. Interactive Mode (Recommended for first run)

This mode will perform all dependency checks and prompt you for decisions (like installing software or running long tests).

```
sudo ./system_tests.sh

```

#### 2. Automated Mode

This mode skips all dependency checks and confirmation prompts, making it ideal for automated environments. It will immediately run all tests, including the long-running benchmarks.

```
sudo ./system_tests.sh --nocheck

```

## Output

The script generates a single HTML file in the same directory, named with a timestamp (e.g., `system_test_report_2025-09-12_15-30-00.html`). This file is self-contained and can be opened in any modern web browser to view the full report.
