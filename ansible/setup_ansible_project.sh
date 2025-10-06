#!/bin/bash
# setup_ansible_project.sh (v4 - Consolidated Fixes)
# This script creates the directory structure and files for the Ansible health check playbook.

echo "🚀 Creating Ansible project directories..."
# Clean up previous attempt if it exists
rm -rf ansible_health_check
mkdir -p ansible_health_check/{roles,group_vars,templates,reports}

# Create main playbook and config files
echo "📝 Creating core Ansible files..."
cat > ansible_health_check/ansible.cfg << 'EOL'
[defaults]
inventory = ./inventory
host_key_checking = False
retry_files_enabled = False
roles_path = ./roles
[ssh_connection]
pipelining = True
EOL

cat > ansible_health_check/inventory << 'EOL'
[servers]
localhost ansible_connection=local
EOL

# Create group_vars for test configuration
echo "🔧 Creating test configuration file..."
cat > ansible_health_check/group_vars/all.yml << 'EOL'
---
# This file is for global configuration. Specific tests can be toggled via flags.

# Example: Define network speed test servers
speed_test_servers:
  - { desc: "Speedtest Nearby", server_id: "14679" }
  - { desc: "Speedtest Europe", server_id: "14679" } # Using same for demo
EOL

# Create the main playbook
echo "📖 Creating main playbook..."
cat > ansible_health_check/playbook.yml << 'EOL'
---
- name: System Hardware & Performance Report Playbook
  hosts: all
  gather_facts: true

  pre_tasks:
    - name: Initialize test results dictionary
      ansible.builtin.set_fact:
        test_results:
          system: []
          cpu: []
          ram: []
          storage: []
          gpu: []
          ethernet: []
          infiniband: []
          security: []
          network_speed: []

  roles:
    - { role: check_system, when: run_system_check | default(false) | bool }
    - { role: check_cpu, when: run_cpu_check | default(false) | bool }
    - { role: check_ram, when: run_ram_check | default(false) | bool }
    - { role: check_storage, when: run_storage_check | default(false) | bool }
    - { role: check_gpu, when: run_gpu_check | default(false) | bool }
    - { role: check_ethernet, when: run_ethernet_check | default(false) | bool }
    - { role: check_infiniband, when: run_infiniband_check | default(false) | bool }
    - { role: check_security, when: run_security_check | default(false) | bool }
    - { role: check_network_speed, when: run_network_speed_check | default(false) | bool }

  post_tasks:
    - name: Generate HTML report from template
      ansible.builtin.template:
        src: templates/report.html.j2
        dest: "reports/system_test_report_{{ ansible_hostname }}_{{ ansible_date_time.iso8601 }}.html"
      delegate_to: localhost
      run_once: true
EOL

# Create the new, matching HTML report template
echo "🎨 Creating new HTML report template..."
cat > ansible_health_check/templates/report.html.j2 << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Test Report</title>
    <style>
        :root {
            --bg-color: #1a1b26; --card-color: #24283b; --text-color: #c0caf5;
            --header-color: #ffffff; --accent-color: #00bfff; --border-color: #414868;
            --table-header-bg: #2e3452; --green: #34d399; --yellow: #facc15; --red: #f87171;
        }
        body { font-family: 'Inter', sans-serif; background-color: var(--bg-color); color: var(--text-color); margin: 0; padding: 2rem; font-size: 14px; }
        .container { max-width: 1200px; margin: 0 auto; background-color: var(--card-color); border-radius: 12px; padding: 2rem; border: 1px solid var(--border-color); box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
        h1 { color: var(--header-color); text-align: center; border-bottom: 2px solid var(--accent-color); padding-bottom: 1rem; margin-bottom: 0.5rem; font-weight: 700; }
        .report-meta, .report-host { text-align: center; margin-bottom: 1.5rem; font-size: 0.95rem; color: #7a82ac; }
        details { background: var(--bg-color); border-radius: 8px; margin-bottom: 1rem; border: 1px solid var(--border-color); overflow: hidden; }
        summary { font-weight: 600; font-size: 1.2rem; padding: 1rem; cursor: pointer; color: var(--accent-color); background-color: var(--table-header-bg); list-style: none; display: flex; justify-content: space-between; }
        summary::after { content: '+'; font-size: 1.5rem; transition: transform 0.2s; }
        details[open] summary::after { transform: rotate(45deg); }
        table { width: 100%; border-collapse: collapse; table-layout: fixed; }
        th, td { padding: 0.8rem 1rem; text-align: left; border-bottom: 1px solid var(--border-color); vertical-align: top; overflow-wrap: anywhere; word-break: break-word; }
        pre { white-space: pre-wrap; word-break: break-word; margin: 0;}
        thead { background-color: var(--table-header-bg); color: #a9b1d6; font-weight: 600; }
        tbody tr:nth-child(even) { background-color: #2e345250; }
        thead th:nth-child(1) { width: 20%; }
        thead th:nth-child(2) { width: 30%; }
        thead th:nth-child(3) { width: 40%; }
        thead th:nth-child(4) { width: 10%; }
        td:nth-child(1) { font-weight: 600; color: #a9b1d6;}
        td:nth-child(2) { font-family: monospace; color: #e0af68; }
        td:nth-child(3) { white-space: pre-wrap; word-break: break-word; font-family: monospace; font-size: 0.85rem;}
        .status-badge { display: inline-block; padding: 0.2rem 0.5rem; border-radius: 9999px; font-weight: 600; font-size: 0.8rem; }
        .status-pass { background: rgba(52,211,153,0.15); color: var(--green); border: 1px solid rgba(52,211,153,0.4); }
        .status-partial { background: rgba(250,204,21,0.15); color: var(--yellow); border: 1px solid rgba(250,204,21,0.4); }
        .status-fail { background: rgba(248,113,113,0.15); color: var(--red); border: 1px solid rgba(248,113,113,0.4); }
        .status-notes { display:block; margin-top:0.25rem; font-size: 0.8rem; color: #a9b1d6; white-space: pre-wrap; }
        .footer { text-align: center; margin-top: 2rem; font-size: 0.8rem; color: #7a82ac; }
    </style>
</head>
<body>
    <div class="container">
        <h1>System Hardware & Performance Report</h1>
        <div class="report-meta">Generated on: {{ ansible_date_time.iso8601 }}</div>
        <div class="report-host">Hostname: {{ ansible_hostname }} • Primary IP: {{ ansible_default_ipv4.address }}</div>

        {% set categories = {
            'System': test_results.system, 'CPU': test_results.cpu, 'RAM': test_results.ram,
            'NVMe Storage': test_results.storage, 'GPU': test_results.gpu, 'Ethernet Network': test_results.ethernet,
            'InfiniBand Network': test_results.infiniband, 'Security & Accounts': test_results.security,
            'Network Speed Tests': test_results.network_speed
        } %}

        {% for category, results in categories.items() %}
        {% if results %}
        <details open>
            <summary>{{ category }}</summary>
            <table>
                <thead>
                    <tr>
                        <th>Test</th>
                        <th>Command</th>
                        <th>Result</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                {% for result in results %}
                    <tr>
                        <td>{{ result.name }}</td>
                        <td><pre>{{ result.command }}</pre></td>
                        <td><pre>{{ result.result }}</pre></td>
                        <td>
                            <span class="status-badge status-{{ result.status | lower }}">{{ result.status }}</span>
                            {% if result.notes %}
                            <span class="status-notes">{{ result.notes }}</span>
                            {% endif %}
                        </td>
                    </tr>
                {% endfor %}
                </tbody>
            </table>
        </details>
        {% endif %}
        {% endfor %}
    </div>
    <div class="footer">Generated by Ansible</div>
</body>
</html>
EOL

# Create roles and their task files
ROLES=("check_system" "check_cpu" "check_ram" "check_storage" "check_gpu" "check_ethernet" "check_infiniband" "check_security" "check_network_speed")
for role in "${ROLES[@]}"; do
    echo "⚙️  Creating role: ${role}"
    mkdir -p "ansible_health_check/roles/${role}/tasks"
done

echo "✍️ Writing task files for all roles..."

# --- TASKS FOR EACH ROLE ---
# Helper function to create task files
create_task_file() {
    role_name=$1
    shift
    content="$@"
    echo -e "$content" > "ansible_health_check/roles/${role_name}/tasks/main.yml"
}

# Role: check_system
create_task_file "check_system" \
'---
- name: Get OS Version
  ansible.builtin.command: grep PRETTY_NAME /etc/os-release
  register: os_version
  changed_when: false
  failed_when: false

- name: Create OS Version result object
  ansible.builtin.set_fact:
    os_version_result:
      name: "OS Version"
      command: "grep PRETTY_NAME /etc/os-release"
      result: "{{ os_version.stdout | regex_replace(''PRETTY_NAME=\"(.*?)\"'', ''\\1'') | trim }}"
      status: "{{ os_version.rc == 0 | ternary(''PASS'', ''FAIL'') }}"
      notes: ""

- name: Append OS Version result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''system'': test_results.system + [os_version_result]}, recursive=True) }}"
'

# Role: check_cpu
create_task_file "check_cpu" \
'---
- name: Get CPU Information
  ansible.builtin.command: lscpu
  register: lscpu_output
  changed_when: false
  failed_when: false

- name: Create CPU Model result object
  ansible.builtin.set_fact:
    cpu_model_result:
      name: "CPU Model"
      command: "lscpu"
      result: "{{ lscpu_output.stdout | regex_search(''Model name:\\s+(.+)'', ''\\1'') | first | trim }}"
      status: "{{ lscpu_output.rc == 0 | ternary(''PASS'', ''FAIL'') }}"
      notes: ""

- name: Append CPU Model result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''cpu'': test_results.cpu + [cpu_model_result]}, recursive=True) }}"
'

# Role: check_ram
create_task_file "check_ram" \
'---
- name: Create RAM Size result object
  ansible.builtin.set_fact:
    ram_size_result:
      name: "RAM Size"
      command: "ansible_facts.memtotal_mb"
      result: "{{ (ansible_facts.memtotal_mb / 1024) | round(0, ''ceil'') }}Gi"
      status: "PASS"
      notes: ""

- name: Append RAM Size result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''ram'': test_results.ram + [ram_size_result]}, recursive=True) }}"
'

# Role: check_storage
create_task_file "check_storage" \
'---
- name: Create Filesystem Usage result object
  ansible.builtin.set_fact:
    fs_usage_result:
      name: "Filesystem Usage"
      command: "ansible_facts.mounts"
      result: |
        {% for mount in ansible_facts.mounts -%}
        {{ mount.device }} {{ mount.size_total | human_readable }} {{ (mount.size_total - mount.size_available) | human_readable }} {{ mount.size_available | human_readable }} {{ (((mount.size_total - mount.size_available) / mount.size_total) * 100) | round(0) }}% {{ mount.mount }}
        {% endfor %}
      status: "PASS"
      notes: ""

- name: Append Filesystem Usage result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''storage'': test_results.storage + [fs_usage_result]}, recursive=True) }}"
'

# Role: check_gpu
create_task_file "check_gpu" \
'---
- name: Check for nvidia-smi command
  ansible.builtin.command: nvidia-smi --query-gpu=gpu_name --format=csv,noheader
  register: gpu_type
  changed_when: false
  failed_when: false

- name: Create GPU Type result object
  ansible.builtin.set_fact:
    gpu_type_result:
      name: "GPU Type"
      command: "nvidia-smi --query-gpu=gpu_name --format=csv,noheader"
      result: "{{ gpu_type.rc != 0 | ternary(gpu_type.stderr if gpu_type.stderr else gpu_type.stdout, gpu_type.stdout) }}"
      status: "{{ gpu_type.rc == 0 | ternary(''PASS'', ''FAIL'') }}"
      notes: "Exit code {{ gpu_type.rc }}"

- name: Append GPU Type result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''gpu'': test_results.gpu + [gpu_type_result]}, recursive=True) }}"
'

# Role: check_ethernet
create_task_file "check_ethernet" \
'---
- name: Get Ethernet Links
  ansible.builtin.command: ip -br a
  register: ip_links
  changed_when: false
  failed_when: false

- name: Create Ethernet Links result object
  ansible.builtin.set_fact:
    ethernet_links_result:
      name: "Ethernet Links"
      command: "ip -br a"
      result: "{{ ip_links.stdout }}"
      status: "PASS"
      notes: ""

- name: Append Ethernet Links result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''ethernet'': test_results.ethernet + [ethernet_links_result]}, recursive=True) }}"
'

# Role: check_infiniband
create_task_file "check_infiniband" \
'---
- name: Check for ibstatus command
  ansible.builtin.command: ibstatus
  register: ib_status
  changed_when: false
  failed_when: false

- name: Create IB Links result object
  ansible.builtin.set_fact:
    ib_links_result:
      name: "IB Links Speed"
      command: "ibstatus"
      result: "{{ ib_status.rc != 0 | ternary(ib_status.stderr if ib_status.stderr else ib_status.stdout, ib_status.stdout) }}"
      status: "{{ ib_status.rc == 0 | ternary(''PASS'', ''FAIL'') }}"
      notes: "Exit code {{ ib_status.rc }}"

- name: Append IB Links result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''infiniband'': test_results.infiniband + [ib_links_result]}, recursive=True) }}"
'

# Role: check_security
create_task_file "check_security" \
'---
- name: Get /etc/passwd content
  ansible.builtin.slurp:
    src: /etc/passwd
  register: passwd_file
  failed_when: not passwd_file.content

- name: Create /etc/passwd result object
  ansible.builtin.set_fact:
    passwd_result:
      name: "/etc/passwd"
      command: "cat /etc/passwd"
      result: "{{ passwd_file.content | b64decode }}"
      status: "PASS"
      notes: ""

- name: Append /etc/passwd result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''security'': test_results.security + [passwd_result]}, recursive=True) }}"
'

# Role: check_network_speed
create_task_file "check_network_speed" \
'---
- name: Run speedtest-cli for each server
  ansible.builtin.command: "speedtest-cli --server {{ item.server_id }} --simple"
  register: speedtest_results
  loop: "{{ speed_test_servers }}"
  changed_when: false
  failed_when: false

- name: Format and append speedtest results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({''network_speed'': test_results.network_speed + [
        {
          ''name'': item.item.desc,
          ''command'': ''speedtest-cli --server '' ~ item.item.server_id ~ '' --simple'',
          ''result'': item.rc != 0 | ternary(item.stderr, item.stdout),
          ''status'': item.rc == 0 | ternary(''PASS'', ''FAIL''),
          ''notes'': ''''
        }
      ]
    }, recursive=True) }}"
  loop: "{{ speedtest_results.results }}"
'

echo "✅ All done. Your corrected Ansible project is ready in the 'ansible_health_check' directory."
