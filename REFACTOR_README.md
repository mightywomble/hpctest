# HPC Test Framework - Modular Refactoring

This document describes the refactored modular architecture of the hpctests framework.

## Overview

The original `hpctests.sh` monolithic script (~1260 lines) has been refactored into a modular system consisting of:

- **config.sh** - Shared utilities, logging, and configuration
- **tests.manifest.json** - Test metadata and execution order (JSON)
- **tests.d/NNN-*.sh** - 12 individual self-contained test scripts
- **hpctests.sh** (or **hpctests_new.sh**) - Main orchestrator

### Key Benefits

1. **Maintainability**: Each test category is isolated in its own script (~50-100 lines)
2. **Extensibility**: New tests can be added by dropping a script in `tests.d/` and updating the manifest
3. **Reusability**: Common functions centralized in `config.sh`, no duplication
4. **Testability**: Individual test scripts can be run and debugged independently
5. **Flexibility**: Manifest-driven execution allows for flexible test ordering and skipping

## Directory Structure

```
hpctest/
├── hpctests.sh                    # Main orchestrator script (refactored)
├── hpctests.sh.backup             # Backup of original script
├── hpctests_new.sh                # New orchestrator (to replace hpctests.sh)
├── config.sh                       # Shared config & utility functions
├── tests.manifest.json             # Test execution manifest
├── tests.d/                        # Test scripts directory
│   ├── 001-system.sh              # System information tests
│   ├── 002-cpu.sh                 # CPU information tests
│   ├── 003-ram.sh                 # RAM information tests
│   ├── 004-nvme.sh                # NVMe storage tests
│   ├── 005-gpu.sh                 # GPU and NVIDIA driver tests
│   ├── 006-ethernet.sh            # Ethernet network tests
│   ├── 007-infiniband.sh          # InfiniBand tests
│   ├── 008-security.sh            # Security and account audit tests
│   ├── 009-speedtest.sh           # Network speed tests
│   ├── 010-software.sh            # Software and packages tests
│   ├── 011-services.sh            # Services and mounts tests
│   └── 012-benchmarks.sh          # Docker benchmark tests
├── TEST_SCRIPT_TEMPLATE.md         # Guide for creating new test scripts
├── REFACTOR_README.md              # This file
└── README.md                       # Original project README
```

## Usage

### Running Tests

The refactored `hpctests.sh` maintains backward compatibility with the original command-line interface:

```bash
# Standard run (interactive)
sudo ./hpctests.sh

# Headless mode (auto-yes to all prompts, installs allowed)
sudo ./hpctests.sh --headless

# Skip Docker benchmarks
sudo ./hpctests.sh --noburn

# Do not install software
sudo ./hpctests.sh --noinstall

# Legacy automated mode
sudo ./hpctests.sh --nocheck

# Help
sudo ./hpctests.sh --help
```

All flags can be combined:
```bash
sudo ./hpctests.sh --headless --noburn
```

### Output

- HTML report: `system_test_report_YYYY-MM-DD_HH-MM-SS.html`
- Console output with colored logging
- Per-test status (PASS/PARTIAL/FAIL)

## Architecture Details

### config.sh - Shared Configuration

Provides:
- **Logging functions**: `log()`, `log_success()`, `log_warn()`, `log_error()`
- **Color codes**: `C_RED`, `C_GREEN`, `C_YELLOW`, `C_BLUE`, `C_CYAN`
- **Global variables**: Hostnames, IPs, thresholds, flags
- **Helper functions**: 
  - `output_test_result()` - Output JSON test result
  - `output_test_result_html()` - Output JSON with embedded HTML
  - `start_json_output()` / `finish_json_output()` - JSON array markers
  - `check_command_exists()` - Command availability check
  - `should_skip_test()` - Flag-based skip logic
  - `run_single_test()` - Simple test execution with exit code handling

### tests.manifest.json - Execution Manifest

Defines test execution order and metadata. Example entry:

```json
{
  "id": "001-system",
  "script": "tests.d/001-system.sh",
  "category": "System",
  "description": "System information tests",
  "dependencies": [],
  "depends_on_tests": [],
  "skip_flags": [],
  "timeout_seconds": 30
}
```

**Fields**:
- `id`: Unique test identifier (NNN-name format)
- `script`: Relative path to test script
- `category`: HTML section heading
- `description`: Human-readable description
- `dependencies`: Commands that script requires (informational)
- `depends_on_tests`: Other test IDs that must run first
- `skip_flags`: Flags that cause test to be skipped (`--noburn`, `--noinstall`, `--nocheck`)
- `timeout_seconds`: Maximum execution time

### Individual Test Scripts (tests.d/NNN-*.sh)

Each test script:
1. Sources `config.sh` for shared functions
2. Calls `start_json_output` to begin JSON array
3. Runs tests, outputting each as JSON object via `output_test_result()`
4. Calls `finish_json_output` to close JSON array
5. Exits with code 0 (no error handling needed - status in JSON)

**Key Characteristics**:
- Completely self-contained (handles own dependencies)
- Outputs valid JSON array to stdout
- No HTML generation (main script does this)
- Gracefully degrades when tools are missing
- Always exits 0 (failures recorded in JSON)

### hpctests.sh - Main Orchestrator

The refactored orchestrator:
1. Parses command-line flags (--headless, --noburn, etc.)
2. Sources config.sh for shared utilities
3. Exports flag variables for test scripts to access
4. Loads tests.manifest.json (uses grep/sed for parsing)
5. For each test in manifest order:
   - Checks if skip_flags apply
   - Executes test script
   - Captures JSON output
   - Parses JSON and renders to HTML
6. Generates final HTML report

**Flow**:
```
Parse CLI flags
  ↓
Initialize HTML report
  ↓
Load manifest
  ↓
For each test:
  ├─ Check skip_flags
  ├─ Execute test script
  ├─ Capture JSON output
  ├─ Parse JSON
  └─ Render to HTML
  ↓
Finalize HTML report
  ↓
Report completion
```

## Adding New Tests

To add a new test to the framework:

### 1. Create Test Script

Create `tests.d/NNN-your_test_name.sh`:

```bash
#!/bin/bash

source "$(dirname "$0")/../config.sh"

start_json_output

# Your tests here
result=$(command_here 2>&1)
output_test_result "Test Name" "command_here" "$result" "pass" ""

finish_json_output
```

### 2. Update Manifest

Add entry to `tests.manifest.json`:

```json
{
  "id": "NNN-your_test_name",
  "script": "tests.d/NNN-your_test_name.sh",
  "category": "Your Category",
  "description": "Test description",
  "dependencies": ["cmd1", "cmd2"],
  "depends_on_tests": [],
  "skip_flags": [],
  "timeout_seconds": 30
}
```

### 3. Test Independently

```bash
bash tests.d/NNN-your_test_name.sh | jq .
```

For complete details, see `TEST_SCRIPT_TEMPLATE.md`.

## JSON Output Format

Test scripts output JSON arrays with test objects:

```json
[
  {
    "test_name": "Test Name",
    "command": "command executed",
    "result": "output of command",
    "status": "pass|fail|partial",
    "notes": "optional notes"
  },
  ...
]
```

The orchestrator parses this JSON and renders it to HTML table rows.

## Configuration Variables

All test scripts have access to:

```bash
# Host info (read-only)
$HOSTNAME_FQDN                # Fully qualified hostname
$PRIMARY_IP                   # Primary IP address

# Thresholds (can be overridden by environment)
$MIN_LINK_SPEED_MBPS          # Ethernet speed threshold
$MIN_DOWNLOAD_MBPS            # Download speed threshold
$MIN_UPLOAD_MBPS              # Upload speed threshold

# Speedtest servers (optional)
$SPEEDTEST_SERVER_NEARBY      # Nearby server ID
$SPEEDTEST_SERVER_EU          # EU server ID

# Flags (booleans)
$HEADLESS_MODE                # --headless flag
$NOBURN_MODE                  # --noburn flag
$NOINSTALL_MODE               # --noinstall flag
$NOCHECK_MODE                 # --nocheck flag

# Output file
$OUTPUT_FILE                  # HTML report path
```

## Execution Flow

### Test Execution Order

Tests execute in manifest order (defined by JSON order):

1. 001-system (System info)
2. 002-cpu (CPU info)
3. 003-ram (RAM info)
4. 004-nvme (Storage)
5. 005-gpu (GPU info)
6. 006-ethernet (Ethernet)
7. 007-infiniband (InfiniBand)
8. 008-security (Security audit)
9. 009-speedtest (Network speed)
10. 010-software (Packages)
11. 011-services (Services)
12. 012-benchmarks (Benchmarks)

Order matters because some tests depend on prior packages being installed.

### Flag Handling

All flags are shared across test scripts via exported variables:

- `--headless`: Tests run non-interactively; `HEADLESS_MODE=true`
- `--noburn`: Skip benchmark tests; `NOBURN_MODE=true`
- `--noinstall`: Skip software installation; `NOINSTALL_MODE=true`
- `--nocheck`: Legacy mode; `NOCHECK_MODE=true`

Individual test scripts check flags using `should_skip_test()` if applicable.

## Development Workflow

### Creating a New Test

1. Copy template from `TEST_SCRIPT_TEMPLATE.md`
2. Create `tests.d/NNN-name.sh`
3. Implement test logic using provided functions
4. Add entry to `tests.manifest.json`
5. Test independently: `bash tests.d/NNN-name.sh | jq .`
6. Run full suite: `sudo ./hpctests.sh --nocheck`
7. Verify HTML output

### Debugging

Test a single script:
```bash
bash tests.d/001-system.sh | jq .
```

Enable verbose bash:
```bash
bash -x tests.d/001-system.sh 2>&1 | head -50
```

Check JSON validity:
```bash
bash tests.d/001-system.sh | jq . > /dev/null && echo "Valid JSON"
```

## Migration from Original

The original `hpctests.sh` is backed up as `hpctests.sh.backup`. The refactored version (`hpctests_new.sh` or the updated `hpctests.sh`) provides identical functionality with:

- Same HTML output format
- Same command-line interface
- Same test results
- Improved maintainability

## Performance Considerations

- Tests run sequentially (order matters for dependencies)
- Speedtest and benchmarks are the longest-running tests
- Use `--noburn` to skip time-consuming benchmarks during development
- Set appropriate `timeout_seconds` in manifest for monitoring

## Backward Compatibility

The refactored system maintains full backward compatibility:
- All command-line flags work identically
- HTML output format is unchanged
- Test content is identical
- All existing workflows continue to work

## Best Practices

1. **Keep test scripts focused**: Each script tests one category
2. **Use shared functions**: Leverage `config.sh` functions
3. **Handle failures gracefully**: Record in JSON `status`, don't exit with errors
4. **Check dependencies**: Gracefully skip if tools missing
5. **Self-contained tests**: Never depend on other test scripts
6. **Document tests**: Add comments explaining test purpose
7. **Test independently**: Verify JSON output before integrating
8. **Update manifest**: Keep metadata current and accurate

## Future Enhancements

Possible improvements to the framework:

- Parallel test execution (careful with dependencies)
- Timeout enforcement by orchestrator
- Test result caching
- Configurable HTML themes
- Extended test metadata (author, version, maintainer)
- Test dependencies resolution
- Pre/post-test hooks
- Test result assertions/validation
- Email/webhook reporting integration

## Troubleshooting

**Test script not running**: Make sure it's executable (`chmod +x`)

**JSON parsing error**: Validate with `jq` or `python3 -m json.tool`

**Missing dependencies**: Check manifest and implement fallbacks in test script

**Slow execution**: Use `--noburn` to skip benchmarks during testing

**HTML not generated**: Check orchestrator logs for errors

## Support

For questions or issues:
1. Check `TEST_SCRIPT_TEMPLATE.md` for examples
2. Review existing test scripts in `tests.d/`
3. Examine `config.sh` for available utilities
4. Check manifest for test ordering and flags
