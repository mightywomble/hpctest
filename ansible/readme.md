
# Ansible Health Check & Reporting Playbook

This project provides an automated, idempotent, and extensible framework for running system health checks using Ansible. It's designed to be run from a CI/CD pipeline like Rundeck or Jenkins, generating a clean HTML report for each run.

The entire playbook operates in a **read-only** capacity, using Ansible's fact-gathering and check-mode capabilities to inspect system state without making any changes.

----------

## ✨ Features

-   **100% Idempotent**: Safely run checks multiple times without altering the system.
    
-   **Role-Based**: Each type of check is a self-contained role, making it easy to manage and extend.
    
-   **HTML Reporting**: Generates a user-friendly, timestamped HTML report summarizing test results.
    
-   **Declarative Configuration**: Define all your tests in a simple YAML file (`group_vars/all.yml`).
    
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

All tests are defined in `group_vars/all.yml`. Open this file and customize the lists of packages, services, ports, etc., that you want to validate.

### 3. Run the Playbook

Execute the playbook from the command line, using flags to specify which checks to run.

Bash

```
# Example: Run only the package and service checks on the local machine
ansible-playbook playbook.yml -e "run_package_check=true run_service_check=true"

```

----------

## 📁 File & Directory Structure

Here's a breakdown of the key files in this project:

-   `ansible.cfg`: Basic Ansible configuration file pointing to the inventory and roles directory.
    
-   `inventory`: Defines the hosts to run the checks against. By default, it's set to `localhost`.
    
-   `playbook.yml`: The main playbook. It orchestrates the entire process, from initializing variables to conditionally running roles and generating the final report.
    
-   `group_vars/all.yml`: **This is where you define your tests.** All check roles read their configuration from this file.
    
-   `roles/`: Contains a subdirectory for each health check.
    
-   `templates/report.html.j2`: The Jinja2 template used to generate the HTML report.
    
-   `reports/`: The output directory where the generated HTML reports are saved.
    

----------

## ⚙️ How the Roles Work

Each role is designed to perform a specific type of check and report its findings in a standardized format.

-   `check_package`
    
    -   **What it does**: Verifies that a list of packages is installed.
        
    -   **How it works**: It uses the `ansible.builtin.package_facts` module to get a list of all installed packages and then checks if the required packages from `group_vars/all.yml` are present in that list.
        
-   `check_service`
    
    -   **What it does**: Ensures services are both `running` and `enabled`.
        
    -   **How it works**: It uses the `ansible.builtin.service_facts` module to gather the state of all services on the system and compares it against the desired state.
        
-   `check_port`
    
    -   **What it does**: Checks if specific TCP ports are open and listening.
        
    -   **How it works**: It uses the `ansible.builtin.wait_for` module with a short timeout to probe the port without making a full connection. It's configured to check for a `started` state.
        
-   `check_file`
    
    -   **What it does**: Verifies the existence, type (file/directory), or absence of a path.
        
    -   **How it works**: It uses the `ansible.builtin.stat` module to get metadata about a path and then compares the `state` (e.g., `file`, `directory`, `absent`) with the expected state defined in your variables.
        
-   `check_disk_space`
    
    -   **What it does**: Confirms that a mount point has a minimum percentage of free space.
        
    -   **How it works**: It reads the `ansible_facts.mounts` variable (gathered automatically by Ansible) and calculates the percentage of free space, comparing it against the defined threshold.
        

----------

## 🏃‍♂️ Running the Playbook

To run the playbook, you use the standard `ansible-playbook` command. The key is to use **flags** (`-e` or `--extra-vars`) to tell the playbook which roles to execute. If no flags are provided, no tests will run.

### Available Flags

-   `run_package_check=true`: Executes the package installation checks.
    
-   `run_service_check=true`: Executes the service status checks.
    
-   `run_port_check=true`: Executes the open port checks.
    
-   `run_file_check=true`: Executes the file and directory state checks.
    
-   `run_disk_space_check=true`: Executes the disk space checks.
    

### Command Examples

Bash

```
# Run a single check for services
ansible-playbook playbook.yml -e "run_service_check=true"

# Run checks for ports and disk space simultaneously
ansible-playbook playbook.yml -e "run_port_check=true run_disk_space_check=true"

# Run all available checks
ansible-playbook playbook.yml -e "run_package_check=true run_service_check=true run_port_check=true run_file_check=true run_disk_space_check=true"

```

----------

## 📄 The HTML Report

After a successful run, a report is generated in the `reports/` directory.

-   **Filename**: The report has a descriptive name, including the hostname and a precise timestamp (e.g., `health_check_report_my-server_2025-10-06T133000Z.html`).
    
-   **Content**: The report contains a summary table with four columns:
    
    1.  **Test Name**: A description of the check (e.g., "Package Check: curl").
        
    2.  **Status**: The result, which is either **SUCCESS** (green) or **FAILED** (red).
        
    3.  **Details**: A brief message explaining the outcome (e.g., "Package is installed." or "Port is closed or unreachable.").
        

----------

## 🧩 How to Add a New Role

Adding a new check is straightforward. Let's say you want to create a new role to check if a kernel parameter (`sysctl`) has the correct value.

#### Step 1: Create the Role Directory

Create the basic directory structure for your new role.

Bash

```
mkdir -p roles/check_kernel_param/tasks

```

#### Step 2: Define the Check Logic

Create a `main.yml` file inside `roles/check_kernel_param/tasks/` and add your logic. The key is to format the result into a standard dictionary and add it to the `test_results` list.

YAML

```
# roles/check_kernel_param/tasks/main.yml
---
- name: Get value of a kernel parameter
  ansible.posix.sysctl:
    name: net.ipv4.ip_forward
  register: sysctl_result

- name: Evaluate kernel parameter check result
  ansible.builtin.set_fact:
    test_results: "{{ test_results + [item_result] }}"
  vars:
    # Define the expected value (you could move this to group_vars/all.yml)
    expected_value: '1'
    actual_value: "{{ sysctl_result.value }}"
    is_success: actual_value == expected_value
    # This dictionary structure is CRUCIAL for the report to work.
    item_result:
      name: "Kernel Param Check: net.ipv4.ip_forward"
      status: "{{ is_success | ternary('SUCCESS', 'FAILED') }}"
      details: "Expected '{{ expected_value }}', but found '{{ actual_value }}'."

```

#### Step 3: Integrate the Role into the Main Playbook

Open `playbook.yml` and add your new role, complete with its own `when` condition and flag.

YAML

```
# playbook.yml
...
  roles:
    - role: check_package
      when: run_package_check | default(false) | bool
    - role: check_service
      when: run_service_check | default(false) | bool
    - role: check_port
      when: run_port_check | default(false) | bool
    - role: check_file
      when: run_file_check | default(false) | bool
    - role: check_disk_space
      when: run_disk_space_check | default(false) | bool
    # Add your new role here
    - role: check_kernel_param
      when: run_kernel_check | default(false) | bool
...

```

#### Step 4: Run Your New Check

You can now execute your new check using the flag you just defined.

Bash

```
ansible-playbook playbook.yml -e "run_kernel_check=true"

```

The new test result will automatically appear in the HTML report without any changes needed to the template, because you used the correct data structure!
