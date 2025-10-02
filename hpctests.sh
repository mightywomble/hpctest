#!/bin/bash

# ==============================================================================
#
# System Hardware & Performance Test Script
#
# Description:
#   This script automates a series of system checks, providing verbose
#   real-time feedback. The results are compiled into a single, self-contained,
#   and styled HTML report file.
#
# Usage:
#   - Standard run (interactive):
#     'sudo ./hpctests.sh'
#   - Headless (auto-yes to prompts; installs allowed):
#     'sudo ./hpctests.sh --headless'
#   - Skip Docker benchmarks:
#     'sudo ./hpctests.sh --noburn'
#   - Do not install missing software (also skips benchmarks), still run tests and generate report:
#     'sudo ./hpctests.sh --noinstall'
#   - Legacy automated mode (skip prompts; run all tests):
#     'sudo ./hpctests.sh --nocheck'
#   - Help:
#     'sudo ./hpctests.sh --help'
#
# ==============================================================================

# --- Globals and Configuration ---
readonly SCRIPT_NAME=$(basename "$0")
readonly TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
readonly FILENAME_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
readonly OUTPUT_FILE="system_test_report_${FILENAME_TIMESTAMP}.html"
NOCHECK_MODE=false # This flag will be set to true if --nocheck is passed
HEADLESS_MODE=false  # Auto-yes to prompts; still performs installs unless --noinstall
NOINSTALL_MODE=false # Do not install missing software; still run tests and generate report
NOBURN_MODE=false    # Skip Docker-based benchmark tests (HPL/GPU-burn)

# Host identification (best-effort)
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)
PRIMARY_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if ($i=="src"){print $(i+1); exit}}')
if [[ -z "$PRIMARY_IP" ]]; then
    # Fallback to first global IPv4
    PRIMARY_IP=$(ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}' | head -n1 | cut -d'/' -f1)
fi

# Thresholds and Speedtest server pins (configurable via env)
MIN_LINK_SPEED_MBPS=${MIN_LINK_SPEED_MBPS:-0}
MIN_DOWNLOAD_MBPS=${MIN_DOWNLOAD_MBPS:-0}
MIN_UPLOAD_MBPS=${MIN_UPLOAD_MBPS:-0}
SPEEDTEST_SERVER_NEARBY=${SPEEDTEST_SERVER_NEARBY:-}
SPEEDTEST_SERVER_EU=${SPEEDTEST_SERVER_EU:-}

# --- Color Codes for Verbose Console Output ---
readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'

# ==============================================================================
# Helper Functions
# ==============================================================================

log() {
    echo -e "${C_CYAN}[$(date +"%T")]${C_RESET} $1"
}

log_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

log_warn() {
    echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"
}

print_usage() {
    cat <<USAGE
Usage: sudo ./hpctests.sh [options]

Options:
  --headless   Run all tests non-interactively, defaulting "yes" to prompts (installs allowed).
  --noburn     Skip Docker-based benchmarks (HPL and GPU-burn). Tests still run; report generated.
  --noinstall  Do not install missing software or run burn tests. Tests still run; report generated.
  --nocheck    Legacy automated mode: skip dependency prompts and confirmations; run all tests.
  --help, -h   Show this help and exit.

Notes:
- --headless may be combined with --noburn (to skip benchmarks) or left alone to auto-run them.
- --noinstall implies no Docker installation and benchmarks are skipped.
USAGE
}

# --- HTML Report Generation Functions ---
initialize_html_report() {
    log "Initializing HTML report file: ${OUTPUT_FILE}"
    cat > "${OUTPUT_FILE}" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Test Report</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
        :root {
            --bg-color: #1a1b26;
            --card-color: #24283b;
            --text-color: #c0caf5;
            --header-color: #ffffff;
            --accent-color: #00bfff; /* DeepSkyBlue/Cyan accent */
            --border-color: #414868;
            --table-header-bg: #2e3452;
            --green: #34d399; /* pass */
            --yellow: #facc15; /* partial */
            --red: #f87171; /* fail */
        }
        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            margin: 0;
            padding: 2rem;
            font-size: 14px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: var(--card-color);
            border-radius: 12px;
            padding: 2rem;
            border: 1px solid var(--border-color);
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        .actions { text-align:center; margin-bottom: 1.5rem; }
        .btn { background: #2e3452; color: #c0caf5; border: 1px solid #414868; padding: 0.5rem 0.9rem; border-radius: 8px; cursor: pointer; font-weight: 600; }
        .btn:hover { filter: brightness(1.1); }
        .search { width: 100%; padding: 0.5rem 0.75rem; margin: 0.5rem 0 0.75rem 0; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-color); color: var(--text-color); }
        h1 {
            color: var(--header-color);
            text-align: center;
            border-bottom: 2px solid var(--accent-color);
            padding-bottom: 1rem;
            margin-bottom: 0.5rem;
            font-weight: 700;
        }
        .report-meta {
            text-align: center;
            margin-bottom: 1.5rem;
            font-size: 0.95rem;
            color: #7a82ac;
        }
        .report-host {
            text-align: center;
            margin-bottom: 2rem;
            font-size: 0.95rem;
            color: #a9b1d6;
        }
        details {
            background: var(--bg-color);
            border-radius: 8px;
            margin-bottom: 1rem;
            border: 1px solid var(--border-color);
            overflow: hidden;
        }
        summary {
            font-weight: 600;
            font-size: 1.2rem;
            padding: 1rem;
            cursor: pointer;
            color: var(--accent-color);
            background-color: var(--table-header-bg);
            list-style: none;
            display: flex;
            justify-content: space-between;
        }
        summary::-webkit-details-marker { display: none; }
        summary::after {
            content: '+';
            font-size: 1.5rem;
            transition: transform 0.2s;
        }
        details[open] summary::after {
            transform: rotate(45deg);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            table-layout: fixed; /* enforce fixed widths */
        }
        th, td {
            padding: 0.8rem 1rem;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
            vertical-align: top;
            overflow-wrap: anywhere;
            word-break: break-word;
        }
        pre { white-space: pre-wrap; word-break: break-word; }
        thead {
            background-color: var(--table-header-bg);
            color: #a9b1d6;
            font-weight: 600;
        }
        tbody tr:nth-child(even) {
            background-color: #2e345250;
        }
        thead th:nth-child(1) { width: 10%; }
        thead th:nth-child(2) { width: 30%; }
        thead th:nth-child(3) { width: 50%; }
        thead th:nth-child(4) { width: 10%; }
        td:nth-child(1) { width: 10%; font-weight: 600; color: #a9b1d6;}
        td:nth-child(2) { width: 30%; font-family: monospace; color: #e0af68; }
        td:nth-child(3) { width: 50%; white-space: pre-wrap; word-break: break-word; font-family: monospace; font-size: 0.85rem;}
        td:nth-child(4) { width: 10%; }
        .status-badge { display: inline-block; padding: 0.2rem 0.5rem; border-radius: 9999px; font-weight: 600; font-size: 0.8rem; }
        .status-pass { background: rgba(52,211,153,0.15); color: var(--green); border: 1px solid rgba(52,211,153,0.4); }
        .status-partial { background: rgba(250,204,21,0.15); color: var(--yellow); border: 1px solid rgba(250,204,21,0.4); }
        .status-fail { background: rgba(248,113,113,0.15); color: var(--red); border: 1px solid rgba(248,113,113,0.4); }
        .status-notes { display:block; margin-top:0.25rem; font-size: 0.8rem; color: #a9b1d6; white-space: pre-wrap; }
        .disk-chips { margin-bottom: 0.5rem; }
        .disk-chip { display:inline-block; margin: 0 0.25rem 0.25rem 0; padding: 0.15rem 0.5rem; border-radius: 6px; background: #2e3452; color: #e0af68; border: 1px solid #414868; font-size: 0.8rem; }
        .footer {
            text-align: center;
            margin-top: 2rem;
            font-size: 0.8rem;
            color: #7a82ac;
        }
        .banner { padding: 0.6rem 0.9rem; border: 1px dashed var(--yellow); background: rgba(250,204,21,0.08); color: var(--yellow); border-radius: 8px; margin-bottom: 0.6rem; font-weight: 600; }
        .box { border: 1px solid var(--border-color); border-radius: 8px; padding: 0.75rem; background: var(--bg-color); margin: 0.5rem 0; }
    </style>
    <script>
      function findRowByTestName(name){
        const rows = document.querySelectorAll('table tbody tr');
        for(const tr of rows){
          const td = tr.querySelector('td');
          if(!td) continue;
          const t = td.textContent.trim();
          if(t === name) return tr;
        }
        return null;
      }
      function getStatusFor(name){
        const tr = findRowByTestName(name);
        if(!tr) return {status:'', notes:''};
        const badge = tr.querySelector('.status-badge');
        const notesEl = tr.querySelector('.status-notes');
        return {status: badge?badge.textContent.trim():'', notes: notesEl?notesEl.textContent.trim():''};
      }
      function exportChecklistCSV(){
        const lines = [];
        lines.push(['Category','Item','Status','Notes']);
        // Network
        const near = getStatusFor('Speedtest Nearby');
        const eu = getStatusFor('Speedtest Europe');
        function aggStatus(arr){
          const vals = arr.map(x=>x.status);
          if(vals.some(v=>v==='FAIL')) return 'Fail';
          if(vals.some(v=>v==='PARTIAL')) return 'Partial';
          if(vals.some(v=>v==='PASS')) return 'Pass';
          return '';
        }
        const bwStatus = aggStatus([near,eu]);
        const bwNotes = ['Nearby: '+(near.status||'N/A'),'Europe: '+(eu.status||'N/A')].join(' | ');
        lines.push(['Network','Internet bandwidth',bwStatus,bwNotes]);
        // Software
        const osv = getStatusFor('OS Full Version (lsb_release -a)');
        lines.push(['Software','OS version',osv.status||'',osv.notes||'']);
        const nvsmi = getStatusFor('nvidia-smi Full Output');
        const drver = getStatusFor('Driver Version');
        const nvidiaStatus = nvsmi.status || drver.status || '';
        const nvidiaNotes = nvsmi.notes || drver.notes || '';
        lines.push(['Software','NVIDIA software',nvidiaStatus,nvidiaNotes]);
        const cpuw = getStatusFor('HPL Single Node');
        lines.push(['Software','CPU test workload',cpuw.status||'',cpuw.notes||'']);
        const gpuw = getStatusFor('GPU Burn');
        lines.push(['Software','GPU test workload',gpuw.status||'',gpuw.notes||'']);
        // Hardware provider breadcrumbs
        const motd = getStatusFor('MOTD');
        lines.push(['Hardware provider breadcrumbs','Message of the day',motd.status||'',motd.notes||'']);
        // Server name is derived from header; mark Pass with value
        const hostEl = document.querySelector('.report-host');
        const hostTxt = hostEl?hostEl.textContent.replace('Hostname: ','').trim():'';
        lines.push(['Hardware provider breadcrumbs','Server name','Pass',hostTxt]);
        const authkeys = getStatusFor('SSH Keys Audit');
        lines.push(['Hardware provider breadcrumbs','authorized_keys',authkeys.status||'',authkeys.notes||'']);
        const passwd = getStatusFor('/etc/passwd');
        lines.push(['Hardware provider breadcrumbs','password file',passwd.status||'',passwd.notes||'See shadow row']);
        const shadow = getStatusFor('/etc/shadow (redacted)');
        lines.push(['Hardware provider breadcrumbs','password shadow',shadow.status||'',shadow.notes||'']);
        const homes = getStatusFor('Home Directories');
        lines.push(['Hardware provider breadcrumbs','home directories',homes.status||'',homes.notes||'']);
        const pkgs = getStatusFor('Installed Packages');
        lines.push(['Hardware provider breadcrumbs','all software',pkgs.status||'',pkgs.notes||'']);
        // Proprietary software requires manual triage
        lines.push(['Hardware provider breadcrumbs','proprietary software','Partial','Review manual packages/highlighted items']);

        const csv = lines.map(r=>r.map(x => '"' + String((x||'')).replace(/"/g,'""') + '"').join(',')).join('\\n');
        const blob = new Blob([csv],{type:'text/csv;charset=utf-8;'});
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'hpc_audit_checklist.csv';
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
      }
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
      function exportFullCSV(){
        const lines = [];
        lines.push(['Test','Command','Result','Status','Notes']);
        const tables = document.querySelectorAll('details > table');
        tables.forEach(tbl => {
          const firstHeader = tbl.querySelector('thead th');
          if(!firstHeader) return;
          if(firstHeader.textContent.trim() !== 'Test') return; // skip non-test tables (e.g., follow-up)
          const rows = tbl.querySelectorAll('tbody tr');
          rows.forEach(tr => {
            const tds = tr.querySelectorAll('td');
            if(tds.length < 3) return;
            const test = tds[0].textContent.trim();
            const cmd = tds[1].textContent.trim();
            const res = tds[2].textContent.trim();
            let status = '';
            let notes = '';
            const badge = tr.querySelector('.status-badge');
            const noteEl = tr.querySelector('.status-notes');
            if(badge) status = badge.textContent.trim();
            if(noteEl) notes = noteEl.textContent.trim();
            lines.push([test, cmd, res, status, notes]);
          });
        });
        const csv = lines.map(r=>r.map(x => '"' + String((x||'')).replace(/"/g,'""') + '"').join(',')).join('\\n');
        const blob = new Blob([csv],{type:'text/csv;charset=utf-8;'});
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'hpc_full_results.csv';
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
      }
    </script>
</head>
<body>
    <div class="container">
        <h1>System Hardware & Performance Report</h1>
        <div class="report-meta">Generated on: ${TIMESTAMP}</div>
        <div class="report-host">Hostname: ${HOSTNAME_FQDN:-Unknown} • Primary IP: ${PRIMARY_IP:-Unknown}</div>
        <div class="actions">
          <button class="btn" onclick="exportChecklistCSV()">Export Checklist CSV</button>
          <button class="btn" style="margin-left:8px" onclick="exportFullCSV()">Export Full Results CSV</button>
        </div>
EOF
    log_success "HTML report file initialized."
}

add_html_category_header() {
    local category="$1"
    cat >> "${OUTPUT_FILE}" << EOF
<details open>
    <summary>${category}</summary>
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
EOF
}

close_html_category_section() {
    cat >> "${OUTPUT_FILE}" << EOF
        </tbody>
    </table>
</details>
EOF
}

add_row_to_html_report() {
    local test_name="$1"
    local command="$2"
    local result="$3"
    local status_raw="${4:-N/A}"
    local notes_text="${5:-}"

    local status_lower=$(echo "$status_raw" | tr '[:upper:]' '[:lower:]')
    local status_class=""
    local status_label=""
    case "$status_lower" in
        pass)
            status_class="status-pass"; status_label="PASS";;
        partial)
            status_class="status-partial"; status_label="PARTIAL";;
        fail)
            status_class="status-fail"; status_label="FAIL";;
        *)
            status_class=""; status_label="";;
    esac

    local sanitized_cmd
    sanitized_cmd=$(echo "$command" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
    local sanitized_result
    sanitized_result=$(echo "$result" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')

    local status_cell=""
    if [[ -n "$status_label" ]]; then
        if [[ -n "$notes_text" ]]; then
            local sanitized_notes
            sanitized_notes=$(echo "$notes_text" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span><span class=\"status-notes\">${sanitized_notes}</span>"
        else
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span>"
        fi
    else
        status_cell=""
    fi

    echo "<tr><td>${test_name}</td><td>${sanitized_cmd}</td><td><pre>${sanitized_result}</pre></td><td>${status_cell}</td></tr>" >> "${OUTPUT_FILE}"
}

# When the result already contains safe HTML (e.g., <details> blocks), use this variant
add_row_to_html_report_html() {
    local test_name="$1"
    local command="$2"
    local result_html="$3"
    local status_raw="${4:-N/A}"
    local notes_text="${5:-}"

    local status_lower=$(echo "$status_raw" | tr '[:upper:]' '[:lower:]')
    local status_class=""
    local status_label=""
    case "$status_lower" in
        pass)
            status_class="status-pass"; status_label="PASS";;
        partial)
            status_class="status-partial"; status_label="PARTIAL";;
        fail)
            status_class="status-fail"; status_label="FAIL";;
        *)
            status_class=""; status_label="";;
    esac

    local sanitized_cmd
    sanitized_cmd=$(echo "$command" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')

    local status_cell=""
    if [[ -n "$status_label" ]]; then
        if [[ -n "$notes_text" ]]; then
            local sanitized_notes
            sanitized_notes=$(echo "$notes_text" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span><span class=\"status-notes\">${sanitized_notes}</span>"
        else
            status_cell="<span class=\"status-badge ${status_class}\">${status_label}</span>"
        fi
    else
        status_cell=""
    fi

    echo "<tr><td>${test_name}</td><td>${sanitized_cmd}</td><td>${result_html}</td><td>${status_cell}</td></tr>" >> "${OUTPUT_FILE}"
}

write_followup_section() {
    cat >> "${OUTPUT_FILE}" << EOF
<details>
  <summary>Follow-up Manual Checks</summary>
  <table>
    <thead>
      <tr>
        <th>Item</th>
        <th>Suggested Command</th>
        <th>Notes</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>CPU test workload (alternative)</td>
        <td><pre>stress-ng --cpu 0 --timeout 300s</pre></td>
        <td>Use if HPL is skipped or unavailable. Install: apt-get install stress-ng</td>
        <td></td>
      </tr>
      <tr>
        <td>GPU test workload (alternative)</td>
        <td><pre>nvidia-smi dmon -s pucm -o DT -f dmon.csv</pre></td>
        <td>Use alongside or instead of GPU-burn to observe utilization</td>
        <td></td>
      </tr>
      <tr>
        <td>authorized_keys review</td>
        <td><pre>grep -R --line-number '' /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys 2>/dev/null</pre></td>
        <td>Manually verify keys and permissions</td>
        <td></td>
      </tr>
      <tr>
        <td>All software export</td>
        <td><pre>dpkg -l | awk '{print $1"\t"$2"\t"$3"\t"$4}' &gt; packages.tsv</pre></td>
        <td>Generates a TSV inventory for deeper analysis</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</details>
EOF
}

finalize_html_report() {
    cat >> "${OUTPUT_FILE}" << EOF
    </div>
    <div class="footer">Script by System Test Automation</div>
</body>
</html>
EOF
    log_success "HTML report has been finalized."
}

run_test() {
    local category="$1"
    local test_name="$2"
    local cmd="$3"
    log "Running Test: ${C_YELLOW}${test_name}${C_RESET}..."
    log "  -> Command: ${cmd}"
    local result
    local exit_code
    result=$(eval "${cmd}" 2>&1); exit_code=$?
    local status="pass"
    local note=""
    if [[ $exit_code -ne 0 ]]; then
        status="fail"
        note="Exit code ${exit_code}"
        log_warn "  -> Command failed for '${test_name}' (exit ${exit_code})"
    elif [[ -z "$result" ]]; then
        status="partial"
        note="No output"
        log_warn "  -> No output received for '${test_name}'"
        result="No output"
    fi
    add_row_to_html_report "$test_name" "$cmd" "$result" "$status" "$note"
    log_success "  -> Test '${test_name}' complete."
    echo
}

# ==============================================================================
# Pre-flight Checks
# ==============================================================================
check_and_install_dependencies() {
    log "Checking for required command-line tools..."
    declare -A standard_packages
    standard_packages=(
        [lshw]="lshw" [ethtool]="ethtool" [ipmitool]="ipmitool"
        [ibstatus]="ibutils" [ibdev2netdev]="ibutils" [iblinkinfo]="ibutils"
        [speedtest-cli]="speedtest-cli" [lsb_release]="lsb-release" [ssh-keygen]="openssh-client"
    )
    declare -A complex_commands
    complex_commands=(
        [nvidia-smi]="NVIDIA drivers" [nv-fabricmanager]="NVIDIA Fabric Manager" [ofed_info]="Mellanox OFED drivers"
    )
    declare -A complex_command_instructions
    complex_command_instructions=(
        [nvidia-smi]="
    How to install:
      1. Visit the NVIDIA driver download page: https://www.nvidia.com/Download/index.aspx
      2. On Ubuntu, you can also use the 'Additional Drivers' utility or run: sudo ubuntu-drivers autoinstall"
        [nv-fabricmanager]="
    How to install:
      1. This tool is typically installed from the NVIDIA CUDA repository.
      2. E.g., for Ubuntu: sudo apt-get install nvidia-fabricmanager-535"
        [ofed_info]="
    How to install:
      1. Download the correct driver for your OS from the NVIDIA Networking website.
      2. Unpack and follow the installation guide (e.g., sudo ./mlnxofedinstall)"
    )
    local packages_to_install=()
    log "Scanning for missing standard packages..."
    for cmd in "${!standard_packages[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            local package=${standard_packages[$cmd]}
            if [[ ! " ${packages_to_install[@]} " =~ " ${package} " ]]; then
                packages_to_install+=("$package")
            fi
        fi
    done
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log_warn "The following standard packages appear to be missing:"
        for pkg in "${packages_to_install[@]}"; do echo -e "  - ${C_YELLOW}${pkg}${C_RESET}"; done; echo
        if $NOINSTALL_MODE; then
            log_warn "--noinstall specified: skipping installation of missing standard packages; tests may fail."
        else
            if $HEADLESS_MODE; then
                log "--headless specified: auto-installing missing standard packages via apt..."
                DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages_to_install[@]}" || { log_error "Package installation failed."; exit 1; }
            else
                read -p "Do you want to attempt to install them using 'apt'? (y/N): " choice
                if [[ "$choice" =~ ^[Yy]$ ]]; then
                    log "Updating and installing packages..."
                    apt-get update && apt-get install -y "${packages_to_install[@]}" || { log_error "Package installation failed."; exit 1; }
                else
                    log_warn "Continuing without installing missing standard packages; tests may fail."
                fi
            fi
        fi
    fi
    log "Scanning for complex drivers and tools..."
    local any_complex_missing=false
    for cmd in "${!complex_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            if ! $any_complex_missing; then
                log_warn "----------------------------------------------------------------"
                log_warn "ATTENTION: Manual installation required for the following:"
                any_complex_missing=true
            fi
            echo -e "\n  -> Missing: ${C_YELLOW}${complex_commands[$cmd]}${C_RESET} (command: ${C_YELLOW}${cmd}${C_RESET})"
            echo -e "${C_YELLOW}${complex_command_instructions[$cmd]}${C_RESET}"
        fi
    done
    if $any_complex_missing; then
        log_warn "\nTests for these components will report 'command not found'."
        log_warn "----------------------------------------------------------------"
        if $HEADLESS_MODE || $NOINSTALL_MODE; then
            log_warn "Auto-continuing due to --headless/--noinstall."
        else
            read -p "Do you want to continue with the tests? (Y/n): " continue_choice
            [[ "${continue_choice:-y}" =~ ^[Nn]$ ]] && { log_error "Aborting as requested."; exit 1; }
        fi
    fi
    log_success "Dependency check complete." && echo
}

# ==============================================================================
# Test Functions
# ==============================================================================

run_system_info_tests() {
    add_html_category_header "System"
    run_test "System" "System Name" "cat /sys/devices/virtual/dmi/id/product_name"
    run_test "System" "OS Version" "grep PRETTY_NAME /etc/os-release | cut -d '\"' -f 2"
    run_test "System" "OS Full Version (lsb_release -a)" "lsb_release -a"
    close_html_category_section
}

run_cpu_tests() {
    add_html_category_header "CPU"
    run_test "CPU" "CPU Model" "lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//'"
    run_test "CPU" "CPU Core Count" "lscpu | grep -E '^(Socket|Core)' | tr '\n' ' ' | sed 's/  */ /g'"
    run_test "CPU" "NUMA Configuration" "lscpu | grep 'NUMA node' | tr '\n' ' ' | sed 's/  */ /g'"

    # Collapsible lscpu summary
    local lscpu_out
    lscpu_out=$(lscpu 2>&1)
    local lscpu_sanitized
    lscpu_sanitized=$(echo "$lscpu_out" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
    local lscpu_html="<details><summary>Show lscpu output</summary><pre>${lscpu_sanitized}</pre></details>"
    add_row_to_html_report_html "lscpu Summary" "lscpu" "$lscpu_html" "pass" "Basic lscpu output"

    close_html_category_section
}

run_ram_tests() {
    add_html_category_header "RAM"
    run_test "RAM" "RAM Size" "free -h | grep Mem: | awk '{print \$2}'"
    close_html_category_section
}

run_nvme_tests() {
    add_html_category_header "NVMe Storage"
    run_test "NVMe" "Block Devices" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS"

    # Collapsible lsblk with disk highlights
    local disks_list
    disks_list=$(lsblk -dn -o NAME,SIZE,MODEL,TYPE 2>/dev/null | awk '$4=="disk" {print $1" ("$2") "$3}')
    local chips_html="<div class=\"disk-chips\">"
    local disk_status="pass"
    local disk_note="Disks highlighted above"
    if [[ -n "$disks_list" ]]; then
        while IFS= read -r line; do
            chips_html+="<span class=\"disk-chip\">${line}</span>"
        done <<< "$disks_list"
    else
        chips_html+="<span class=\"disk-chip\">No disks detected</span>"
        disk_status="fail"
        disk_note="No disks detected"
    fi
    chips_html+="</div>"

    local lsblk_out
    lsblk_out=$(lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS 2>&1)
    local lsblk_sanitized
    lsblk_sanitized=$(echo "$lsblk_out" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
    local lsblk_html="${chips_html}<details><summary>Show lsblk output</summary><pre>${lsblk_sanitized}</pre></details>"
    add_row_to_html_report_html "lsblk Overview" "lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS" "$lsblk_html" "$disk_status" "$disk_note"

    run_test "NVMe" "Filesystem Usage" "df -h"
    close_html_category_section
}

run_gpu_tests() {
    add_html_category_header "GPU"
    run_test "GPU" "GPU Type" "nvidia-smi --query-gpu=gpu_name --format=csv,noheader"
    run_test "GPU" "VRAM per GPU" "nvidia-smi --query-gpu=memory.total --format=csv"
    run_test "GPU" "NVIDIA Peermem" "lsmod | grep -i nvidia_peermem"
    run_test "GPU" "NVLink Fabric Manager" "nv-fabricmanager --version"
    run_test "GPU" "NVLink Status" "nvidia-smi nvlink -s"
    run_test "GPU" "Driver Version" "nvidia-smi | grep -i 'Driver Version'"

    if command -v nvidia-smi &> /dev/null; then
        local nsmi
        nsmi=$(nvidia-smi 2>&1)
        local nsmi_s
        nsmi_s=$(echo "$nsmi" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
        local nsmi_html="<details><summary>Show nvidia-smi output</summary><pre>${nsmi_s}</pre></details>"
        add_row_to_html_report_html "nvidia-smi Full Output" "nvidia-smi" "$nsmi_html" "pass" ""
    else
        add_row_to_html_report "nvidia-smi Full Output" "nvidia-smi" "nvidia-smi not installed" "partial" "Install NVIDIA drivers"
    fi

    close_html_category_section
}

# Helper: NIC info per IPv4 (driver, vendor, product)
nic_info_per_ipv4() {
  ip -o -4 addr show primary scope global | while read -r idx iface fam cidr rest; do
    ip_addr="${cidr}"
    drv=$(ethtool -i "$iface" 2>/dev/null | awk -F': ' '/driver/ {gsub(/^ +| +$/, "", $2); print $2}')
    ven=$(lshw -C network 2>/dev/null | awk -v IF="$iface" '$1=="logical"&&$2=="name:"&&$3==IF{f=1} f&&$1=="vendor:"{sub(/^vendor: /,""); print; exit}')
    prod=$(lshw -C network 2>/dev/null | awk -v IF="$iface" '$1=="logical"&&$2=="name:"&&$3==IF{f=1} f&&$1=="product:"{sub(/^product: /,""); print; exit}')
    echo "$iface ${ip_addr} driver=${drv:-unknown} vendor=${ven:-unknown} product=${prod:-unknown}"
  done
}

run_ethernet_tests() {
    add_html_category_header "Ethernet Network"
    run_test "Ethernet" "Ethernet NICs" "lshw -C network -short"
    run_test "Ethernet" "Ethernet Links" "ip -br a"

    # All IP addresses
    run_test "Ethernet" "All IP Addresses (IPv4 & IPv6)" "ip -o addr show primary scope global | awk '{print \$2, \$3, \$4}'"

    # NIC type per IP (IPv4) with vendor/product
    run_test "Ethernet" "NIC Type per IPv4" "nic_info_per_ipv4"

    # Link speed assertion against MIN_LINK_SPEED_MBPS (0 disables threshold)
    {
        local min=${MIN_LINK_SPEED_MBPS:-0}
        local overall_status="pass"
        local notes=""
        local lines=""
        mapfile -t ifaces < <(ip -o -4 addr show primary scope global | awk '{print $2}' | sort -u)
        if [[ ${#ifaces[@]} -eq 0 ]]; then
            lines+="No IPv4 interfaces with global scope found"
            overall_status="partial"
            notes="No interfaces"
        else
            for iface in "${ifaces[@]}"; do
                local raw
                raw=$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Speed/{print $2}')
                local spd
                spd=$(echo "$raw" | sed -E 's/[^0-9.]+//g')
                local entry
                if [[ -z "$spd" ]]; then
                    entry="$iface speed=unknown"
                    if (( min > 0 )); then overall_status="fail"; fi
                else
                    entry="$iface speed=${spd}Mb/s"
                    if (( min > 0 )) && (( ${spd%.*} < min )); then
                        overall_status="fail"
                        entry+=" (below ${min}Mb/s)"
                    fi
                fi
                lines+="$entry"$'\n'
            done
            if (( min == 0 )) && [[ "$overall_status" == "pass" ]]; then
                notes="No minimum threshold configured"
            else
                notes="Minimum: ${min} Mb/s"
            fi
        fi
        add_row_to_html_report "Link Speed Check (>= ${MIN_LINK_SPEED_MBPS} Mb/s)" "ethtool <each iface>" "$lines" "$overall_status" "$notes"
    }

    if ip link show bond0 > /dev/null 2>&1; then
        run_test "Ethernet" "Bond Speed" "ethtool bond0 | grep -i Speed"
        run_test "Ethernet" "Bond Type" "cat /proc/net/bonding/bond0 | grep 'Bonding Mode'"
    else
        add_row_to_html_report "Bond Speed" "ethtool bond0" "Device not found" "partial" "bond0 not present"
        add_row_to_html_report "Bond Type" "cat /proc/net/bonding/bond0" "Device not found" "partial" "bond0 not present"
    fi
    close_html_category_section
}

run_infiniband_tests() {
    add_html_category_header "InfiniBand Network"
    run_test "InfiniBand" "IB Links Speed" "ibstatus | grep -e 'rate:' -e 'device'"
    run_test "InfiniBand" "IB Links Status" "ibstatus | grep -e 'link_layer:' -e 'phys state:'"
    run_test "InfiniBand" "OFED Version" "ofed_info -s"
    run_test "InfiniBand" "IBoIP Enabled" "ibdev2netdev"
    run_test "InfiniBand" "IB Fabric" "iblinkinfo --switches-only"
    close_html_category_section
}

run_security_audit_tests() {
    add_html_category_header "Security & Accounts"

    # MOTD discovery and contents
    {
        local motd_files
        motd_files=$( ( [ -f /etc/motd ] && echo /etc/motd; ls -1 /etc/update-motd.d/* 2>/dev/null ) | sed '/^$/d' )
        local html=""
        if [[ -n "$motd_files" ]]; then
            local count
            count=$(echo "$motd_files" | wc -l | awk '{print $1}')
            html+="<details><summary>Show MOTD files and contents</summary>"
            if (( count > 1 )); then
                html+="<div class=\"banner\">Multiple MOTD fragments detected (${count} files)</div>"
            fi
            # List file names first
            html+="<div><strong>Files:</strong><ul>"
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                local sf
                sf=$(echo "$f" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                html+="<li>${sf}</li>"
            done <<< "$motd_files"
            html+="</ul></div>"
            # Then contents, one box per file
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                local content
                content=$(cat "$f" 2>&1)
                local safe
                safe=$(echo "$content" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                local sf
                sf=$(echo "$f" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                html+="<div class=\"box\"><div style=\"font-weight:600; color:#a9b1d6\">${sf}</div><pre>${safe}</pre></div>"
            done <<< "$motd_files"
            html+="</details>"
            add_row_to_html_report_html "MOTD" "cat /etc/motd; ls /etc/update-motd.d" "$html" "$([ $count -gt 1 ] && echo partial || echo pass)" "$([ $count -gt 1 ] && echo \"Multiple files\" || echo \"Found MOTD files\")"
        else
            add_row_to_html_report "MOTD" "cat /etc/motd" "No MOTD files found" "partial" ""
        fi
    }

    # SSH keys audit (paths, perms, fingerprints) - content redacted by design
    {
        local html="<details><summary>Show SSH key metadata (paths, perms, fingerprints)</summary>"
        local files
        files=$(find /root/.ssh /home -maxdepth 3 \( -name 'id_*' -o -name '*.pub' -o -name 'authorized_keys' \) 2>/dev/null)
        if [[ -z "$files" ]]; then
            html+="<div>No SSH key-like files found</div>"
        else
            html+="<table><thead><tr><th>Path</th><th>Type</th><th>Perms</th><th>Owner</th><th>Fingerprint</th></tr></thead><tbody>"
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                local perms owner fp type
                perms=$(stat -c '%a' "$f" 2>/dev/null)
                owner=$(stat -c '%U:%G' "$f" 2>/dev/null)
                if [[ "$f" == *.pub || "$(basename "$f")" == authorized_keys ]]; then
                    type="public"
                    fp=$(ssh-keygen -lf "$f" 2>/dev/null | awk '{print $2" "$3}' )
                else
                    type="private"
                    fp=$(ssh-keygen -lf "$f" 2>/dev/null | awk '{print $2" "$3}' )
                    [[ -z "$fp" ]] && fp="(fingerprint unavailable)"
                fi
                local safe_f
                safe_f=$(echo "$f" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                html+="<tr><td>${safe_f}</td><td>${type}</td><td>${perms:-N/A}</td><td>${owner:-N/A}</td><td>${fp:-N/A}</td></tr>"
            done <<< "$files"
            html+="</tbody></table><div style=\"margin-top:4px;color:#a9b1d6\">Key contents are intentionally redacted</div>"
        fi
        html+="</details>"
        add_row_to_html_report_html "SSH Keys Audit" "find ~/.ssh /home/*/.ssh" "$html" "partial" "Metadata only; contents redacted"
    }

    # /etc/passwd collapsible
    {
        local p
        p=$(cat /etc/passwd 2>&1)
        local safe
        safe=$(echo "$p" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
        local html="<details><summary>Show /etc/passwd</summary><pre>${safe}</pre></details>"
        add_row_to_html_report_html "/etc/passwd" "cat /etc/passwd" "$html" "pass" ""
    }

    # /etc/shadow analysis (no hashes shown)
    {
        local html=""
        if [[ -r /etc/shadow ]]; then
            local users_with_pw
            users_with_pw=$(awk -F: '($2!="!" && $2!="*" && $2!="" ){print $1}' /etc/shadow 2>/dev/null)
            local chips="<div class=\"disk-chips\">"
            local count=0
            if [[ -n "$users_with_pw" ]]; then
                while IFS= read -r u; do
                    [[ -z "$u" ]] && continue
                    chips+="<span class=\"disk-chip\">${u}</span>"
                    count=$((count+1))
                done <<< "$users_with_pw"
            else
                chips+="<span class=\"disk-chip\">No accounts with password set</span>"
            fi
            chips+="</div>"
            html+="$chips"
            local detail="<details><summary>Show shadow account status (redacted)</summary><pre>$(awk -F: '{printf "%s: ", $1; if($2=="!"||$2=="*") print "locked"; else if($2=="") print "no password"; else print "password set"}' /etc/shadow 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')</pre></details>"
            html+="$detail"
            local status="pass"
            local note="${count} account(s) with passwords set"
            add_row_to_html_report_html "/etc/shadow (redacted)" "analyzed" "$html" "$status" "$note"
        else
            add_row_to_html_report "/etc/shadow (redacted)" "N/A" "Not readable" "partial" "Requires root"
        fi
    }

    # Home directories (/home) and from /etc/passwd
    {
        local html=""
        # /home listing
        local homelist
        homelist=$(ls -1 /home 2>/dev/null)
        local html1="<details><summary>/home directory listing</summary>"
        if [[ -n "$homelist" ]]; then
            html1+="<table><thead><tr><th>Name</th></tr></thead><tbody>"
            while IFS= read -r h; do
                [[ -z "$h" ]] && continue
                local safe
                safe=$(echo "$h" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                html1+="<tr><td>${safe}</td></tr>"
            done <<< "$homelist"
            html1+="</tbody></table>"
        else
            html1+="<div>Empty or inaccessible /home</div>"
        fi
        html1+="</details>"

        # From /etc/passwd
        local homes
        homes=$(awk -F: '{print $6}' /etc/passwd | sort -u)
        local html2="<details><summary>Home directories parsed from /etc/passwd</summary>"
        if [[ -n "$homes" ]]; then
            html2+="<table><thead><tr><th>Path</th></tr></thead><tbody>"
            while IFS= read -r h; do
                [[ -z "$h" ]] && continue
                local safe
                safe=$(echo "$h" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                html2+="<tr><td>${safe}</td></tr>"
            done <<< "$homes"
            html2+="</tbody></table>"
        else
            html2+="<div>No home directories found</div>"
        fi
        html2+="</details>"

        html="${html1}${html2}"
        add_row_to_html_report_html "Home Directories" "ls /home and /etc/passwd" "$html" "pass" ""
    }

    close_html_category_section
}

run_speedtest_tests() {
    add_html_category_header "Network Speed Tests"

    log_warn "Network speed tests can take 1-3 minutes. We will discover servers and run two tests (Nearby, Europe). Please wait..."

    if ! command -v speedtest-cli &> /dev/null; then
        if $NOCHECK_MODE; then
            add_row_to_html_report "Speedtest" "speedtest-cli" "Skipped - speedtest-cli not installed" "partial" "Install 'speedtest-cli' to enable"
            close_html_category_section
            return
        else
            add_row_to_html_report "Speedtest" "speedtest-cli" "speedtest-cli not installed" "fail" "Install via apt: speedtest-cli"
            close_html_category_section
            return
        fi
    fi

    # Helper to find server by region keyword
    log "Discovering Speedtest servers (this may take ~15-30s)..."
    local list_all
    list_all=$(speedtest-cli --list 2>/dev/null)

    local sid_near sid_eu label_near label_eu

    if [[ -n "$SPEEDTEST_SERVER_NEARBY" ]]; then
        sid_near="$SPEEDTEST_SERVER_NEARBY"
        label_near=$(echo "$list_all" | grep -E "^\s*${sid_near}\)" | sed 's/^ *[0-9]\+) //')
    else
        # Assume top of list is nearest
        sid_near=$(echo "$list_all" | grep -Eo '^[[:space:]]*[0-9]+' | head -n 1 | tr -d ' ')
        label_near=$(echo "$list_all" | grep -E "^\s*${sid_near}\)" | sed 's/^ *[0-9]\+) //')
    fi


    if [[ -n "$SPEEDTEST_SERVER_EU" ]]; then
        sid_eu="$SPEEDTEST_SERVER_EU"
        label_eu=$(echo "$list_all" | grep -E "^\s*${sid_eu}\)" | sed 's/^ *[0-9]\+) //')
    else
        local EU_PATTERN="Germany|France|Netherlands|United Kingdom|UK|Sweden|Spain|Italy|Switzerland|Norway|Denmark|Finland|Poland|Ireland|Belgium|Austria|Czech|Portugal|Hungary|Romania|Greece|Iceland|Luxembourg|Slovakia|Slovenia|Lithuania|Latvia|Estonia|Bulgaria|Croatia|Serbia"
        sid_eu=$(echo "$list_all" | grep -E "$EU_PATTERN" | head -n 1 | grep -Eo '^[[:space:]]*[0-9]+' | tr -d ' ')
        label_eu=$(echo "$list_all" | grep -E "^\s*${sid_eu}\)" | sed 's/^ *[0-9]\+) //')
    fi

    # Function to run and evaluate a single server against thresholds
    run_one_speedtest() {
        local sid="$1"; local label="$2"; local tag="$3"
        if [[ -z "$sid" ]]; then
            add_row_to_html_report "Speedtest ${tag}" "speedtest-cli --simple" "No matching server" "partial" "No server ID for ${tag}"
            return
        fi
        log "Running Speedtest (${tag}) on server ${sid}${label:+ - ${label}} (may take up to ~60s)..."
        local out ec
        out=$(speedtest-cli --server "$sid" --simple 2>&1); ec=$?
        local status="pass"; local note="$label"
        if [[ $ec -ne 0 ]]; then
            status="fail"; note="${label:+${label} - }Exit code $ec"
        else
            # Parse speeds (Mbit/s)
            local dl ul
            dl=$(echo "$out" | awk '/Download:/ {print $2}')
            ul=$(echo "$out" | awk '/Upload:/ {print $2}')
            local dl_ok=1 ul_ok=1
            if (( ${MIN_DOWNLOAD_MBPS:-0} > 0 )) && [[ -n "$dl" ]] && (( ${dl%.*} < MIN_DOWNLOAD_MBPS )); then dl_ok=0; fi
            if (( ${MIN_UPLOAD_MBPS:-0} > 0 )) && [[ -n "$ul" ]] && (( ${ul%.*} < MIN_UPLOAD_MBPS )); then ul_ok=0; fi
            if (( ${MIN_DOWNLOAD_MBPS:-0} > 0 || ${MIN_UPLOAD_MBPS:-0} > 0 )); then
                if (( dl_ok==0 || ul_ok==0 )); then
                    status="fail"
                    note="${label:+${label} - }Thresholds DL>=${MIN_DOWNLOAD_MBPS} UL>=${MIN_UPLOAD_MBPS} (got DL=${dl:-N/A}, UL=${ul:-N/A})"
                else
                    note="${label:+${label} - }DL=${dl:-N/A} UL=${ul:-N/A} (thresholds DL>=${MIN_DOWNLOAD_MBPS} UL>=${MIN_UPLOAD_MBPS})"
                fi
            else
                note="${label:+${label} - }DL=${dl:-N/A} UL=${ul:-N/A}"
            fi
        fi
        add_row_to_html_report "Speedtest ${tag}" "speedtest-cli --server ${sid} --simple" "$out" "$status" "$note"
    }

    run_one_speedtest "$sid_near" "$label_near" "Nearby"
    run_one_speedtest "$sid_eu" "$label_eu" "Europe"

    close_html_category_section
}

install_docker_ce() {
    log "Starting Docker CE installation..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        log_error "Docker CE installation failed."; return 1
    fi
    log_success "Docker CE installed successfully."
    log "Verifying Docker installation with 'docker ps'..."
    docker ps
    return 0
}

run_benchmark_tests() {
    add_html_category_header "High-Performance Benchmarks"
    if ! command -v docker &> /dev/null; then
        log_warn "Docker is not installed, but it is required for benchmark tests."
        # If any non-install or burn-skip mode is active, skip benchmarks gracefully
        if $NOCHECK_MODE || $NOINSTALL_MODE || $NOBURN_MODE; then
             add_row_to_html_report "Benchmarks" "N/A" "Skipped - Docker not installed" "partial" "Benches disabled by flag or nocheck"
             close_html_category_section; return
        fi
        if $HEADLESS_MODE; then
            log_warn "--headless specified: attempting automatic Docker CE installation..."
            install_docker_ce || { add_row_to_html_report "Benchmarks" "N/A" "Skipped due to failed Docker installation" "fail" "Docker installation failed"; close_html_category_section; return; }
        else
            read -p "Do you want to install Docker CE now? (y/N): " docker_choice
            if [[ "$docker_choice" =~ ^[Yy]$ ]]; then
                install_docker_ce || { add_row_to_html_report "Benchmarks" "N/A" "Skipped due to failed Docker installation" "fail" "Docker installation failed"; close_html_category_section; return; }
            else
                add_row_to_html_report "Benchmarks" "N/A" "Skipped - Docker not installed" "partial" "User skipped installation"; close_html_category_section; return;
            fi
        fi
    fi
    
    local choice
    if $NOBURN_MODE || $NOINSTALL_MODE; then
        add_row_to_html_report "HPL Single Node" "N/A" "Skipped by flag" "partial" "--noburn/--noinstall"
        add_row_to_html_report "GPU Burn" "N/A" "Skipped by flag" "partial" "--noburn/--noinstall"
        close_html_category_section; return
    fi
    if $NOCHECK_MODE || $HEADLESS_MODE; then
        log_warn "Auto-accepting benchmarks due to automated mode."
        choice="y"
    else
        read -p "Run long-running Docker benchmarks (HPL/GPU-burn)? (y/N): " choice
    fi

    if [[ "$choice" =~ ^[Yy]$ ]]; then
        run_test "Benchmark" "HPL Single Node" "docker run --gpus all --rm --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 nvcr.io/nvidia/hpc-benchmarks:24.05 mpirun -np 8 --bind-to none --map-by ppr:8:node /hpl.sh --dat /hpl-linux-x86_64/sample-dat/HPL-dgx-h100-1N.dat"
        run_test "Benchmark" "GPU Burn" "docker run --rm --gpus all oguzpastirmaci/gpu-burn:latest"
    else
        add_row_to_html_report "HPL Single Node" "N/A" "Skipped by user" "partial" "Benchmarks not executed"
        add_row_to_html_report "GPU Burn" "N/A" "Skipped by user" "partial" "Benchmarks not executed"
    fi
    close_html_category_section
}

run_misc_tests() {
    add_html_category_header "Services & Mounts"
    run_test "Services" "SSH Access" "systemctl status sshd | grep 'Active:' | sed 's/^[ \t]*//'"
    run_test "Services" "IPMI Access" "ipmitool lan print"
    run_test "Mounts" "NFS Mounts" "mount | grep nfs"
    close_html_category_section
}

run_software_tests() {
    add_html_category_header "Software & Packages"

    # Process list (collapsible)
    {
        local psout
        psout=$(ps axfcu 2>&1)
        local safe
        safe=$(echo "$psout" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g;')
        local html="<details><summary>Show process list (ps axfcu)</summary><pre>${safe}</pre></details>"
        add_row_to_html_report_html "Process List" "ps axfcu" "$html" "pass" ""
    }

    # Installed packages as expandable list (package + version)
    {
        local manual html
        manual=$(apt-mark showmanual 2>/dev/null | sort -u)

        # Installed Packages (package + version)
        local q
        q=$(dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null)
        if [[ -n "$q" ]]; then
            local tab="<details><summary>Installed Packages</summary><div><input class=\"search\" id=\"pkgFilter\" placeholder=\"Filter packages...\" oninput=\"filterTable('pkgFilter','pkgTable')\"></div><table id=\"pkgTable\"><thead><tr><th>Package</th><th>Version</th></tr></thead><tbody>"
            while IFS=$'\t' read -r p v; do
                [[ -z "$p" ]] && continue
                local sp sv
                sp=$(echo "$p" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                sv=$(echo "$v" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                tab+="<tr><td>${sp}</td><td>${sv}</td></tr>"
            done <<< "$q"
            tab+="</tbody></table></details>"
            add_row_to_html_report_html "Installed Packages" "dpkg-query -W" "$tab" "pass" "Package and version"
        else
            add_row_to_html_report "Installed Packages" "dpkg-query -W" "No package data" "partial" "dpkg-query returned no results"
        fi

        # Manually installed software (package + version)
        if [[ -n "$manual" ]]; then
            local manhtml="<details><summary>Manually installed software</summary><div><input class=\"search\" id=\"manFilter\" placeholder=\"Filter manual packages...\" oninput=\"filterTable('manFilter','manTable')\"></div><table id=\"manTable\"><thead><tr><th>Package</th><th>Version</th></tr></thead><tbody>"
            while IFS= read -r pkg; do
                [[ -z "$pkg" ]] && continue
                local ver
                ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
                local sp sv
                sp=$(echo "$pkg" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                sv=$(echo "${ver:-N/A}" | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g;')
                manhtml+="<tr><td>${sp}</td><td>${sv}</td></tr>"
            done <<< "$manual"
            manhtml+="</tbody></table></details>"
            add_row_to_html_report_html "Manually installed software" "apt-mark showmanual | sort" "$manhtml" "pass" "From apt-mark showmanual"
        else
            add_row_to_html_report_html "Manually installed software" "apt-mark showmanual | sort" "<details><summary>Manually installed software</summary><div>No manual packages detected</div></details>" "partial" "None detected"
        fi
    }

    close_html_category_section
}

# ==============================================================================
# Main Execution Logic
# ==============================================================================

main() {
    if [[ $EUID -ne 0 ]]; then
       log_error "This script must be run as root or with sudo."; exit 1
    fi

    # --- Parse Command-Line Arguments ---
    for arg in "$@"; do
        case "$arg" in
            --nocheck)
                NOCHECK_MODE=true
                ;;
            --headless)
                HEADLESS_MODE=true
                ;;
            --noinstall)
                NOINSTALL_MODE=true
                ;;
            --noburn)
                NOBURN_MODE=true
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
        esac
    done
    
    clear
    echo -e "${C_GREEN}===========================================${C_RESET}"
    echo -e "${C_GREEN}  System Hardware & Performance Test Tool  ${C_RESET}"
    echo -e "${C_GREEN}===========================================${C_RESET}"
    echo

    if $NOCHECK_MODE; then
        log_warn "Running in --nocheck mode. All dependency checks and prompts will be skipped."
    else
        check_and_install_dependencies
    fi

    log "Starting all tests. The results will be saved to: ${C_YELLOW}${OUTPUT_FILE}${C_RESET}"
    echo
    
    initialize_html_report
    
    run_system_info_tests
    run_cpu_tests
    run_ram_tests
    run_nvme_tests
    run_gpu_tests
    run_ethernet_tests
    run_infiniband_tests
    run_security_audit_tests
    run_speedtest_tests
    run_software_tests
    run_misc_tests
    run_benchmark_tests

    # Write follow-up/checklist section then finalize
    write_followup_section
    
    finalize_html_report
    
    echo
    log_success "All tests have been completed."
    log "Report saved successfully to: ${C_YELLOW}${OUTPUT_FILE}${C_RESET}"
    echo
}

# Pass all script arguments to the main function
main "$@"


