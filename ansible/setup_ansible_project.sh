#!/bin/bash
# setup_ansible_project.sh (v6 - Final Version with all fixes)
# This script creates the directory structure and files for the Ansible health check playbook.

echo "🚀 Creating Ansible project directories..."
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
# Example: Define network speed test servers
speed_test_servers:
  - { desc: "Speedtest Nearby", server_id: "14679" }
  - { desc: "Speedtest Europe", server_id: "14679" }
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
          software: []
          services: []

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
    - { role: check_software, when: run_software_check | default(false) | bool }
    - { role: check_services, when: run_services_check | default(false) | bool }

  post_tasks:
    - name: Generate HTML report from template
      ansible.builtin.template:
        src: templates/report.html.j2
        dest: "reports/system_test_report_{{ ansible_hostname }}_{{ ansible_date_time.iso8601 }}.html"
      delegate_to: localhost
      run_once: true
EOL

# Create the HTML report template
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
        .search { width: 100%; box-sizing: border-box; padding: 0.5rem 0.75rem; margin: 0.5rem 0 0.75rem 0; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-color); color: var(--text-color); }
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
            'Network Speed Tests': test_results.network_speed, 'Software & Packages': test_results.software, 'Services & Mounts': test_results.services
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
    <script>
      function filterTable(inputId, tableId){
        const input = document.getElementById(inputId);
        const table = document.getElementById(tableId);
        if(!input || !table) return;
        const q = input.value.toLowerCase();
        const rows = table.querySelectorAll('tbody tr');
        rows.forEach(tr => {
          const txt = tr.textContent.toLowerCase();
          tr.style.display = txt.includes(q) ? '' : 'none';
        });
      }
    </script>
</body>
</html>
EOL

# Create role directories
ROLES=("check_system" "check_cpu" "check_ram" "check_storage" "check_gpu" "check_ethernet" "check_infiniband" "check_security" "check_network_speed" "check_software" "check_services")
for role in "${ROLES[@]}"; do
    echo "⚙️  Creating role: ${role}"
    mkdir -p "ansible_health_check/roles/${role}/tasks"
done

echo "✍️ Writing task files for all roles..."

# --- Role Task Files ---

cat > ansible_health_check/roles/check_system/tasks/main.yml << 'EOL'
---
- name: Get OS Version
  ansible.builtin.shell: "grep PRETTY_NAME /etc/os-release | cut -d '\"' -f 2"
  register: os_version
  changed_when: false
  failed_when: false
- name: Get System Name
  ansible.builtin.command: cat /sys/devices/virtual/dmi/id/product_name
  register: system_name
  changed_when: false
  failed_when: false
- name: Get Full OS Version (lsb_release)
  ansible.builtin.command: lsb_release -a
  register: lsb_release_full
  changed_when: false
  failed_when: false
- name: Create System result objects
  ansible.builtin.set_fact:
    system_name_result:
      name: "System Name"
      command: "cat /sys/devices/virtual/dmi/id/product_name"
      result: "{{ system_name.stdout | trim }}"
      status: "{{ (system_name.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    os_version_result:
      name: "OS Version"
      command: "grep PRETTY_NAME /etc/os-release | cut -d '\"' -f 2"
      result: "{{ os_version.stdout | trim }}"
      status: "{{ (os_version.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    lsb_release_result:
      name: "OS Full Version (lsb_release -a)"
      command: "lsb_release -a"
      result: "{{ lsb_release_full.stdout | trim }}"
      status: "{{ (lsb_release_full.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
- name: Append all System results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'system': test_results.system + [system_name_result, os_version_result, lsb_release_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_cpu/tasks/main.yml << 'EOL'
---
- name: Get all CPU Information with lscpu
  ansible.builtin.command: lscpu
  register: lscpu_output
  changed_when: false
  failed_when: false
- name: Get CPU Core Count
  ansible.builtin.shell: "lscpu | grep -E '^(Socket|Core)' | tr '\\n' ' ' | sed 's/  */ /g'"
  register: core_count
  changed_when: false
  failed_when: false
- name: Get NUMA Configuration
  ansible.builtin.shell: "lscpu | grep 'NUMA node' | tr '\\n' ' ' | sed 's/  */ /g'"
  register: numa_config
  changed_when: false
  failed_when: false
- name: Create CPU result objects
  ansible.builtin.set_fact:
    cpu_model_result:
      name: "CPU Model"
      command: "lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//'"
      result: "{{ lscpu_output.stdout | regex_search('Model name:\\s+(.+)', '\\1') | first | trim }}"
      status: "{{ (lscpu_output.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    core_count_result:
      name: "CPU Core Count"
      command: "lscpu | grep -E '^(Socket|Core)' | tr '\\n' ' ' | sed 's/  */ /g'"
      result: "{{ core_count.stdout | trim }}"
      status: "{{ (core_count.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    numa_config_result:
      name: "NUMA Configuration"
      command: "lscpu | grep 'NUMA node' | tr '\\n' ' ' | sed 's/  */ /g'"
      result: "{{ numa_config.stdout | trim }}"
      status: "{{ (numa_config.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    lscpu_summary_result:
      name: "lscpu Summary"
      command: "lscpu"
      result: "<details><summary>Show lscpu output</summary><pre>{{ lscpu_output.stdout }}</pre></details>"
      status: "{{ (lscpu_output.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Basic lscpu output"
- name: Append all CPU results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'cpu': test_results.cpu + [cpu_model_result, core_count_result, numa_config_result, lscpu_summary_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_ram/tasks/main.yml << 'EOL'
---
- name: Create RAM Size result object
  ansible.builtin.set_fact:
    ram_size_result:
      name: "RAM Size"
      command: "ansible_facts.memtotal_mb"
      result: "{{ (ansible_facts.memtotal_mb / 1024) | round(0, 'ceil') }}Gi"
      status: "PASS"
      notes: ""
- name: Append RAM Size result
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'ram': test_results.ram + [ram_size_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_storage/tasks/main.yml << 'EOL'
---
- name: Get block device information
  ansible.builtin.command: lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS
  register: lsblk_output
  changed_when: false
  failed_when: false
- name: Create Storage result objects
  ansible.builtin.set_fact:
    block_devices_result:
      name: "Block Devices"
      command: "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS"
      result: "{{ lsblk_output.stdout }}"
      status: "{{ (lsblk_output.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    lsblk_overview_result:
      name: "lsblk Overview"
      command: "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS"
      result: "<details><summary>Show lsblk output</summary><pre>{{ lsblk_output.stdout }}</pre></details>"
      status: "{{ (lsblk_output.rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Full lsblk output"
    fs_usage_result:
      name: "Filesystem Usage"
      command: "df -h (from ansible_facts.mounts)"
      result: |
        {% for mount in ansible_facts.mounts -%}
        {{ mount.device }} {{ mount.size_total | human_readable }} {{ (mount.size_total - mount.size_available) | human_readable }} {{ mount.size_available | human_readable }} {{ (((mount.size_total - mount.size_available) / mount.size_total) * 100) | round(0) }}% {{ mount.mount }}
        {% endfor %}
      status: "PASS"
      notes: ""
- name: Append all Storage results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'storage': test_results.storage + [block_devices_result, lsblk_overview_result, fs_usage_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_gpu/tasks/main.yml << 'EOL'
---
- name: Run all GPU-related commands
  ansible.builtin.shell: "{{ item.cmd }}"
  register: gpu_command_results
  loop:
    - { name: "gpu_type", cmd: "nvidia-smi --query-gpu=gpu_name --format=csv,noheader" }
    - { name: "gpu_vram", cmd: "nvidia-smi --query-gpu=memory.total --format=csv" }
    - { name: "peermem", cmd: "lsmod | grep -i nvidia_peermem" }
    - { name: "nvfabric", cmd: "nv-fabricmanager --version" }
    - { name: "nvlink", cmd: "nvidia-smi nvlink -s" }
    - { name: "nvidia_smi_full", cmd: "nvidia-smi" }
  changed_when: false
  failed_when: false
- name: Create all GPU result objects
  ansible.builtin.set_fact:
    gpu_type_result:
      name: "GPU Type"
      command: "{{ gpu_command_results.results[0].item.cmd }}"
      result: "{{ gpu_command_results.results[0].stdout if gpu_command_results.results[0].rc == 0 else (gpu_command_results.results[0].stderr if gpu_command_results.results[0].stderr else 'Command not found') }}"
      status: "{{ (gpu_command_results.results[0].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ gpu_command_results.results[0].rc }}"
    gpu_vram_result:
      name: "VRAM per GPU"
      command: "{{ gpu_command_results.results[1].item.cmd }}"
      result: "{{ gpu_command_results.results[1].stdout if gpu_command_results.results[1].rc == 0 else (gpu_command_results.results[1].stderr if gpu_command_results.results[1].stderr else 'Command not found') }}"
      status: "{{ (gpu_command_results.results[1].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ gpu_command_results.results[1].rc }}"
    peermem_result:
      name: "NVIDIA Peermem"
      command: "{{ gpu_command_results.results[2].item.cmd }}"
      result: "{{ gpu_command_results.results[2].stdout if gpu_command_results.results[2].rc == 0 else 'Module not loaded' }}"
      status: "{{ (gpu_command_results.results[2].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ gpu_command_results.results[2].rc }}"
    nvfabric_result:
      name: "NVLink Fabric Manager"
      command: "{{ gpu_command_results.results[3].item.cmd }}"
      result: "{{ gpu_command_results.results[3].stdout if gpu_command_results.results[3].rc == 0 else (gpu_command_results.results[3].stderr if gpu_command_results.results[3].stderr else 'Command not found') }}"
      status: "{{ (gpu_command_results.results[3].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ gpu_command_results.results[3].rc }}"
    nvlink_result:
      name: "NVLink Status"
      command: "{{ gpu_command_results.results[4].item.cmd }}"
      result: "{{ gpu_command_results.results[4].stdout if gpu_command_results.results[4].rc == 0 else (gpu_command_results.results[4].stderr if gpu_command_results.results[4].stderr else 'Command not found') }}"
      status: "{{ (gpu_command_results.results[4].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ gpu_command_results.results[4].rc }}"
    driver_version_result:
      name: "Driver Version"
      command: "nvidia-smi | grep -i 'Driver Version'"
      result: "{{ gpu_command_results.results[5].stdout | regex_search('Driver Version:\\s*([0-9.]+)') | default('Not found') }}"
      status: "{{ ('Driver Version:' in gpu_command_results.results[5].stdout) | ternary('PASS', 'FAIL') }}"
      notes: ""
    nvidia_smi_full_result:
      name: "nvidia-smi Full Output"
      command: "{{ gpu_command_results.results[5].item.cmd }}"
      result: "<details><summary>Show nvidia-smi output</summary><pre>{{ gpu_command_results.results[5].stdout if gpu_command_results.results[5].rc == 0 else (gpu_command_results.results[5].stderr if gpu_command_results.results[5].stderr else 'Command not found') }}</pre></details>"
      status: "{{ (gpu_command_results.results[5].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ gpu_command_results.results[5].rc }}"
- name: Append all GPU results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'gpu': test_results.gpu + [gpu_type_result, gpu_vram_result, peermem_result, nvfabric_result, nvlink_result, driver_version_result, nvidia_smi_full_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_ethernet/tasks/main.yml << 'EOL'
---
- name: Run general Ethernet-related commands
  ansible.builtin.shell: "{{ item.cmd }}"
  register: eth_commands
  loop:
    - { name: "nics", cmd: "lshw -C network -short" }
    - { name: "links", cmd: "ip -br a" }
    - { name: "ips", cmd: "ip -o addr show primary scope global | awk '{print $2, $3, $4}'" }
    - { name: "bond_speed", cmd: "ethtool bond0" }
    - { name: "bond_type", cmd: "cat /proc/net/bonding/bond0" }
  changed_when: false
  failed_when: false
- name: Check ethtool link speed for each active interface
  ansible.builtin.command: "ethtool {{ item }}"
  register: ethtool_results
  loop: "{{ ansible_facts.interfaces | difference(['lo']) }}"
  changed_when: false
  failed_when: false
- name: Create Ethernet result objects
  ansible.builtin.set_fact:
    ethernet_nics_result:
      name: "Ethernet NICs"
      command: "{{ eth_commands.results[0].item.cmd }}"
      result: "{{ eth_commands.results[0].stdout }}"
      status: "{{ (eth_commands.results[0].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    ethernet_links_result:
      name: "Ethernet Links"
      command: "{{ eth_commands.results[1].item.cmd }}"
      result: "{{ eth_commands.results[1].stdout }}"
      status: "PASS"
      notes: ""
    all_ips_result:
      name: "All IP Addresses (IPv4 & IPv6)"
      command: "{{ eth_commands.results[2].item.cmd }}"
      result: "{{ eth_commands.results[2].stdout }}"
      status: "{{ (eth_commands.results[2].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    link_speed_result:
      name: "Link Speed Check"
      command: "ethtool <each iface>"
      result: |
        {% for result in ethtool_results.results -%}
        {{ result.item }}: {{ result.stdout | regex_search('Speed: (.*)') | default('Speed: Unknown') }}
        {% endfor %}
      status: "PASS"
      notes: "No minimum threshold configured"
    bond_speed_result:
      name: "Bond Speed"
      command: "{{ eth_commands.results[3].item.cmd }}"
      result: "{{ eth_commands.results[3].stdout if eth_commands.results[3].rc == 0 else 'Device not found' }}"
      status: "{{ (eth_commands.results[3].rc == 0) | ternary('PASS', 'PARTIAL') }}"
      notes: "{{ '' if (eth_commands.results[3].rc == 0) else 'bond0 not present' }}"
    bond_type_result:
      name: "Bond Type"
      command: "{{ eth_commands.results[4].item.cmd }}"
      result: "{{ eth_commands.results[4].stdout if eth_commands.results[4].rc == 0 else 'Device not found' }}"
      status: "{{ (eth_commands.results[4].rc == 0) | ternary('PASS', 'PARTIAL') }}"
      notes: "{{ '' if (eth_commands.results[4].rc == 0) else 'bond0 not present' }}"
- name: Append all Ethernet results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'ethernet': test_results.ethernet + [ethernet_nics_result, ethernet_links_result, all_ips_result, link_speed_result, bond_speed_result, bond_type_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_infiniband/tasks/main.yml << 'EOL'
---
- name: Run InfiniBand-related commands
  ansible.builtin.shell: "{{ item.cmd }}"
  register: ib_commands
  loop:
    - { name: "speed", cmd: "ibstatus | grep -e 'rate:' -e 'device'" }
    - { name: "status", cmd: "ibstatus | grep -e 'link_layer:' -e 'phys state:'" }
    - { name: "ofed", cmd: "ofed_info -s" }
    - { name: "iboip", cmd: "ibdev2netdev" }
    - { name: "fabric", cmd: "iblinkinfo --switches-only" }
  changed_when: false
  failed_when: false
- name: Create InfiniBand result objects
  ansible.builtin.set_fact:
    ib_speed_result:
      name: "IB Links Speed"
      command: "{{ ib_commands.results[0].item.cmd }}"
      result: "{{ ib_commands.results[0].stdout if ib_commands.results[0].rc == 0 else (ib_commands.results[0].stderr if ib_commands.results[0].stderr else 'Command not found') }}"
      status: "{{ (ib_commands.results[0].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ ib_commands.results[0].rc }}"
    ib_status_result:
      name: "IB Links Status"
      command: "{{ ib_commands.results[1].item.cmd }}"
      result: "{{ ib_commands.results[1].stdout if ib_commands.results[1].rc == 0 else (ib_commands.results[1].stderr if ib_commands.results[1].stderr else 'Command not found') }}"
      status: "{{ (ib_commands.results[1].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ ib_commands.results[1].rc }}"
    ofed_result:
      name: "OFED Version"
      command: "{{ ib_commands.results[2].item.cmd }}"
      result: "{{ ib_commands.results[2].stdout if ib_commands.results[2].rc == 0 else (ib_commands.results[2].stderr if ib_commands.results[2].stderr else 'Command not found') }}"
      status: "{{ (ib_commands.results[2].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ ib_commands.results[2].rc }}"
    iboip_result:
      name: "IBoIP Enabled"
      command: "{{ ib_commands.results[3].item.cmd }}"
      result: "{{ ib_commands.results[3].stdout if ib_commands.results[3].rc == 0 else (ib_commands.results[3].stderr if ib_commands.results[3].stderr else 'Command not found') }}"
      status: "{{ (ib_commands.results[3].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ ib_commands.results[3].rc }}"
    fabric_result:
      name: "IB Fabric"
      command: "{{ ib_commands.results[4].item.cmd }}"
      result: "{{ ib_commands.results[4].stdout if ib_commands.results[4].rc == 0 else (ib_commands.results[4].stderr if ib_commands.results[4].stderr else 'Command not found') }}"
      status: "{{ (ib_commands.results[4].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ ib_commands.results[4].rc }}"
- name: Append all InfiniBand results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'infiniband': test_results.infiniband + [ib_speed_result, ib_status_result, ofed_result, iboip_result, fabric_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_security/tasks/main.yml << 'EOL'
---
- name: Get /etc/passwd content
  ansible.builtin.slurp:
    src: /etc/passwd
  register: passwd_file
  failed_when: not passwd_file.content
- name: Get /etc/shadow content
  ansible.builtin.slurp:
    src: /etc/shadow
  register: shadow_file
  become: true
  failed_when: not shadow_file.content
- name: Find all SSH key files
  ansible.builtin.find:
    paths:
      - /root/.ssh
      - /home/
    patterns: "authorized_keys,*.pub,id_*"
    recurse: true
    file_type: file
  register: ssh_files
- name: Get stats for each SSH key file
  ansible.builtin.stat:
    path: "{{ item.path }}"
  loop: "{{ ssh_files.files }}"
  register: ssh_stat_results
- name: Get fingerprints for each SSH key file
  ansible.builtin.shell: |
    set -e
    fingerprint="N/A"
    if [[ "{{ item.path }}" == *.pub ]] || [[ "{{ item.path }}" == *authorized_keys ]]; then
      fingerprint=$(ssh-keygen -lf "{{ item.path }}" | awk '{print $1, $2, $3}' | tr -d '\\n' | sed 's/SHA256:/\\nSHA256:/g' | sed '/^$/d' || echo "Invalid key format")
    fi
    echo "fingerprint=${fingerprint}"
  args:
    executable: /bin/bash
  register: ssh_fingerprints
  loop: "{{ ssh_files.files }}"
  changed_when: false
- name: Get list of MOTD files
  ansible.builtin.find:
    paths: /etc/update-motd.d
    file_type: file
  register: motd_files
- name: Slurp content of MOTD files
  ansible.builtin.slurp:
    src: "{{ item.path }}"
  loop: "{{ motd_files.files }}"
  register: motd_contents
- name: Create Security & Accounts result objects
  ansible.builtin.set_fact:
    motd_result:
      name: "MOTD"
      command: "cat /etc/motd; ls /etc/update-motd.d"
      result: |
        <details><summary>Show MOTD files and contents</summary>
        <div class="banner">Multiple MOTD fragments detected ({{ motd_files.files | length }} files)</div>
        <div><strong>Files:</strong><ul>
        {% for file in motd_files.files %}<li>{{ file.path }}</li>{% endfor %}
        </ul></div>
        {% for content in motd_contents.results %}
        <div class="box"><div style="font-weight:600; color:#a9b1d6">{{ content.item.path }}</div><pre>{{ content.content | b64decode }}</pre></div>
        {% endfor %}
        </details>
      status: "PARTIAL"
      notes: "Multiple files"
    ssh_keys_result:
      name: "SSH Keys Audit"
      command: "find ~/.ssh /home/*/.ssh"
      result: |
        <details><summary>Show SSH key metadata (paths, perms, fingerprints)</summary>
        <table><thead><tr><th>Path</th><th>Type</th><th>Perms</th><th>Owner</th><th>Fingerprint</th></tr></thead><tbody>
        {% for file in ssh_files.files %}
        <tr><td>{{ file.path }}</td><td>{{ 'private' if 'id_' in file.path and not file.path.endswith('.pub') else 'public' }}</td><td>{{ ssh_stat_results.results[loop.index0].stat.mode }}</td><td>{{ ssh_stat_results.results[loop.index0].stat.pw_name }}:{{ ssh_stat_results.results[loop.index0].stat.gr_name }}</td><td><pre>{{ ssh_fingerprints.results[loop.index0].stdout | regex_replace('fingerprint=') }}</pre></td></tr>
        {% endfor %}
        </tbody></table><div style="margin-top:4px;color:#a9b1d6">Key contents are intentionally redacted</div></details>
      status: "PARTIAL"
      notes: "Metadata only; contents redacted"
    passwd_result:
      name: "/etc/passwd"
      command: "cat /etc/passwd"
      result: "<details><summary>Show /etc/passwd</summary><pre>{{ passwd_file.content | b64decode }}</pre></details>"
      status: "PASS"
      notes: ""
    shadow_result:
      name: "/etc/shadow (redacted)"
      command: "analyzed"
      result: |
        <div class="disk-chips">
        {% for account in accounts_with_passwords %}<span class="disk-chip">{{ account }}</span>{% endfor %}
        </div>
        <details><summary>Show shadow account status (redacted)</summary><pre>
        {%- for line in (shadow_file.content | b64decode).split('\n') -%}
        {%- if line -%}
        {{- line.split(':')[0] }}: {{ 'password set' if not line.split(':')[1] in ['!', '*'] else 'locked' }}
        {%- endif -%}
        {%- endfor -%}
        </pre></details>
      status: "PASS"
      notes: "{{ accounts_with_passwords | length }} account(s) with passwords set"
    home_dirs_result:
      name: "Home Directories"
      command: "ls /home and /etc/passwd"
      result: |
        <details><summary>/home directory listing</summary>
        </details>
        <details><summary>Home directories parsed from /etc/passwd</summary><table><thead><tr><th>Path</th></tr></thead><tbody>
        {% for path in (passwd_file.content | b64decode).split('\n') | map('regex_replace', '^.*?:.*?:.*?:.*?:.*?:(.*?):.*$', '\\1') | unique | sort %}
        {% if path %}<tr><td>{{ path }}</td></tr>{% endif %}
        {% endfor %}
        </tbody></table></details>
      status: "PASS"
      notes: ""
  vars:
    accounts_with_passwords: >-
      {%- set accounts = [] -%}
      {%- for line in (shadow_file.content | b64decode).split('\n') -%}
        {%- if line and not line.split(':')[1] in ['!', '*'] -%}
          {%- set _ = accounts.append(line.split(':')[0]) -%}
        {%- endif -%}
      {%- endfor -%}
      {{- accounts -}}
- name: Append all Security results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'security': test_results.security + [motd_result, ssh_keys_result, passwd_result, shadow_result, home_dirs_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_software/tasks/main.yml << 'EOL'
---
- name: Run software and package commands
  ansible.builtin.shell: "{{ item.cmd }}"
  register: software_commands
  loop:
    - { name: "ps", cmd: "ps axfcu" }
    - { name: "dpkg", cmd: "dpkg-query -W" }
    - { name: "manual", cmd: "apt-mark showmanual | sort" }
  changed_when: false
  failed_when: false
- name: Create Software & Packages result objects
  ansible.builtin.set_fact:
    process_list_result:
      name: "Process List"
      command: "ps axfcu"
      result: "<details><summary>Show process list (ps axfcu)</summary><pre>{{ software_commands.results[0].stdout }}</pre></details>"
      status: "PASS"
      notes: ""
    installed_packages_result:
      name: "Installed Packages"
      command: "dpkg-query -W"
      result: |
        <details><summary>Installed Packages</summary><div><input class="search" id="pkgFilter" placeholder="Filter packages..." oninput="filterTable('pkgFilter','pkgTable')"></div>
        <table id="pkgTable"><thead><tr><th>Package</th><th>Version</th></tr></thead><tbody>
        {% for line in software_commands.results[1].stdout_lines %}
        <tr><td>{{ line.split()[0] }}</td><td>{{ line.split()[1] }}</td></tr>
        {% endfor %}
        </tbody></table></details>
      status: "PASS"
      notes: "Package and version"
    manual_packages_result:
      name: "Manually installed software"
      command: "apt-mark showmanual | sort"
      result: |
        <details><summary>Manually installed software</summary><div><input class="search" id="manFilter" placeholder="Filter manual packages..." oninput="filterTable('manFilter','manTable')"></div>
        <table id="manTable"><thead><tr><th>Package</th></tr></thead><tbody>
        {% for line in software_commands.results[2].stdout_lines %}
        <tr><td>{{ line }}</td></tr>
        {% endfor %}
        </tbody></table></details>
      status: "PASS"
      notes: "From apt-mark showmanual"
- name: Append all Software results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'software': test_results.software + [process_list_result, installed_packages_result, manual_packages_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_services/tasks/main.yml << 'EOL'
---
- name: Run service and mount commands
  ansible.builtin.shell: "{{ item.cmd }}"
  register: service_commands
  loop:
    - { name: "ssh", cmd: "systemctl status sshd | grep 'Active:' | sed 's/^[ \\t]*//'" }
    - { name: "ipmi", cmd: "ipmitool lan print" }
    - { name: "nfs", cmd: "mount | grep nfs" }
  changed_when: false
  failed_when: false
- name: Create Services & Mounts result objects
  ansible.builtin.set_fact:
    ssh_result:
      name: "SSH Access"
      command: "systemctl status sshd | grep 'Active:' | sed 's/^[ \\t]*//'"
      result: "{{ service_commands.results[0].stdout }}"
      status: "{{ (service_commands.results[0].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: ""
    ipmi_result:
      name: "IPMI Access"
      command: "ipmitool lan print"
      result: "{{ service_commands.results[1].stdout if service_commands.results[1].rc == 0 else service_commands.results[1].stderr }}"
      status: "{{ (service_commands.results[1].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ service_commands.results[1].rc }}"
    nfs_result:
      name: "NFS Mounts"
      command: "mount | grep nfs"
      result: "{{ service_commands.results[2].stdout | default('No NFS mounts found.', true) }}"
      status: "{{ (service_commands.results[2].rc == 0) | ternary('PASS', 'FAIL') }}"
      notes: "Exit code {{ service_commands.results[2].rc }}"
- name: Append all Services results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'services': test_results.services + [ssh_result, ipmi_result, nfs_result]}, recursive=True) }}"
EOL

cat > ansible_health_check/roles/check_network_speed/tasks/main.yml << 'EOL'
---
- name: Run speedtest-cli for each server
  ansible.builtin.command: "speedtest-cli --server {{ item.server_id }} --simple"
  register: speedtest_results
  loop: "{{ speed_test_servers }}"
  changed_when: false
  failed_when: false
- name: Format and append speedtest results
  ansible.builtin.set_fact:
    test_results: "{{ test_results | combine({'network_speed': test_results.network_speed + [
        {
          'name': item.item.desc,
          'command': 'speedtest-cli --server ' ~ item.item.server_id ~ ' --simple',
          'result': item.stdout if item.rc == 0 else item.stderr,
          'status': (item.rc == 0) | ternary('PASS', 'FAIL'),
          'notes': ''
        }
      ]
    }, recursive=True) }}"
  loop: "{{ speedtest_results.results }}"
EOL

echo "✅ All done. Your final, corrected Ansible project is ready in the 'ansible_health_check' directory."
