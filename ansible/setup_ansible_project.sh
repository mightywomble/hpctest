#!/bin/bash
# setup_ansible_project.sh
# This script creates the directory structure and files for the Ansible health check playbook.

echo "🚀 Creating Ansible project directories..."
mkdir -p ansible_health_check/{roles,group_vars,templates,reports}

# Create main playbook and config files
echo "📝 Creating core Ansible files..."
cat > ansible_health_check/ansible.cfg << EOL
[defaults]
inventory = ./inventory
host_key_checking = False
retry_files_enabled = False
roles_path = ./roles
EOL

cat > ansible_health_check/inventory << EOL
[servers]
localhost ansible_connection=local
EOL

# Create group_vars for test configuration
echo "🔧 Creating test configuration file..."
cat > ansible_health_check/group_vars/all.yml << EOL
---
# Define all checks in this file. This makes it easy to manage your tests.

# 1. Package checks: List of packages that should be present.
packages_to_check:
  - name: curl
  - name: vim

# 2. Service checks: List of services to check for 'running' and 'enabled' state.
services_to_check:
  - name: sshd
  - name: rsyslog

# 3. Port checks: List of TCP ports that should be listening.
ports_to_check:
  - port: 22
    desc: "SSH Port"
  - port: 80
    desc: "Web Server Port"

# 4. File/Directory checks: List of paths to verify.
# 'state' can be 'directory', 'file', or 'absent'.
files_to_check:
  - path: /etc/hosts
    state: file
  - path: /tmp
    state: directory
  - path: /no/such/file
    state: absent

# 5. Disk space checks: List of mount points and the minimum free space required.
# 'threshold' is the minimum percentage of free space required.
disk_space_to_check:
  - mount: /
    threshold: 10
EOL

# Create the main playbook
echo "📖 Creating main playbook..."
cat > ansible_health_check/playbook.yml << EOL
---
- name: System Health Check Playbook
  hosts: all
  gather_facts: true

  pre_tasks:
    - name: Initialize the list of test results
      ansible.builtin.set_fact:
        test_results: []

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

  post_tasks:
    - name: Generate HTML report from template
      ansible.builtin.template:
        src: templates/report.html.j2
        dest: "reports/health_check_report_{{ ansible_hostname }}_{{ ansible_date_time.iso8610 }}.html"
      delegate_to: localhost
      run_once: true
EOL

# Create the HTML report template
echo "🎨 Creating HTML report template..."
cat > ansible_health_check/templates/report.html.j2 << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Ansible Health Check Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; margin: 40px; background-color: #f4f7f9; color: #333; }
        h1, h2 { color: #2c3e50; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .status-SUCCESS { color: #27ae60; font-weight: bold; }
        .status-FAILED { color: #c0392b; font-weight: bold; }
        .summary { padding: 20px; background-color: #ecf0f1; border-radius: 5px; margin-bottom: 20px; }
        .summary p { margin: 5px 0; }
    </style>
</head>
<body>
    <h1>Ansible Health Check Report</h1>
    <div class="summary">
        <p><strong>Target Host:</strong> {{ inventory_hostname }}</p>
        <p><strong>Report Generated:</strong> {{ ansible_date_time.iso8610_basic_short }}</p>
    </div>

    <h2>Test Results</h2>
    <table>
        <thead>
            <tr>
                <th>Test Name</th>
                <th>Status</th>
                <th>Details</th>
            </tr>
        </thead>
        <tbody>
        {% for result in test_results %}
            <tr>
                <td>{{ result.name }}</td>
                <td><span class="status-{{ result.status }}">{{ result.status }}</span></td>
                <td>{{ result.details }}</td>
            </tr>
        {% else %}
            <tr>
                <td colspan="3">No tests were executed.</td>
            </tr>
        {% endfor %}
        </tbody>
    </table>
</body>
</html>
EOL

# Create roles
ROLES=("check_package" "check_service" "check_port" "check_file" "check_disk_space")
for role in "\${ROLES[@]}"; do
    echo "⚙️  Creating role: \${role}"
    mkdir -p ansible_health_check/roles/\${role}/tasks
done

# Create tasks for each role
echo "---
# tasks file for check_package
- name: Check if required packages are installed
  ansible.builtin.package_facts:
    manager: auto

- name: Evaluate package check results
  ansible.builtin.set_fact:
    test_results: \"{{ test_results + [item_result] }}\"
  loop: \"{{ packages_to_check }}\"
  vars:
    is_installed: item.name in ansible_facts.packages
    item_result:
      name: \"Package Check: {{ item.name }}\"
      status: \"{{ is_installed | ternary('SUCCESS', 'FAILED') }}\"
      details: \"{{ 'Package is installed.' if is_installed else 'Package is NOT installed.' }}\"
" > ansible_health_check/roles/check_package/tasks/main.yml

echo "---
# tasks file for check_service
- name: Get service facts
  ansible.builtin.service_facts:

- name: Evaluate service check results
  ansible.builtin.set_fact:
    test_results: \"{{ test_results + [item_result] }}\"
  loop: \"{{ services_to_check }}\"
  vars:
    service_info: ansible_facts.services[item.name ~ '.service'] | default({})
    is_running: service_info.state | default('unknown') == 'running'
    is_enabled: service_info.status | default('unknown') == 'enabled'
    is_success: is_running and is_enabled
    item_result:
      name: \"Service Check: {{ item.name }}\"
      status: \"{{ is_success | ternary('SUCCESS', 'FAILED') }}\"
      details: \"State is '{{ service_info.state | default('not found') }}' and status is '{{ service_info.status | default('not found') }}'.\"
" > ansible_health_check/roles/check_service/tasks/main.yml

echo "---
# tasks file for check_port
- name: Check if port {{ item.port }} is listening
  ansible.builtin.wait_for:
    port: \"{{ item.port }}\"
    state: started
    timeout: 1
  ignore_errors: true
  register: port_check_result
  loop: \"{{ ports_to_check }}\"
  loop_control:
    label: \"{{ item.desc }} ({{ item.port }})\"

- name: Evaluate port check results
  ansible.builtin.set_fact:
    test_results: \"{{ test_results + [item_result] }}\"
  loop: \"{{ port_check_result.results }}\"
  vars:
    is_success: not item.failed
    item_result:
      name: \"Port Check: {{ item.item.desc }} ({{ item.item.port }})\"
      status: \"{{ is_success | ternary('SUCCESS', 'FAILED') }}\"
      details: \"{{ is_success | ternary('Port is open and listening.', 'Port is closed or unreachable.') }}\"
" > ansible_health_check/roles/check_port/tasks/main.yml

echo "---
# tasks file for check_file
- name: Check file or directory state
  ansible.builtin.stat:
    path: \"{{ item.path }}\"
  register: file_check_stat
  loop: \"{{ files_to_check }}\"
  loop_control:
    label: \"{{ item.path }}\"

- name: Evaluate file check results
  ansible.builtin.set_fact:
    test_results: \"{{ test_results + [item_result] }}\"
  loop: \"{{ file_check_stat.results }}\"
  vars:
    stat_info: item.stat
    expected_state: item.item.state
    actual_state: >-
      {%- if not stat_info.exists -%}
      absent
      {%- elif stat_info.isdir -%}
      directory
      {%- elif stat_info.isreg -%}
      file
      {%- else -%}
      other
      {%- endif -%}
    is_success: expected_state == actual_state
    item_result:
      name: \"Path Check: {{ item.item.path }}\"
      status: \"{{ is_success | ternary('SUCCESS', 'FAILED') }}\"
      details: \"Required state is '{{ expected_state }}', actual state is '{{ actual_state }}'.\"
" > ansible_health_check/roles/check_file/tasks/main.yml

echo "---
# tasks file for check_disk_space
- name: Evaluate disk space check results
  ansible.builtin.set_fact:
    test_results: \"{{ test_results + [item_result] }}\"
  loop: \"{{ disk_space_to_check }}\"
  vars:
    mount_info: ansible_facts.mounts | selectattr('mount', 'equalto', item.mount) | first
    free_percent: \"{{ (100 * mount_info.size_available / mount_info.size_total) | round(2) }}\"
    is_success: free_percent | float >= item.threshold | float
    item_result:
      name: \"Disk Space Check: {{ item.mount }}\"
      status: \"{{ is_success | ternary('SUCCESS', 'FAILED') }}\"
      details: \"{{ free_percent }}% free. (Threshold: >{{ item.threshold }}%)\"
" > ansible_health_check/roles/check_disk_space/tasks/main.yml

echo "✅ All done. Your Ansible project is ready in the 'ansible_health_check' directory."