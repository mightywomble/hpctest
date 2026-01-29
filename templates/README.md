# Test Script Templates

This directory contains templates for creating new test scripts. Each template demonstrates a different pattern for common HPC test scenarios.

## Using Templates

1. Copy the template that matches your use case
2. Replace placeholder text (marked with `[DESCRIPTION]`, `[YOUR_COMMAND]`, etc.)
3. Make it executable: `chmod +x your_script.sh`
4. Test it: `bash your_script.sh`
5. Validate JSON: `bash your_script.sh | jq .`
6. Add to `tests.manifest.json` when ready

## Available Templates

### 1. **basic-single-test.sh**
**Use when**: Running a single command and reporting the result

**Example use cases**:
- Check OS version
- Get system uptime
- Read a configuration file
- Display a simple metric

**Pattern**:
```bash
result=$(your_command)
status="pass" or "fail"
output_html_result "Test Name" "your_command" "$result" "$status" "$notes"
```

### 2. **conditional-test.sh**
**Use when**: Command has conditional logic (if/else)

**Example use cases**:
- Check if a service is running
- Check if a file exists
- Verify configuration value
- Check if a threshold is met

**Pattern**:
```bash
if [[ condition ]]; then
    status="pass"
else
    status="fail"
fi
```

### 3. **exit-code-test.sh**
**Use when**: Determining pass/fail based on exit codes

**Example use cases**:
- Run a system command and check success
- Execute a tool and verify it works
- Capture both stdout and stderr

**Pattern**:
```bash
result=$(command 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    status="pass"
else
    status="fail"
fi
```

### 4. **multiple-tests.sh**
**Use when**: Multiple related tests in one script

**Example use cases**:
- Test multiple system properties
- Check several related services
- Gather related metrics

**Pattern**:
```bash
start_json_output
# Test 1
output_html_result ...
echo ","
# Test 2
output_html_result ...
finish_json_output
```

### 5. **optional-feature.sh**
**Use when**: Testing for optional/not-required features

**Example use cases**:
- GPU detection
- InfiniBand stack detection
- Optional package check
- Optional daemon presence

**Pattern**:
```bash
if command -v tool &>/dev/null; then
    result=$(tool 2>&1)
    if [[ $? -eq 0 ]]; then
        status="pass"
    else
        status="fail"  # Tool exists but broken
    fi
else
    status="pass"  # Tool not installed = normal, not a failure
    result="Not installed"
    notes="(Optional feature)"
fi
```

### 6. **grep-search.sh**
**Use when**: Searching for specific content in output

**Example use cases**:
- Look for configuration in a file
- Search for specific output in command
- Check for presence/absence of text

**Pattern**:
```bash
result=$(command 2>&1 | grep -i "pattern" || true)
if [[ -n "$result" ]]; then
    status="pass"
    notes="Found"
else
    status="pass"  # or "fail" depending on context
    notes="Not found (may be normal)"
fi
```

### 7. **threshold-check.sh**
**Use when**: Testing against minimum/maximum thresholds

**Example use cases**:
- Verify link speed meets minimum
- Check available disk space
- Validate network bandwidth
- Confirm memory capacity

**Pattern**:
```bash
value=$(command | extract_number)
min_threshold=100
if (( value >= min_threshold )); then
    status="pass"
else
    status="fail"
    notes="Below minimum: $value < $min_threshold"
fi
```

### 8. **dependency-check.sh**
**Use when**: Testing presence of required tools/packages

**Example use cases**:
- Check for required commands
- Verify package installation
- Validate library availability

**Pattern**:
```bash
if command -v tool_name &>/dev/null; then
    # Tool exists
    result=$(tool_name 2>&1)
    status="pass"
else
    # Tool missing
    status="fail"
    result="tool_name not installed"
    notes="Install with: apt install package-name"
fi
```

## Key Functions Available

All templates can use these functions from `config.sh`:

```bash
# Output a test result
output_html_result "Test Name" "command" "result" "status" "notes" "test_id" "category" "type"

# Check if a test should be skipped
should_skip_test "--flag"

# Log messages (for debugging, not in output)
log "message"
log_warn "warning message"
log_error "error message"

# JSON functions (for multi-test scripts)
start_json_output
finish_json_output
```

## Status Values

All templates use these status values:

- `"pass"` - Test passed, working as expected
- `"fail"` - Test failed, error detected
- `"partial"` - (Deprecated) Avoid using this

## Common Patterns

### Checking Exit Codes

```bash
# Always capture exit code immediately after command
result=$(command 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    status="pass"
else
    status="fail"
fi
```

### Handling Missing Commands

```bash
# For optional features (absence is OK)
result=$(command 2>&1 || true)
if [[ -n "$result" ]]; then
    status="pass"
else
    status="pass"  # Feature not installed, that's OK
    result="Not installed"
fi
```

### Parsing Output

```bash
# Extract a value from command output
value=$(free -h | grep Mem: | awk '{print $2}')

# Search for text in output
if grep -q "pattern" /path/to/file; then
    status="pass"
fi
```

### Multiple Tests in One Script

```bash
start_json_output

# Test 1
result=$(cmd1)
output_html_result "Test 1" "cmd1" "$result" "pass" "" "test-1" "Category" "text"
echo ","

# Test 2 (no comma after last test)
result=$(cmd2)
output_html_result "Test 2" "cmd2" "$result" "pass" "" "test-2" "Category" "text"

finish_json_output
```

## Template Variables

Each template uses these placeholders—replace them with your actual values:

| Placeholder | Example | Description |
|------------|---------|------------|
| `[SCRIPT_NAME]` | `001-example.sh` | The script filename |
| `[CATEGORY]` | `System Information` | The category in the HTML report |
| `[DESCRIPTION]` | `Check system hostname` | What the test does |
| `[TEST_NAME]` | `Hostname Check` | Name shown in HTML report |
| `[YOUR_COMMAND]` | `hostname` | The command to run |
| `[TEST_ID]` | `hostname-check` | Unique ID (lowercase, hyphens) |
| `[NOTES]` | `System hostname retrieved` | Additional information |

## Testing Your Template

Once you create a script from a template:

```bash
# 1. Make it executable
chmod +x tests.d/your_script.sh

# 2. Run it and check output
bash tests.d/your_script.sh

# 3. Validate JSON format
bash tests.d/your_script.sh | jq .

# 4. Run as root (how it will be run in real system)
sudo bash tests.d/your_script.sh
```

## Adding to the System

Once your script works:

1. Add entry to `tests.manifest.json`:
```json
{
  "id": "test-id",
  "script": "tests.d/your_script.sh",
  "category": "Category Name",
  "description": "What the test does",
  "dependencies": ["command1", "command2"],
  "depends_on_tests": [],
  "skip_flags": ["--noburn"],
  "timeout_seconds": 30
}
```

2. Validate manifest: `jq . tests.manifest.json`

3. Run full test suite: `sudo ./hpctests.sh --headless --noburn`

## Getting Help

- Look at existing tests in `tests.d/` for real-world examples
- Read `STATUS_EVALUATION.md` for status determination rules
- Check `GETTING_STARTED.md` for detailed walkthrough
- Review `docs/TEST_SCRIPT_TEMPLATE.md` for complete reference

## Common Mistakes to Avoid

❌ **Hardcoding status without checking exit code**
```bash
result=$(command)
status="pass"  # WRONG! Should check exit code
```

✅ **Proper exit code checking**
```bash
result=$(command 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    status="pass"
else
    status="fail"
fi
```

---

❌ **Forgetting commas between tests**
```bash
output_html_result "Test 1" ...
output_html_result "Test 2" ...  # WRONG! Missing comma
```

✅ **Proper comma placement**
```bash
output_html_result "Test 1" ...
echo ","
output_html_result "Test 2" ...
```

---

❌ **Using `partial` status**
```bash
status="partial"  # WRONG! Use pass or fail
```

✅ **Use pass or fail only**
```bash
status="pass"  # Feature doesn't exist, that's OK
# or
status="fail"  # Actual error occurred
```

---

**Happy testing! 🚀**
