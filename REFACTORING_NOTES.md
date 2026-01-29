# HTML Refactoring - Direct Generation with Metadata

## Overview
Refactored hpctests system to directly generate enhanced HTML with embedded metadata and JSON test data, eliminating fragile grep/sed parsing that was causing crashes.

## Key Changes

### 1. Manifest Parsing - Fixed Loop Crash
**Problem**: Previous implementation used `grep -o` with regex patterns on JSON, which:
- Failed to properly handle escaped quotes and special characters
- Created misaligned arrays when manifest structure wasn't perfect
- Caused loop iteration issues when array lengths didn't match

**Solution**: Replace with robust `jq` JSON parsing:
```bash
tests_json=$(jq -c '.tests[]' "$MANIFEST_FILE" 2>/dev/null)
while IFS= read -r test_entry; do
    local script=$(echo "$test_entry" | jq -r '.script')
    local test_id=$(echo "$test_entry" | jq -r '.id')
    ...
done <<< "$tests_json"
```

Benefits:
- Validates JSON structure before processing
- Proper handling of special characters and escaped strings
- Clear error messages if manifest is invalid
- No array length mismatches

### 2. Enhanced HTML Metadata
Added server information meta tags to HTML `<head>`:
```html
<meta name="test-run-id" content="uuid-here" />
<meta name="test-date" content="2026-01-29T14:23:40Z" />
<meta name="hostname" content="server-hostname" />
<meta name="ip-address" content="192.168.1.100" />
```

### 3. Test Row Data Attributes
Each HTML table row now includes extraction-friendly data attributes:
```html
<tr data-test-id="system-name" 
    data-test-name="System Name" 
    data-category="System" 
    data-result="Dell PowerEdge R7625" 
    data-result-type="text" 
    data-status="pass">
  ...
</tr>
```

### 4. JSON Data Block
Embedded test data as application/json before closing `</body>`:
```html
<script type="application/json" id="test-data">
{
  "test_run_id": "uuid-here",
  "test_date": "2026-01-29T14:23:40Z",
  "server_info": {
    "hostname": "server-hostname",
    "ip_address": "192.168.1.100"
  },
  "tests": [
    {
      "test_id": "system-name",
      "test_name": "System Name",
      "category": "System",
      "command": "cat /sys/devices/virtual/dmi/id/product_name",
      "result": "Dell PowerEdge R7625",
      "result_type": "text",
      "status": "pass"
    },
    ...
  ]
}
</script>
```

## Config.sh Changes

### Global Test Data Collection
Added arrays to track test data across test scripts:
```bash
declare -a TEST_DATA_IDS
declare -a TEST_DATA_NAMES
declare -a TEST_DATA_CATEGORIES
declare -a TEST_DATA_COMMANDS
declare -a TEST_DATA_RESULTS
declare -a TEST_DATA_TYPES
declare -a TEST_DATA_STATUSES
TEST_RUN_ID=$(uuidgen)
TEST_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

### Enhanced output_html_result() Function
Extended signature to accept test metadata:
```bash
output_html_result "Test Name" "command" "result" "status" "notes" "test_id" "category" "result_type"
```

The function now:
1. Generates data attributes for HTML rows
2. Collects test data into global arrays for JSON generation
3. Appends to OUTPUT_FILE directly

## Test Script Updates

All test scripts need to be updated to pass test metadata:

**Before**:
```bash
output_html_result "System Name" "command" "result" "status" "notes"
```

**After**:
```bash
output_html_result "System Name" "command" "result" "status" "notes" "system-name" "System" "text"
```

Parameters:
- `test_id`: Lowercase with hyphens (e.g., `system-name`, `os-version`)
- `category`: Match manifest category (e.g., `System`, `CPU`, `RAM`)
- `result_type`: One of `text`, `numeric`, `boolean`

## Usage

The refactored scripts are 100% backward compatible:
```bash
sudo ./hpctests_new.sh              # Standard run
sudo ./hpctests_new.sh --headless   # Non-interactive
sudo ./hpctests_new.sh --noburn     # Skip benchmarks
```

## Benefits for Platform Implementation

This refactoring enables:

1. **API Data Extraction**: The JSON block can be parsed by the upload API to extract:
   - Server information (hostname, IP, make, model)
   - All test results with metadata
   - Test categories and result types

2. **Database Population**: The embedded JSON makes it easy to:
   - Store versioned test results
   - Track test categories
   - Index by test_id for configuration lookup

3. **Validation**: Data attributes on HTML rows enable:
   - Client-side validation
   - Report generation from HTML alone
   - Manual verification by engineers

4. **Extensibility**: The JSON block can be extended with:
   - Test-specific scoring ranges
   - Result unit conversions
   - Performance trend analysis

## Aligns With Platform Spec

These changes implement **Part 3: HTML Enhancement** from `PLATFORM_IMPLEMENTATION_SPEC.md`:

✓ Metadata in `<head>` section  
✓ Data attributes on test rows  
✓ JSON block before `</body>`  
✓ Server info extraction-ready  
✓ Test results properly categorized  

Ready for Phase 2 (HTML Parsing & Upload API).
