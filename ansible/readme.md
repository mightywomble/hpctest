# Ansible Hardware & Performance Report

This project provides an automated, idempotent, and extensible framework for running system hardware, performance, and security checks using Ansible. It is designed to replicate the output of a detailed diagnostic script, generating a clean, dark-themed HTML report for each run.

The entire playbook operates in a **read-only** capacity for most checks, using Ansible's fact-gathering and command modules. The optional HCL benchmark role will install prerequisite software if it is not found.

----------

## ✨ Features

-   **Comprehensive Checks**: Includes roles for system info, CPU, RAM, storage, GPU, networking, security, software, services, and an optional HCL benchmark.
    
-   **HTML Reporting**: Generates a visually rich, collapsible HTML report summarizing all test results.
    
-   **Idempotent**: Safely run checks multiple times. The roles will not make changes to the system unless prerequisites for a test (like the HCL benchmark) are missing.
    
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
    
2.  **Run the Playbook**: Execute the playbook from the command line, using flags to specify which checks to run (see the detailed section below).
    

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
    
-   `run_software_check=true`
    
-   `run_services_check=true`
    
-   `run_hcl_check=true`
    

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
ansible-playbook playbook.yml -e "run_system_check=true run_cpu_check=true run_ram_check=true run_storage_check=true run_gpu_check=true run_ethernet_check=true run_infiniband_check=true run_security_check=true run_network_speed_check=true run_software_check=true run_services_check=true run_hcl_check=true"

```

----------

## 🐛 Debugging the Playbook

If you encounter issues (e.g., a report isn't generated), you can use Ansible's built-in debugging features.

### ## Method 1: Increase Verbosity

The easiest way to find an error is to run the playbook with increased verbosity.

-   **Use `-v`**: This will display the output of the built-in debug task, showing you the `test_results` variable just before the report is generated.
    
    Bash
    
    ```
    ansible-playbook playbook.yml -e "..." -v
    
    ```
    
-   **Use `-vvv`**: This is more powerful. If a task fails (especially the template task), it will print the full error traceback, which usually points to the exact line and problem (e.g., a syntax error in a `.j2` file).
    
    Bash
    
    ```
    ansible-playbook playbook.yml -e "..." -vvv
    
    ```
    

### ## Method 2: Built-in Debug Blocks

The `playbook.yml` now includes two debugging mechanisms in the `post_tasks` section:

1.  **Display Data**: A `debug` task that prints all the data collected by the roles. This is triggered by running the playbook with `-v`. It helps you verify that data is being collected as expected.
    
2.  **Error Catching**: A `block`/`rescue` structure around the report generation task. If the template fails to render for any reason, the `rescue` block will be executed, and the playbook will stop with a clear error message explaining what failed, rather than finishing silently.
    

----------

## ⚙️ Rundeck Integration

Integrating this playbook into a Rundeck job is straightforward and allows you to select which tests to run from the Rundeck UI.

### ## 1. Create Job Options

In your Rundeck job, navigate to the **Options** tab and add a **Checkbox** option for each test you want to control.

Configure each option as follows:

-   **Option Type**: `Checkbox`
    
-   **Name**: `run_system_check` (must match the Ansible variable)
    
-   **Label**: `Run System Checks?` (user-friendly text)
    
-   **Values**: `true`
    

Repeat this for all other flags (`run_cpu_check`, `run_gpu_check`, `run_hcl_check`, etc.).

### ## 2. Configure the Ansible Workflow Step

In the job's **Workflow** tab, edit your **Ansible Playbook** step. In the **Extra Ansible arguments** field, map the Rundeck options to the `-e` flag using the format `@option.NAME@`.

```
-e "run_system_check=@option.run_system_check@ run_cpu_check=@option.run_cpu_check@ run_ram_check=@option.run_ram_check@ run_storage_check=@option.run_storage_check@ run_gpu_check=@option.run_gpu_check@ run_ethernet_check=@option.run_ethernet_check@ run_infiniband_check=@option.run_infiniband_check@ run_security_check=@option.run_security_check@ run_network_speed_check=@option.run_network_speed_check@ run_software_check=@option.run_software_check@ run_services_check=@option.run_services_check@ run_hcl_check=@option.run_hcl_check@"
```
