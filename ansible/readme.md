
# Ansible Hardware & Performance Report

This project provides an automated, idempotent, and extensible framework for running system hardware, performance, and security checks using Ansible. It is designed to replicate the output of a detailed diagnostic script, generating a clean, dark-themed HTML report for each run.

The entire playbook operates in a **read-only** capacity, using Ansible's fact-gathering and command modules to inspect system state without making any changes.

----------

## ✨ Features

-   **Comprehensive Checks**: Includes roles for system info, CPU, RAM, storage, GPU, networking, security, and more.
    
-   **Identical HTML Reporting**: Generates a visually identical, collapsible HTML report that matches the provided diagnostic script's output.
    
-   **100% Idempotent**: Safely run checks multiple times without altering the system.
    
-   **Role-Based**: Each category of check is a self-contained role, making it easy to manage and extend.
    
-   **CI/CD Friendly**: Use flags to control which checks to run, perfect for integration with tools like Rundeck.
    

----------

## 🚀 Getting Started

### 1. Run the Setup Script

First, run the provided setup script to create the entire project structure and all necessary files.

Bash

```
# Make the script executable
chmod +x setup_ansible_project.sh

# Run the script
./setup_ansible_project.sh

# Navigate into the newly created project directory
cd ansible_health_check

```

### 2. Configure Your Checks

Most tests gather facts directly, but some can be configured in `group_vars/all.yml`. For example, you can define which speed test servers to use.

### 3. Run the Playbook

Execute the playbook from the command line, using flags to specify which checks to run.

Bash

```
# Example: Run only the system and GPU checks on the local machine
ansible-playbook playbook.yml -e "run_system_check=true run_gpu_check=true"

```

----------

## ⚙️ How the Roles Work

Each role performs a specific set of checks and appends its results to a categorized dictionary, which is then used to build the HTML report.

-   `check_system`: Gathers basic OS and system information.
    
-   `check_cpu`: Uses `lscpu` to get detailed CPU information like model and core count.
    
-   `check_ram`: Uses Ansible's gathered facts (`ansible_facts.memtotal_mb`) to report total memory.
    
-   `check_storage`: Reports on block devices and filesystem usage from `ansible_facts.mounts`.
    
-   `check_gpu`: Executes `nvidia-smi` to check for GPU presence and driver status. **Fails gracefully** if the command is not found.
    
-   `check_ethernet`: Gathers network interface details using the `ip -br a` command.
    
-   `check_infiniband`: Checks for InfiniBand hardware using `ibstatus`. **Fails gracefully** if the command is not found.
    
-   `check_security`: Audits user accounts by reading `/etc/passwd` using Ansible's `slurp` module.
    
-   `check_network_speed`: Runs `speedtest-cli` against specified server IDs to benchmark internet performance.
    

----------

## 🏃‍♂️ Running the Playbook

To run the playbook, you must use **flags** (`-e` or `--extra-vars`) to specify which roles to execute. If no flags are provided, no tests will run.

### Available Flags

-   `run_system_check=true`
    
-   `run_cpu_check=true`
    
-   `run_ram_check=true`
    
-   `run_storage_check=true`
    
-   `run_gpu_check=true`
    
-   `run_ethernet_check=true`
    
-   `run_infiniband_check=true`
    
-   `run_security_check=true`
    
-   `run_network_speed_check=true`
    

### Command Examples

Bash

```
# Run a quick check on CPU and RAM
ansible-playbook playbook.yml -e "run_cpu_check=true run_ram_check=true"

# Run all available checks
ansible-playbook playbook.yml -e "run_system_check=true run_cpu_check=true run_ram_check=true run_storage_check=true run_gpu_check=true run_ethernet_check=true run_infiniband_check=true run_security_check=true run_network_speed_check=true"

```

----------

## 🌐 Running on a Remote System

You can easily run these checks on any remote machine managed by Ansible.

### Prerequisites

1.  **SSH Access**: You must have passwordless SSH access (using SSH keys) from your command line to the remote server.
    
2.  **Sudo Privileges**: The user you connect with must have `sudo` privileges to run certain diagnostic commands.
    
3.  **Inventory File**: The remote host must be defined in an Ansible inventory file. Your system-wide inventory is typically at `/etc/ansible/hosts`.
    

### Example Command

To run the playbook against a remote server named `webserver01` defined in your system inventory, use the `-i` (inventory) and `--limit` flags.

Bash

```
ansible-playbook playbook.yml \
    -i /etc/ansible/hosts \
    --limit webserver01 \
    -u your-remote-user \
    --ask-become-pass \
    -e "run_gpu_check=true run_storage_check=true"

```

-   `-i /etc/ansible/hosts`: Specifies the inventory file to use.
    
-   `--limit webserver01`: Restricts the playbook run to only the host named `webserver01`.
    
-   `-u your-remote-user`: Specifies the username to connect with via SSH.
    
-   `--ask-become-pass`: Prompts you to enter the `sudo` password for the remote user. For full automation, configure passwordless `sudo`.
    

----------

## 📄 The HTML Report

The generated report in the `reports/` directory is a faithful recreation of the dark-themed diagnostic output. It includes collapsible sections for each category, status badges (PASS/FAIL/PARTIAL), and the Ansible module or command used to perform the check.

----------

## 🧩 How to Add a New Role

To extend the playbook with a new category of checks, follow these steps.

#### Step 1: Create the Role Directory

Bash

```
mkdir -p roles/check_new_thing/tasks

```

#### Step 2: Add Logic to `tasks/main.yml`

In the new task file, perform your check and use `set_fact` to add the result to the correct category. The `combine` filter with `recursive=True` is essential.

YAML

```
# roles/check_new_thing/tasks/main.yml
---
- name: Perform a new check
  ansible.builtin.command: your_command_here
  register: command_result
  changed_when: false
  failed_when: false

- name: Format the new check's result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'new_thing': test_results.new_thing + [item_result]}}, recursive=True) }}"
  vars:
    item_result:
      name: "My New Awesome Check"
      command: "your_command_here"
      result: "{{ command_result.stdout }}"
      status: "{{ command_result.rc == 0 | ternary('PASS', 'FAIL') }}"
      notes: "Exit code was {{ command_result.rc }}"

```

#### Step 3: Integrate into the Main Playbook

Open `playbook.yml` and add the new role with its flag. You will also need to add `new_thing: []` to the `test_results` dictionary in the `pre_tasks` section.

YAML

```
# playbook.yml
...
  pre_tasks:
    - name: Initialize test results dictionary
      ansible.builtin.set_fact:
        test_results:
          system: []
          # ... other categories
          new_thing: [] # <-- Add new category here

  roles:
    # ... other roles
    - { role: check_new_thing, when: run_new_thing_check | default(false) | bool }
...

```

Now you can run your new check with the `-e "run_new_thing_check=true"` flag, and it will appear in its own section in the HTML report.