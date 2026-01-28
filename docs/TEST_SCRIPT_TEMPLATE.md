# Creating New HPC Test Scripts

This guide explains how to create new modular test scripts for the hpctests framework.

## Overview

Each test script in `tests.d/` follows a consistent pattern:
1. Sources the shared `config.sh` for logging and utility functions
2. Outputs JSON-formatted test results to stdout
3. Is completely self-contained (handles own dependencies, error checking)
4. Exits with code 0 (success/skip logic recorded in JSON output)

## Basic Template

Here's a minimal example to get started:

```bash
#!/bin/bash

# ==============================================================================
# Test Script: Your Category Name
# Category: Category Name
# Description: Brief description of what tests are performed
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Test 1: First test
result=$(your_command_here 2>&1)
status="pass"
notes=""
if [[ -z "$result" ]]; then
    status="partial"
    notes="No output"
    result="No output"
fi
output_test_result "Test 1 Name" "your_command_here" "$result" "$status" "$notes"
echo ","

# Test 2: Second test
result=$(another_command 2>&1)
status="pass"
output_test_result "Test 2 Name" "another_command" "$result" "$status" ""

finish_json_output
```

## Detailed Example

Here's a more complete example showing how to handle dependencies and complex scenarios:

```bash
#!/bin/bash

# ==============================================================================
# Test Script: Example Testing
# Category: Example Tests
# Description: Demonstrates various testing patterns
# ==============================================================================

source "$(dirname "$0")/../config.sh"

start_json_output

# Pattern 1: Simple command with output
result=$(lsblk -o NAME,SIZE 2>&1)
status="pass"
notes=""
output_test_result "Block Devices" "lsblk -o NAME,SIZE" "$result" "$status" "$notes"
echo ","

# Pattern 2: Command with dependency check
if command -v nvidia-smi &>/dev/null; then
    result=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>&1)
    status="pass"
else
    result="nvidia-smi not installed"
    status="partial"
fi
notes="NVIDIA driver detection"
output_test_result "GPU Detection" "nvidia-smi --query-gpu=gpu_name" "$result" "$status" "$notes"
echo ","

# Pattern 3: Command with exit code checking
result=$(curl https://example.com 2>&1)
exit_code=$?
status="pass"
notes=""
if [[ $exit_code -ne 0 ]]; then
    status="fail"
    notes="curl exited with code $exit_code"
fi
output_test_result "Network Test" "curl https://example.com" "$result" "$status" "$notes"
echo ","

# Pattern 4: Conditional logic and complex processing
{
    local threshold=100
    local value=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
    
    local status="pass"
    local notes=""
    if (( value < threshold )); then
        status="fail"
        notes="Value below threshold"
    fi
    output_test_result "Memory Check" "cat /proc/meminfo | grep MemTotal" "$value KB" "$status" "$notes"
}

finish_json_output
```

## Key Functions from config.sh

### Logging Functions
```bash
log "Normal message with timestamp"
log_success "Success message"
log_warn "Warning message"
log_error "Error message"
```

### Output Functions
```bash
# Regular test result
output_test_result "Test Name" "command shown" "result text" "pass|fail|partial" "optional notes"

# For HTML result (complex output with HTML formatting)
output_test_result_html "Test Name" "command shown" "{\"html\": \"content\"}" "pass|fail|partial" "notes"

# Array markers
start_json_output  # Call once at the beginning
finish_json_output # Call once at the end
```

### Helper Functions
```bash
# Check if a command exists
check_command_exists "command_name"

# Check if test should be skipped based on flags
should_skip_test "--noburn" "--noinstall"

# Run a simple test (handles exit code checking automatically)
run_single_test "Test Name" "command here"
```

## Status Values

Always use one of these status values:
- `"pass"` - Test completed successfully
- `"fail"` - Test failed or error occurred
- `"partial"` - Test ran but with incomplete results

## JSON Output Format

Each test script must output valid JSON array. Example:

```json
[
  {
    "test_name": "Test 1",
    "command": "ls -la",
    "result": "total 24\n-rw-r--r-- 1 root root ...",
    "status": "pass",
    "notes": ""
  },
  {
    "test_name": "Test 2",
    "command": "free -h",
    "result": "total       used       free...",
    "status": "pass",
    "notes": "Memory check complete"
  }
]
```

## Escaping JSON Strings

The helper functions handle escaping automatically. If you manually create JSON:
- Replace `\` with `\\`
- Replace `"` with `\"`
- Replace newlines with `\n`

Example:
```bash
result="Line 1\nLine 2"  # newline will be escaped automatically
output_test_result "Test" "cmd" "$result" "pass" ""
```

## Configuration Variables

Access shared configuration set in `config.sh`:

```bash
# Display variables
$HOSTNAME_FQDN          # Hostname
$PRIMARY_IP             # Primary IP address

# Threshold variables (configurable via environment)
$MIN_LINK_SPEED_MBPS    # Minimum link speed
$MIN_DOWNLOAD_MBPS      # Minimum download speed
$MIN_UPLOAD_MBPS        # Minimum upload speed
$SPEEDTEST_SERVER_NEARBY # Speedtest server ID for nearby
$SPEEDTEST_SERVER_EU    # Speedtest server ID for EU

# Flag variables (access flag states)
$HEADLESS_MODE          # true/false
$NOBURN_MODE            # true/false
$NOINSTALL_MODE         # true/false
$NOCHECK_MODE           # true/false

# Output file
$OUTPUT_FILE            # Path to HTML report being generated
```

## Registering Your Script

To add a new test script to the test suite:

1. Create `tests.d/NNN-your_test_name.sh` (use next available number)
2. Add entry to `tests.manifest.json`:

```json
{
  "id": "NNN-your_test_name",
  "script": "tests.d/NNN-your_test_name.sh",
  "category": "Your Category",
  "description": "Brief description",
  "dependencies": ["cmd1", "cmd2"],
  "depends_on_tests": [],
  "skip_flags": ["--noburn"],
  "timeout_seconds": 30
}
```

### Manifest Fields

- **id**: Unique identifier (NNN-name format)
- **script**: Relative path to script
- **category**: HTML section heading (existing category or new)
- **description**: Short description shown in logs
- **dependencies**: Commands required (check in manifest, not by script)
- **depends_on_tests**: List of test IDs that must run first
- **skip_flags**: Flags that skip this test (`--noburn`, `--noinstall`, `--nocheck`)
- **timeout_seconds**: Maximum execution time (used for monitoring)

## Testing Your Script

Before committing, test your script individually:

```bash
# Test as regular user (some output may differ from root)
bash /home/david/code/hpctest/tests.d/NNN-your_test.sh | jq .

# Test as root
sudo bash /home/david/code/hpctest/tests.d/NNN-your_test.sh | jq .
```

Verify the JSON output is valid and all fields are populated correctly.

## Best Practices

1. **Error Handling**: Always capture stderr with `2>&1`
2. **Dependencies**: Check before running (`if command -v ...`)
3. **Graceful Degradation**: Output "partial" status if optional tools missing
4. **No Prompts**: Never call `read` or interactive commands
5. **Exit Code**: Always exit 0 (record failures in JSON `status` field)
6. **Logging**: Use `log`, `log_warn`, `log_error` for user feedback
7. **Isolation**: Don't depend on other test scripts; be self-contained
8. **Escaping**: Let `output_test_result` handle JSON escaping
9. **Commas**: Remember commas between test result objects (see template)
10. **Testing**: Test both with and without required tools installed

## Common Patterns

### Pattern: Optional Tool
```bash
if command -v tool_name &>/dev/null; then
    result=$(tool_name arg 2>&1)
    status="pass"
else
    result="tool_name not installed"
    status="partial"
fi
output_test_result "Test Name" "tool_name arg" "$result" "$status" ""
```

### Pattern: Skip Based on Flags
```bash
if should_skip_test "--noburn"; then
    output_test_result "Benchmark" "docker run..." "Skipped" "partial" "--noburn flag"
    finish_json_output
    exit 0
fi
```

### Pattern: Conditional Check
```bash
value=$(expr 1 + 1)
status="pass"
notes=""
if [[ $value -ne 2 ]]; then
    status="fail"
    notes="Math error"
fi
output_test_result "Math Test" "expr 1 + 1" "$value" "$status" "$notes"
```

### Pattern: Multi-line Output with Filtering
```bash
result=$(ps aux | grep -v grep | wc -l)
output_test_result "Process Count" "ps aux | wc -l" "$result" "pass" ""
```

## Troubleshooting

**Script won't execute**: Make sure it's executable: `chmod +x tests.d/NNN-script.sh`

**JSON parsing errors**: Validate JSON with `jq` tool: `bash script.sh | jq .`

**Missing dependencies at runtime**: Add dependency checks in your script

**Output not appearing in HTML**: Ensure JSON format is valid and fields match expected names

**Slow tests**: Set appropriate `timeout_seconds` in manifest; consider optimizing commands
