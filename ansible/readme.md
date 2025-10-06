
# Ansible Hardware & Performance Report

This project provides an automated, idempotent, and extensible framework for running system hardware, performance, and security checks using Ansible. It is designed to replicate the output of a detailed diagnostic script, generating a clean, dark-themed HTML report for each run.

The entire playbook operates in a **read-only** capacity, using Ansible's fact-gathering and command modules to inspect system state without making any changes.

----------

## ✨ Features

-   **Comprehensive Checks**: Includes roles for system info, CPU, RAM, storage, GPU, networking, security, and more.
    
-   **HTML Reporting**: Generates a visually rich, collapsible HTML report summarizing all test results.
    
-   **100% Idempotent**: Safely run checks multiple times without altering the system.
    
-   **Role-Based**: Each category of check is a self-contained role, making it easy to manage and extend.
    
-   **CI/CD Friendly**: Use flags to control which checks to run, perfect for integration with tools like Rundeck.
    

----------

## 🚀 Getting Started

1.  **Run the Setup Script**: Use the `setup_ansible_project.sh` script to create the entire project structure.
    
    Bash
    
    ```
    chmod +x setup_ansible_project.sh
    ./setup_ansible_project.sh
    cd ansible_health_check
    
    ```
    
2.  **Configure Your Checks**: Most tests gather facts directly, but some can be configured in `group_vars/all.yml` (e.g., speed test servers).
    
3.  **Run the Playbook**: Execute the playbook from the command line, using flags to specify which checks to run (see the detailed section below).
    

----------

## 🏃‍♂️ Running the Playbook

The playbook is designed to be controlled by flags passed as **extra variables** (`-e` or `--extra-vars`). Each test category is disabled by default and must be explicitly enabled.

The following flags are available:

-   `run_system_check=true`
    
-   `run_cpu_check=true`
    
-   `run_ram_check=true`
    
-   `run_storage_check=true`
    
-   `run_gpu_check=true`
    
-   `run_ethernet_check=true`
    
-   `run_infiniband_check=true`
    
-   `run_security_check=true`
    
-   `run_network_speed_check=true`
    

### ## Running Individual Tests

You can run one or more specific tests by passing their corresponding flags. This is useful for targeted diagnostics.

**Example: Run only the CPU and GPU checks**

Bash

```
ansible-playbook playbook.yml -e "run_cpu_check=true run_gpu_check=true"

```

### ## Running All Tests

To perform a full system audit and generate a complete report, enable all the flags in a single command.

**Example: Run all available tests**

Bash

```
ansible-playbook playbook.yml -e "run_system_check=true run_cpu_check=true run_ram_check=true run_storage_check=true run_gpu_check=true run_ethernet_check=true run_infiniband_check=true run_security_check=true run_network_speed_check=true"

```

----------

## ⚙️ Rundeck Integration

Integrating this playbook into a Rundeck job is straightforward and allows you to select which tests to run from the Rundeck UI.

### ## 1. Create Job Options

In your Rundeck job, navigate to the **Options** tab and add a new option for each test you want to control. A **Checkbox** is the best type for this.

Configure each option as follows:

-   **Option Type**: `Checkbox`
    
-   **Name**: `run_system_check` (This must match the Ansible variable name)
    
-   **Label**: `Run System Checks?` (This is the user-friendly text shown in the UI)
    
-   **Values**: `true`
    
-   **Checked by default**: Your choice.
    
-   **Delimited by**: `,` (or any other delimiter)
    

Repeat this process for all other flags (e.g., `run_cpu_check`, `run_gpu_check`, etc.).

### ## 2. Configure the Ansible Workflow Step

In the job's **Workflow** tab, add or edit your **Ansible Playbook** step. In the **Extra Ansible arguments** field, you will map the Rundeck options to the `-e` flag.

Rundeck uses the format `@option.NAME@` to reference the value of an option.

```
-e "run_system_check=@option.run_system_check@ run_cpu_check=@option.run_cpu_check@ run_ram_check=@option.run_ram_check@ run_storage_check=@option.run_storage_check@ run_gpu_check=@option.run_gpu_check@ run_ethernet_check=@option.run_ethernet_check@ run_infiniband_check=@option.run_infiniband_check@ run_security_check=@option.run_security_check@ run_network_speed_check=@option.run_network_speed_check@"

```

### ## How it Works

When you run the Rundeck job:

-   If a box is checked, Rundeck substitutes `@option.run_cpu_check@` with `true`.
    
-   If a box is **not** checked, Rundeck substitutes it with an empty string.
    

The `| default(false)` filter in the Ansible playbook gracefully handles the empty string, ensuring the role is skipped as intended. This gives you a powerful, UI-driven way to run any combination of tests.
