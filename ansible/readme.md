
Of course. Here is the final, updated `README.md` file.

It now includes the new NCCL test, provides detailed descriptions for every check, and has an expanded section explaining how to configure Rundeck with checkboxes to selectively run any combination of tests.

----------

# Ansible Hardware & Performance Report

This project provides an automated, idempotent, and extensible framework for running system hardware, performance, and security checks using Ansible. It is designed to replicate the output of a detailed diagnostic script, generating a clean, dark-themed HTML report for each run.

The entire playbook operates in a **read-only** capacity for most checks. Optional, intensive benchmark roles (like HCL and NCCL) will install prerequisite software if it is not found.

----------

## 🚀 Getting Started

1.  **Run the Setup Script**: Use the `setup_ansible_project.sh` script to create the entire project structure.
    
    Bash
    
    ```
    chmod +x setup_ansible_project.sh
    ./setup_ansible_project.sh
    cd ansible_health_check
    
    ```
    
2.  **Run the Playbook**: Execute the playbook from the command line, using flags to specify which checks to run. See the detailed sections below for a full explanation of the available checks and how to run them.
    

----------

## ⚙️ Available System Checks

Each of the following checks corresponds to a role in the playbook. You can enable any combination of these checks when you run the playbook.

-   `run_system_check=true`
    
    -   **System & OS Information**: Gathers basic operating system details, including the OS "pretty name" (e.g., `Ubuntu 24.04.3 LTS`), the full `lsb_release -a` output, and the hardware's product name from DMI.
        
-   `run_cpu_check=true`
    
    -   **CPU Details**: Collects comprehensive CPU information, including the model name, core and socket count, and NUMA configuration. It also provides the full, raw output of the `lscpu` command in a collapsible section for deep inspection.
        
-   `run_ram_check=true`
    
    -   **RAM Total**: Reports the total amount of system memory available to the OS.
        
-   `run_storage_check=true`
    
    -   **Storage Layout & Usage**: Provides a complete storage overview by running `lsblk` to show all block devices and their layout, and by calculating filesystem usage (similar to `df -h`) to show the capacity, used space, and available space for all mount points.
        
-   `run_gpu_check=true`
    
    -   **GPU Diagnostics**: Performs a suite of checks for NVIDIA GPUs. It queries for GPU type, VRAM, driver version, and the status of technologies like Peermem and NVLink. It also captures the full `nvidia-smi` output. This role will gracefully skip if an NVIDIA GPU is not detected.
        
-   `run_ethernet_check=true`
    
    -   **Ethernet & Network Interfaces**: Audits all network interfaces, showing hardware details (`lshw`), link status and IP addresses (`ip addr`), link speed (`ethtool`), and the status of any network bond configurations.
        
-   `run_infiniband_check=true`
    
    -   **InfiniBand Diagnostics**: Checks for high-performance InfiniBand networking hardware. It validates link speed and status (`ibstatus`), checks the installed OFED version, and looks for the fabric configuration. This role will gracefully skip if InfiniBand hardware is not detected.
        
-   `run_security_check=true`
    
    -   **Security & Accounts Audit**: Performs several security-related checks. It inspects all MOTD (Message of the Day) files, audits SSH keys in user home directories (checking permissions and generating fingerprints), lists the content of `/etc/passwd`, analyzes `/etc/shadow` to find all accounts with a password set, and enumerates all user home directories.
        
-   `run_network_speed_check=true`
    
    -   **Internet Speed Test**: Provides a real-world test of the server's internet connection. This role automatically downloads and uses the official Ookla Speedtest CLI to measure and report internet ping, jitter, download, and upload speeds.
        
-   `run_software_check=true`
    
    -   **Software Inventory**: Gathers a snapshot of the system's software. It captures the current process list (`ps axfcu`), a complete list of all installed packages (`dpkg -W`), and a list of packages that were installed manually (`apt-mark showmanual`). The package lists are presented in filterable tables in the final report.
        
-   `run_services_check=true`
    
    -   **Services & Mounts**: Checks the status of critical services and mounts. It verifies that the SSH daemon is active, checks for IPMI accessibility for out-of-band management, and reports on any active NFS (Network File System) mounts.
        
-   `run_hcl_check=true`
    
    -   **HCL Benchmark (HPL)**: An intensive, high-performance computing benchmark. If an NVIDIA GPU is present, this role will ensure Docker and the NVIDIA Container Toolkit are installed, then run the NVIDIA HPC benchmark container to perform a High-Performance Linpack (HPL) test, which heavily stresses the CPU and GPU.
        
-   `run_nccl_check=true`
    
    -   **NVIDIA NCCL Benchmark**: A specialized test for GPU interconnect performance. If a GPU is present, this role will install all necessary build tools, clone the NVIDIA NCCL and NCCL-Tests repositories from GitHub, compile the source code, and run the `all_reduce_perf` benchmark to measure the performance of the collective communication library, which is critical for multi-GPU workloads.
        

----------

## 🏃‍♂️ Running the Playbook

You can **pick and choose** any combination of the flags listed above to customize your test run.

### ## Running Individual Tests

To run one or more specific tests, pass their corresponding flags using the `-e` argument.

**Example: Run only the Storage and Network Speed tests**

Bash

```
ansible-playbook playbook.yml -e "run_storage_check=true run_network_speed_check=true"

```

### ## Running All Tests

To perform a full system audit, enable all the flags in a single command.

**Example: Run all available tests**

Bash

```
ansible-playbook playbook.yml -e "run_system_check=true run_cpu_check=true run_ram_check=true run_storage_check=true run_gpu_check=true run_ethernet_check=true run_infiniband_check=true run_security_check=true run_network_speed_check=true run_software_check=true run_services_check=true run_hcl_check=true run_nccl_check=true"

```

----------

## 🐛 Debugging the Playbook

If you encounter issues, you can get more information by running the playbook in debug mode.

-   **Use `-v`**: This will display the output of built-in debug tasks, showing the data collected by the roles just before the report is generated.
    
-   **Use `-vvv`**: This will print the full error traceback if a task fails, which is essential for diagnosing issues within the template files.
    

----------

## ⚙️ Rundeck Integration

You can easily configure a Rundeck job to let users select which tests to run via simple checkboxes.

### ## Step 1: Create Job Options

In your Rundeck job, navigate to the **Options** tab and add a **Checkbox** option for each test you want to control.

For example, to add the new NCCL test, you would configure it as follows:

-   **Option Type**: `Checkbox`
    
-   **Name**: `run_nccl_check` (This must match the Ansible variable)
    
-   **Label**: `Run NCCL Benchmark?` (This is the friendly text shown in the UI)
    
-   **Values**: `true`
    
-   **Default Value**: (Leave blank to be unchecked by default)
    

Repeat this process for all other flags (`run_system_check`, `run_gpu_check`, etc.).

### ## Step 2: Configure the Ansible Workflow Step

In the job's **Workflow** tab, edit your **Ansible Playbook** step. In the **Extra Ansible arguments** field, you will map the Rundeck options to the `-e` flag using the format `@option.NAME@`.

Paste the full command below into that field:

```
-e "run_system_check=@option.run_system_check@ run_cpu_check=@option.run_cpu_check@ run_ram_check=@option.run_ram_check@ run_storage_check=@option.run_storage_check@ run_gpu_check=@option.run_gpu_check@ run_ethernet_check=@option.run_ethernet_check@ run_infiniband_check=@option.run_infiniband_check@ run_security_check=@option.run_security_check@ run_network_speed_check=@option.run_network_speed_check@ run_software_check=@option.run_software_check@ run_services_check=@option.run_services_check@ run_hcl_check=@option.run_hcl_check@ run_nccl_check=@option.run_nccl_check@"

```

### ## How It Works

When you run the job, Rundeck will substitute the value of each option. If a box is checked, it passes `true`. If a box is unchecked, it passes an empty string. The `| default(false)` filter in the Ansible playbook handles the empty string, ensuring the role is correctly skipped.
