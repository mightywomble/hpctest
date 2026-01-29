# Status Evaluation Guide

## Current Problem
Status is being hardcoded as "pass" even when commands fail. This is misleading.

### Bad Examples:
- `ipmitool lan print` - command fails (exit code 1) but marked "pass"
- `No NFS mounts detected` - informational message marked as "pass" when no mounts exist
- SSH key search returns 2 files marked "partial" when it should be "pass"

## Solution: Use Exit Codes + Output Presence

### Better Approach

Each test should follow this pattern:

```bash
# Run command and capture exit code
result=$(command 2>&1)
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    # Command succeeded
    if [[ -n "$result" ]]; then
        status="pass"
        notes="Command executed successfully"
    else
        status="pass"
        result="<empty output>"
        notes="Command succeeded with no output"
    fi
else
    # Command failed
    status="fail"
    notes="Command failed with exit code $exit_code"
fi
```

## Test Categories and Evaluation

### System Information Tests (001-system.sh, 002-cpu.sh, 003-ram.sh)
- **PASS**: Command exits 0 and produces output
- **FAIL**: Command exits non-zero or produces no output

### Service Status Tests (011-services.sh)
- **PASS**: Service is running (systemctl status = 0)
- **FAIL**: Service is not running (systemctl status != 0)

### Detection Tests (008-security.sh, 006-ethernet.sh)
- **PASS**: Item found/exists (command exits 0)
- **FAIL**: Item not found/missing (command exits 1 or timeout)
- Example: "SSH keys found" = PASS, "No SSH keys" = still PASS (it's just information)
- Example: "IPMI access failed" = FAIL (exit code != 0)

### Optional Feature Tests (007-infiniband.sh, 005-gpu.sh)
- **PASS**: Feature installed and working (command exits 0)
- **FAIL**: Feature missing or error (command exits non-zero)
- Note: "NVIDIA GPUs not detected" should be PASS (feature doesn't exist, that's okay)
- But: "NVIDIA driver error" should be FAIL (driver installed but broken)

## Implementation Pattern

```bash
# Pattern for service status
if systemctl is-active --quiet sshd; then
    status="pass"
    result="SSH service is running"
else
    status="fail"
    result=$(systemctl status sshd 2>&1)
fi

# Pattern for file/command detection
if command -v ipmitool &>/dev/null; then
    if result=$(ipmitool lan print 2>&1); then
        status="pass"
    else
        status="fail"
    fi
else
    status="fail"
    result="ipmitool not installed"
fi

# Pattern for grep detection (absence is okay, error is not)
result=$(mount 2>&1 | grep nfs) || true
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    status="pass"
    notes="NFS mounts found"
elif [[ $exit_code -eq 1 ]]; then
    # grep found nothing - this is okay, mark as pass
    status="pass"
    result="No NFS mounts detected"
    notes="This is expected if no NFS is configured"
else
    # grep had an error
    status="fail"
    notes="Error checking mount points"
fi
```

## Summary

### Use PASS for:
✓ Command succeeded (exit 0)
✓ Information found (feature exists/works)
✓ Absence of optional features ("no NFS mounts" = normal)

### Use FAIL for:
✗ Command failed (exit != 0)
✗ Error occurred (not just absence, but actual error)
✗ Required feature broken or missing when it should exist

### Avoid:
❌ Hardcoding status without checking exit code
❌ Guessing based on output content
❌ Treating "not found" as "fail" when it's optional
❌ Using "partial" inconsistently - remove it, use pass/fail only
