# Getting Started: Creating Your First Test Script

This guide is for you if:
- You're comfortable using bash commands on the terminal
- You understand basic Linux commands like `ls`, `grep`, `cat`, `echo`
- You want to add your own test to the HPC test system
- You're not sure about scripting concepts yet

**Don't worry if you don't understand everything at first—we'll go through it step by step.**

---

## Table of Contents

1. [Before You Start](#before-you-start)
2. [Understanding the System](#understanding-the-system)
3. [Your First Test Script](#your-first-test-script)
4. [Complete Walkthrough](#complete-walkthrough)
5. [Testing Your Script](#testing-your-script)
6. [Adding to the System](#adding-to-the-system)
7. [Troubleshooting](#troubleshooting)

---

## Before You Start

### Step 1: Verify Your Environment

Open a terminal and run these commands to check you have everything:

```bash
# Check you're in the right directory
pwd

# Expected output should end with: /home/david/code/hpctest
```

```bash
# Check that bash is available
bash --version

# Expected output: GNU bash, version X.X.X...
```

```bash
# Check the test directory structure exists
ls -la tests.d/

# Expected output: List of 001-system.sh, 002-cpu.sh, etc.
```

```bash
# Check you have the config.sh file
ls -la config.sh

# Expected output: shows config.sh with read/execute permissions
```

If any of these commands fail, ask a senior engineer to help set up your environment.

### Step 2: Install Required Tools (Optional but Recommended)

These tools help verify your work. Install them if you don't have them:

```bash
# Install jq (for validating JSON output)
sudo apt-get update
sudo apt-get install -y jq

# Verify installation
jq --version

# Expected output: jq-X.X.X
```

```bash
# Install nano or vim (for editing files)
# nano is easier for beginners
sudo apt-get install -y nano

# Verify installation
nano --version

# Expected output: GNU nano, version X.X.X
```

### Step 3: Understand File Permissions

In Linux, files have permissions that control who can read, write, and execute them:

```bash
# Check permissions of an existing test script
ls -l tests.d/001-system.sh

# Expected output something like:
# -rwxr-xr-x 1 root root 1234 Jan 28 12:34 tests.d/001-system.sh
#  ^^^                        ^
#  |                          - this means it's executable
#  |-- r (read), w (write), x (execute)
```

The key thing: test scripts need the **x (execute)** permission. We'll add that later.

---

## Understanding the System

### What Happens When Tests Run?

When you run `sudo ./hpctests.sh`, here's what happens:

```
1. Main script (hpctests.sh) starts
2. It reads tests.manifest.json (tells it which tests to run and in what order)
3. For each test in the list:
   a. It finds the test script (like tests.d/001-system.sh)
   b. Runs the test script
   c. Captures the JSON output from that script
   d. Puts the results in an HTML report
4. Creates final HTML file with all results
```

### What is JSON?

JSON is a simple format for storing data. Here's an example:

```json
{
  "test_name": "My Test",
  "command": "ls -la",
  "result": "total 24\n-rw-r--r-- 1 root",
  "status": "pass",
  "notes": "Everything worked"
}
```

The key points:
- Everything is in quotes (like `"test_name"`)
- Colons separate the label from the value
- Commas separate items
- Square brackets `[ ]` are used for lists

Don't worry—you don't write JSON directly. The helper functions do it for you.

### What is a Test Script?

A test script is a small program that:

1. Runs Linux commands
2. Collects the output
3. Tells us if it passed or failed
4. Outputs the results as JSON

That's it! Here's a simple example:

```bash
#!/bin/bash

# This runs a command
result=$(whoami)

# This outputs the result
echo "User is: $result"
```

When we run this, it outputs: `User is: root` (if you're root)

---

## Your First Test Script

### Concept: Creating a "Hello World" Test

Let's create a super simple test that checks if a file exists.

**What we'll test**: Does `/etc/hostname` exist?
**Why**: It should always exist on Linux systems
**Expected result**: pass

### Step-by-Step

#### Step 1: Choose Your Test Number

List existing tests:

```bash
ls tests.d/

# Output:
# 001-system.sh
# 002-cpu.sh
# ...
# 012-benchmarks.sh
```

The next available number is `013`. But wait—let's start with a test before them.

For this example, we'll create `tests.d/099-example.sh` (using 099 so it doesn't interfere with official tests).

#### Step 2: Create the File

Create an empty file:

```bash
# Create the file
touch tests.d/099-example.sh

# Check it was created
ls -la tests.d/099-example.sh

# Expected output shows the file exists but has 0 bytes
```

#### Step 3: Edit the File

Open the file in an editor:

```bash
nano tests.d/099-example.sh
```

You'll see a blank editor screen. Now type the following (exactly as shown):

```bash
#!/bin/bash

# ==============================================================================
# Test Script: My Example Test
# Category: Examples
# Description: Simple test to verify the system has an etc/hostname file
# ==============================================================================

# Import shared functions from config.sh
source "$(dirname "$0")/../config.sh"

# Start the JSON output
start_json_output

# Run a test: Check if /etc/hostname exists
if [[ -f /etc/hostname ]]; then
    result="File exists"
    status="pass"
    notes="System hostname file found"
else
    result="File does not exist"
    status="fail"
    notes="Critical file missing"
fi

# Output the test result
output_test_result "Hostname File Check" "test -f /etc/hostname" "$result" "$status" "$notes"

# End the JSON output
finish_json_output
```

#### Step 4: Save the File

In nano:
1. Press `Ctrl+O` (the letter O, not zero)
2. Press `Enter` to confirm the filename
3. Press `Ctrl+X` to exit

You should be back at your terminal prompt.

#### Step 5: Make the File Executable

```bash
# Add execute permission
chmod +x tests.d/099-example.sh

# Verify it's executable
ls -l tests.d/099-example.sh

# Expected output: should show an 'x' in permissions
# -rwxr-xr-x
```

#### Step 6: Test Your Script

```bash
# Run your script
bash tests.d/099-example.sh

# Expected output (JSON format):
# [
#   {
#     "test_name": "Hostname File Check",
#     "command": "test -f /etc/hostname",
#     "result": "File exists",
#     "status": "pass",
#     "notes": "System hostname file found"
#   }
# ]
```

**Congratulations! Your first test script works!**

---

## Complete Walkthrough

Now let's create a more realistic test. We'll test something slightly more complex.

### Creating a Memory Test

Let's create a test that checks available memory.

#### Step 1: Plan Your Test

Before you code, think about:
- What command shows memory? → `free -h`
- What are we testing? → That memory info can be retrieved
- What could fail? → `free` command not available
- What statuses? → pass, partial (if command missing), fail

#### Step 2: Create a New Script File

```bash
nano tests.d/099-memory-info.sh
```

Type this content:

```bash
#!/bin/bash

# ==============================================================================
# Test Script: Memory Information
# Category: System Information
# Description: Check available system memory and swap
# ==============================================================================

# Always source config.sh first—this gives us helper functions
source "$(dirname "$0")/../config.sh"

# Tell the system we're starting JSON output
start_json_output

# TEST 1: Check Total Memory
# The 'free' command shows memory. 'free -h' shows it in human-readable format (MB, GB)
# We capture the output in a variable called 'result'
result=$(free -h | grep Mem: | awk '{print $2}')

# Check if we got a result
if [[ -z "$result" ]]; then
    # Empty result means something went wrong
    status="fail"
    notes="Could not determine memory size"
    result="No output from free command"
else
    # We got a result, so it passed
    status="pass"
    notes="Successfully retrieved memory information"
fi

# Output this test result
output_test_result "Total Memory" "free -h | grep Mem: | awk '{print \$2}'" "$result" "$status" "$notes"

# Add a comma between tests (required by JSON format)
echo ","

# TEST 2: Check Swap Memory
result=$(free -h | grep Swap: | awk '{print $2}')

if [[ -z "$result" ]]; then
    status="fail"
    notes="Could not determine swap size"
    result="No output from free command"
else
    status="pass"
    notes="Successfully retrieved swap information"
fi

output_test_result "Total Swap" "free -h | grep Swap: | awk '{print \$2}'" "$result" "$status" "$notes"

# Tell the system we're done with JSON output
finish_json_output
```

#### Step 3: Make It Executable

```bash
chmod +x tests.d/099-memory-info.sh
```

#### Step 4: Test It

```bash
bash tests.d/099-memory-info.sh

# Expected output:
# [
#   {
#     "test_name": "Total Memory",
#     "command": "free -h | grep Mem: | awk '{print $2}'",
#     "result": "31Gi",
#     "status": "pass",
#     "notes": "Successfully retrieved memory information"
#   },
#   {
#     "test_name": "Total Swap",
#     "command": "free -h | grep Swap: | awk '{print $2}'",
#     "result": "0B",
#     "status": "pass",
#     "notes": "Successfully retrieved swap information"
#   }
# ]
```

#### Step 5: Validate the JSON (Optional but Recommended)

If you installed `jq`:

```bash
bash tests.d/099-memory-info.sh | jq .

# Should output: Valid JSON (pretty-printed)
# If there's an error, jq will tell you what's wrong
```

---

## Testing Your Script

### Test 1: Does It Run Without Errors?

```bash
bash tests.d/099-memory-info.sh

# Should show JSON output, no error messages
```

### Test 2: Is the JSON Valid?

If you have `jq`:

```bash
bash tests.d/099-memory-info.sh | jq . > /dev/null && echo "JSON is valid" || echo "JSON has errors"

# Expected: JSON is valid
```

### Test 3: Do All Fields Have Values?

```bash
bash tests.d/099-memory-info.sh | jq '.[0]'

# Should show all fields filled in:
# - test_name: has a value
# - command: has a value
# - result: has a value (or at least exists)
# - status: is "pass", "fail", or "partial"
# - notes: has a value (can be empty string "")
```

### Test 4: Can It Run as Root?

Since the main system runs as root, test it that way:

```bash
sudo bash tests.d/099-memory-info.sh

# Should work the same way
```

---

## Adding to the System

Once your test script is working, you need to register it in the manifest.

### Step 1: Understand the Manifest

The manifest is in `tests.manifest.json`. Let's look at an existing entry:

```bash
cat tests.manifest.json | head -30

# Shows JSON entries for each test
```

Each test has:
- `id`: Name (must be unique)
- `script`: Path to the script file
- `category`: What section in the HTML report
- `description`: What the test does
- `dependencies`: Commands it needs (optional)
- `depends_on_tests`: Other tests that must run first (optional)
- `skip_flags`: Flags that skip this test (optional)
- `timeout_seconds`: Max time to wait

### Step 2: Add Your Test to the Manifest

Open the manifest file:

```bash
nano tests.manifest.json
```

Look at the end of the file. You'll see the last test entry ends with `}`

Before that closing `}` of the tests array, add a comma and your entry.

Find this line near the end:

```json
  ]
}
```

Change it to:

```json
    },
    {
      "id": "099-memory-info",
      "script": "tests.d/099-memory-info.sh",
      "category": "System Information",
      "description": "Check available system memory and swap",
      "dependencies": ["free"],
      "depends_on_tests": [],
      "skip_flags": [],
      "timeout_seconds": 30
    }
  ]
}
```

**Important**: The entry BEFORE your new one needs a comma after it!

### Step 3: Validate the JSON

The manifest is JSON, so it must be valid:

```bash
# Check if JSON is valid
jq . tests.manifest.json > /dev/null && echo "Manifest is valid" || echo "Manifest has errors"

# If invalid, jq will tell you which line
jq . tests.manifest.json

# Look for the error message
```

### Step 4: Run a Quick Test

Before running the full suite, test one script:

```bash
bash tests.d/099-memory-info.sh | jq .

# Should show valid JSON output
```

---

## Running Your Test in the Full System

Now your test is ready to run with the full suite.

### Test 1: Run All Tests (Headless Mode)

```bash
sudo ./hpctests.sh --headless --noburn

# Should run all tests including yours
# Output will show your test running
```

### Test 2: Check the HTML Report

When finished, you'll see:

```
Report saved to: system_test_report_2026-01-28_12-34-44.html
```

Open the HTML file in a browser to see your results. Your test should appear under "System Information" section.

### Test 3: Find Your Test in the Report

Open the HTML file and look for:
- Section heading "System Information"
- Your test name "Total Memory" and "Total Swap"
- Your test status (PASS or FAIL badge)

---

## Common Patterns (Recipes)

These are copy-paste templates for common test types.

### Pattern 1: Simple Command Test

```bash
result=$(your_command_here 2>&1)
status="pass"
notes=""
output_test_result "Test Name" "your_command_here" "$result" "$status" "$notes"
```

### Pattern 2: Test with Dependency Check

```bash
if command -v tool_name &>/dev/null; then
    result=$(tool_name arg 2>&1)
    status="pass"
else
    result="tool_name not installed"
    status="partial"
fi
notes=""
output_test_result "Test Name" "tool_name arg" "$result" "$status" "$notes"
```

### Pattern 3: Test with Conditional Logic

```bash
result=$(some_command 2>&1)
status="pass"
notes=""

if [[ -z "$result" ]]; then
    # Empty result is bad
    status="fail"
    notes="Command returned no output"
elif [[ "$result" == *"error"* ]]; then
    # Result contains "error"
    status="fail"
    notes="Command reported an error"
fi

output_test_result "Test Name" "some_command" "$result" "$status" "$notes"
```

### Pattern 4: Multiple Tests in One Script

```bash
# Test 1
result=$(cmd1 2>&1)
output_test_result "Test 1" "cmd1" "$result" "pass" ""
echo ","  # <-- Comma between tests!

# Test 2
result=$(cmd2 2>&1)
output_test_result "Test 2" "cmd2" "$result" "pass" ""
# No comma after last test
```

---

## Troubleshooting

### Problem 1: "Permission Denied" Error

```bash
bash tests.d/099-memory-info.sh

# Error: Permission denied
```

**Solution**: Make it executable

```bash
chmod +x tests.d/099-memory-info.sh
```

### Problem 2: "config.sh: No such file or directory"

```bash
bash tests.d/099-memory-info.sh

# Error: config.sh: No such file or directory
```

**Solution**: The source line is wrong. Make sure line 9 is:

```bash
source "$(dirname "$0")/../config.sh"
```

This finds config.sh automatically, no matter where you run the script from.

### Problem 3: JSON Output Has Errors

```bash
bash tests.d/099-memory-info.sh | jq .

# Error: parse error...
```

**Solution**: Check for these common issues:

1. **Missing commas** between test results (except after last one)
   ```bash
   output_test_result ...
   echo ","    # <-- Need this comma!
   output_test_result ...
   ```

2. **Mismatched quotes** in the command string
   ```bash
   # Wrong:
   output_test_result "Test" "ls -la" "$result" "pass" ""
   
   # Right (escape the quotes in the command):
   output_test_result "Test" "ls -la" "$result" "pass" ""
   ```

3. **Missing start/finish JSON calls**
   ```bash
   start_json_output  # <-- Must be first!
   
   # ... tests here ...
   
   finish_json_output # <-- Must be last!
   ```

### Problem 4: Test Shows "PARTIAL" Status in HTML

This usually means:
- A required command was not found (e.g., `free` command missing)
- Or you set status to "partial" intentionally

**Solution**: Install missing packages

```bash
# For memory test
sudo apt-get install -y procps
```

Or check your script logic—did you set status="partial" on purpose?

### Problem 5: Script Output is Cluttered

If your script output shows logs mixed with JSON:

```bash
# Wrong: Shows logs AND JSON
[12:34:56] Starting test...
[
  {
    "test_name": ...
```

**Solution**: Don't use `log` functions. Only use `output_test_result()` and JSON functions.

Remove lines like:
```bash
log "Running test..."  # Remove this!
```

### Problem 6: Can't Edit File in Nano

If you're stuck in nano:
1. Press `Ctrl+X` to exit
2. Press `N` if asked to save (don't save if you didn't want changes)
3. You're back at terminal

If you want to save:
1. Press `Ctrl+O`
2. Press `Enter`
3. Press `Ctrl+X`

---

## Checklist: Before You Submit

When your test is ready, verify this checklist:

- [ ] Script file created at `tests.d/NNN-yourname.sh`
- [ ] File is executable (`chmod +x ...`)
- [ ] Script starts with `#!/bin/bash`
- [ ] Script sources `config.sh` with `source "$(dirname "$0")/../config.sh"`
- [ ] Script starts with `start_json_output`
- [ ] Script ends with `finish_json_output`
- [ ] All test results use `output_test_result()` function
- [ ] Commas between test results (not after last one)
- [ ] JSON output is valid (`jq` validates it)
- [ ] Test runs without errors: `bash tests.d/NNN-yourname.sh`
- [ ] Test runs as root: `sudo bash tests.d/NNN-yourname.sh`
- [ ] Manifest entry added with unique `id`
- [ ] Manifest JSON is valid: `jq . tests.manifest.json`
- [ ] Script handles missing dependencies gracefully
- [ ] All status values are "pass", "fail", or "partial"

---

## Next Steps

Once your test works:

1. **Get code review** - Ask a senior engineer to review your script and manifest entry
2. **Test in full suite** - Run `sudo ./hpctests.sh --headless --noburn`
3. **Check HTML report** - Open the generated HTML file
4. **Commit changes** - If approved, commit to git:
   ```bash
   git add tests.d/099-yourname.sh tests.manifest.json
   git commit -m "Add test for [description]"
   ```

---

## Quick Reference

### Key Commands

```bash
# Create a file
nano tests.d/NNN-name.sh

# Make executable
chmod +x tests.d/NNN-name.sh

# Test your script
bash tests.d/NNN-name.sh

# Validate JSON
bash tests.d/NNN-name.sh | jq .

# Edit manifest
nano tests.manifest.json

# Validate manifest
jq . tests.manifest.json

# Run full test suite
sudo ./hpctests.sh --headless --noburn
```

### Key Functions (in config.sh)

```bash
# Start JSON output
start_json_output

# Output a test result
output_test_result "Name" "command" "result" "status" "notes"

# End JSON output
finish_json_output

# Check if command exists
if command -v cmd_name &>/dev/null; then ... fi

# Check if test should be skipped
if should_skip_test "--noburn"; then ... fi
```

### Status Values

```bash
status="pass"      # Test passed
status="fail"      # Test failed or error
status="partial"   # Test ran but incomplete (e.g., tool missing)
```

---

## Learning Resources

To understand bash better:

- **Variables**: `$variable` holds a value
- **Command substitution**: `result=$(command)` runs `command` and stores output in `result`
- **String comparison**: `[[ $var == "value" ]]` checks if they match
- **File tests**: `[[ -f /path ]]` checks if file exists
- **Conditionals**: `if ... then ... else ... fi` makes decisions

---

## Getting Help

If you're stuck:

1. **Check existing scripts** - Look at `tests.d/001-system.sh` for examples
2. **Read TEST_SCRIPT_TEMPLATE.md** - Has detailed examples
3. **Ask a colleague** - Senior engineers can help debug
4. **Check error messages** - They usually tell you what's wrong

---

**Congratulations! You now know how to create and add test scripts to the HPC test system.**

Start with a simple test, get it working, then add more complex logic once you're comfortable.

Good luck! 🚀
