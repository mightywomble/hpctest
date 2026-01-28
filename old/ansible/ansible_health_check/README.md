# Ansible Health Check: Preflight and NCCL Testing

This directory contains an Ansible playbook and roles to generate a system health report and validate NVIDIA/CUDA/NCCL readiness.

## What’s new
- Role `check_preflight` (tag: `run_preflight_check`) to prepare nodes for NCCL testing:
  - Purges conflicting NVIDIA/CUDA packages
  - Installs CUDA 13.0 toolkit (includes driver) via NVIDIA keyring
  - Sets `/usr/local/cuda` and `/usr/bin/nvcc` symlinks
  - Clones and builds `nccl-tests`, symlinks `/usr/local/bin/all_reduce_perf`
  - Writes status file `/etc/ansible_gpu_install_complete`
  - Reboots the host to load the NVIDIA kernel modules
- NCCL role trigger changed to `run_ncclnode_check` (was `run_nccl_check`). The role now:
  - Performs a pre-flight check (status file + minimum uptime)
  - Runs `all_reduce_perf` with 1 or N GPUs
  - Appends both pre-flight and benchmark results to the HTML report

## Why run the preflight first?
NCCL tests require a consistent NVIDIA driver + CUDA toolkit and the `all_reduce_perf` binary. The preflight role guarantees a clean, up-to-date stack and produces a status file that the NCCL role uses to confirm readiness before benchmarking.

## Usage

1) Run the preflight (installs drivers/toolkit, builds NCCL tests, reboots):
```bash
ansible-playbook -i inventory preflight.yaml --become -t run_preflight_check
```
Wait for the host to reboot and come back online.

2) Run the main report with NCCL testing enabled:
```bash
ansible-playbook -i inventory playbook.yml --become -e "run_ncclnode_check=true"
```
This generates a styled HTML report under `reports/` named like `system_test_report_<HOST>_<TIMESTAMP>.html`, including:
- "NCCL Pre-flight" (PASS/FAIL with details)
- "NCCL Benchmark (all_reduce_perf)" (PASS/FAIL/PARTIAL)

Optional: enable other checks in the same run by adding variables, e.g.:
```bash
-e "run_system_check=true run_cpu_check=true run_ram_check=true run_storage_check=true run_gpu_check=true run_ethernet_check=true run_infiniband_check=true run_security_check=true run_network_speed_check=true run_software_check=true run_services_check=true"
```

## Notes
- CUDA packages in the preflight are targeted at Ubuntu 22.04 and CUDA 13.0; adjust if your distribution/version differs.
- The NCCL role looks for `/etc/ansible_gpu_install_complete` and requires at least ~2 minutes of uptime post-reboot before testing.
