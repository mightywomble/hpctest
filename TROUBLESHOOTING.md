# HPC Test Suite - Troubleshooting Guide

## Issue: Docker Error - "no space left on device"

When running the HPL benchmark, you may see:
```
docker: failed to register layer: write /usr/local/cuda-12.6/targets/x86_64-linux/lib/libcufft.so.11.2.6.59: no space left on device
```

### Root Cause
Docker needs to extract and layer the NVIDIA HPC-Benchmarks image (~5-10GB). Your root filesystem doesn't have enough free space.

### Solution

**Check current disk usage:**
```bash
df -h /
```

You need at least 15-20GB free on `/` (root filesystem).

**Option 1: Clean up Docker (recommended)**
```bash
# Remove unused Docker images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove all stopped containers
docker container prune

# Check freed space
df -h /
```

**Option 2: Configure Docker to use external storage**
If your `/home` or `/var/docker` partition has more space:

```bash
# Stop Docker
sudo systemctl stop docker

# Move Docker data to a larger partition
sudo mv /var/lib/docker /path/to/larger/disk/docker

# Create symlink
sudo ln -s /path/to/larger/disk/docker /var/lib/docker

# Start Docker
sudo systemctl start docker
```

**Option 3: Skip benchmarks for now**
```bash
sudo ./hpctests_new.sh --noburn
```
This runs all other tests and skips the Docker-based benchmarks.

---

## Issue: No Console Output During Test

If you run tests and see no output for long periods, this is normal!

### What's happening
- Each test script now outputs `[RUNNING] <category>` when it starts
- Tests like CPU, RAM, and NVMe complete quickly with no intermediate output
- Long-running tests (like Speedtest) will show progress

### Example output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ 002-cpu
[RUNNING] 001-system
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ COMPLETE - 002-cpu
```

The `[RUNNING]` line appears immediately, then the test completes and you see `✓ COMPLETE`.

---

## Issue: HPL Benchmark Fails to Pull Image

Error: `manifest unknown` or `Error response from daemon`

### Cause
The NVIDIA NGC registry either:
- Doesn't have the tag you requested
- Requires authentication
- Is unreachable from your network

### Solution
The script auto-detects the latest available tag using:
```bash
curl https://registry.ngc.nvidia.com/v2/nvidia/hpc-benchmarks/tags/list
```

If this fails, it falls back to tag `24.09`.

**Verify connectivity:**
```bash
curl -s https://registry.ngc.nvidia.com/v2/nvidia/hpc-benchmarks/tags/list | head -c 100
```

**If behind a proxy:**
```bash
curl -x [proxy-url] https://registry.ngc.nvidia.com/v2/nvidia/hpc-benchmarks/tags/list
```

---

## Issue: Missing jq Dependency

Error: `jq is required for parsing manifest`

### Solution
```bash
sudo apt-get update
sudo apt-get install -y jq
```

The script checks for jq at startup and fails cleanly with installation instructions.

---

## Issue: Missing Docker

Error: `Docker is not installed, but it is required for benchmark tests`

### Solution
For `--headless` mode (auto-install):
```bash
sudo ./hpctests_new.sh --headless
```

Manual install:
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo usermod -aG docker $(whoami)
newgrp docker
```

---

## Performance Tips

### Speed up tests
- Use `--noburn` to skip Docker-based benchmarks (saves 10+ minutes)
- Run during off-peak hours if on a shared system

### Disk space optimization
- Run tests on a partition with 20GB+ free
- Clean Docker images before running: `docker image prune -a`

### Network optimization
- For Speedtest to complete: ensure stable internet connection (300+ seconds)
- For HPL: ensure `curl` can reach `registry.ngc.nvidia.com`

---

## Getting Help

### Check the logs
- HTML report: Look at generated `system_test_report_*.html`
- Console output: Review `[RUNNING]` lines for which tests executed
- Test data: HTML includes JSON block at end with all results

### Verbose mode
Currently tests don't have verbose mode. To debug:
1. Run individual test scripts: `bash tests.d/002-cpu.sh`
2. Check exit codes: `echo $?`
3. Review test script logic in `tests.d/`

### Known limitations
- HPL benchmark requires NVIDIA GPUs (skips gracefully on CPU-only systems)
- Speedtest requires internet connectivity (300+ seconds)
- Some tests require root/sudo privileges
