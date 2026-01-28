#!/usr/bin/env bash
# generate_clush_config.sh
# Create a ClusterShell (clush) groups file from IPs listed in clusterip.txt
# Default output: ~/.config/clustershell/groups.d/cluster.yaml
# Usage examples:
#   ./generate_clush_config.sh                      # uses ./clusterip.txt, group name "cluster"
#   ./generate_clush_config.sh -g hpc               # write ~/.config/clustershell/groups.d/hpc.yaml
#   ./generate_clush_config.sh -i /path/ips.txt     # custom input file
#   ./generate_clush_config.sh -o ./mygroup.yaml    # custom output path
#   ./generate_clush_config.sh --dry-run            # print YAML to stdout only

set -euo pipefail

# Defaults
GROUP_NAME="cluster"
INPUT_FILE=""
OUTPUT_FILE=""
DRY_RUN=0

print_usage() {
  cat <<'USAGE'
Generate ClusterShell (clush) groups YAML from a list of IPv4 addresses.

Options:
  -g, --group <name>     Group name to create (default: cluster)
  -i, --input <file>     Input file path (default: clusterip.txt in this script's directory)
  -o, --output <file>    Output file path (default: ~/.config/clustershell/groups.d/<group>.yaml)
      --dry-run          Print the generated YAML to stdout instead of writing a file
  -h, --help             Show this help

Notes:
- Lines starting with # or blank lines are ignored.
- Only valid IPv4 addresses are included; invalid lines are skipped with a warning.
- Duplicates are removed while preserving original order.

Examples:
  ./generate_clush_config.sh
  ./generate_clush_config.sh -g hpc
  ./generate_clush_config.sh -i ./clusterip.txt -o ./hpc.yaml
  ./generate_clush_config.sh --dry-run | tee hpc.yaml

Once generated, you can target the group with clush using:
  clush -w @<group> <command>
Example:
  clush -w @cluster hostname
USAGE
}

# Resolve script directory for default input
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--group)
      [[ $# -lt 2 ]] && { echo "Error: missing value for $1" >&2; exit 1; }
      GROUP_NAME="$2"; shift 2;;
    -i|--input)
      [[ $# -lt 2 ]] && { echo "Error: missing value for $1" >&2; exit 1; }
      INPUT_FILE="$2"; shift 2;;
    -o|--output)
      [[ $# -lt 2 ]] && { echo "Error: missing value for $1" >&2; exit 1; }
      OUTPUT_FILE="$2"; shift 2;;
    --dry-run)
      DRY_RUN=1; shift;;
    -h|--help)
      print_usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2
      print_usage
      exit 1;;
  esac
done

# Defaults for paths
if [[ -z "${INPUT_FILE}" ]]; then
  INPUT_FILE="${SCRIPT_DIR}/clusterip.txt"
fi

if [[ -z "${OUTPUT_FILE}" ]]; then
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
  OUTPUT_DIR="${XDG_CONFIG_HOME}/clustershell/groups.d"
  OUTPUT_FILE="${OUTPUT_DIR}/${GROUP_NAME}.yaml"
else
  OUTPUT_DIR="$(dirname "${OUTPUT_FILE}")"
fi

# Validate input file exists
if [[ ! -f "${INPUT_FILE}" ]]; then
  echo "Error: input file not found: ${INPUT_FILE}" >&2
  exit 1
fi

# Helpers
is_valid_ipv4() {
  local ip="$1"
  # Basic format check
  if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 1
  fi
  # Octet range check (0-255)
  local IFS='.'
  read -r o1 o2 o3 o4 <<<"$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    # Reject leading plus/minus and empty
    [[ -z "$o" || "$o" == *[!0-9]* ]] && return 1
    # numeric compare
    if (( o < 0 || o > 255 )); then
      return 1
    fi
  done
  return 0
}

# Read, clean, validate, and deduplicate (preserve order)
ips=()
dedup_list=""

while IFS= read -r line || [[ -n "$line" ]]; do
  # Remove CR, strip comments, trim whitespace
  line="${line%$'\r'}"
  line="${line%%#*}"
  # Trim leading/trailing whitespace using awk
  line="$(printf '%s' "$line" | awk '{gsub(/^\s+|\s+$/,""); print}')"
  [[ -z "$line" ]] && continue

  if ! is_valid_ipv4 "$line"; then
    echo "Warning: skipping invalid IPv4 address: $line" >&2
    continue
  fi

  # Deduplicate while preserving order
  if ! printf '%s\n' "$dedup_list" | grep -Fxq "$line"; then
    ips+=("$line")
    dedup_list+="$line"$'\n'
  fi

done < "$INPUT_FILE"

if [[ ${#ips[@]} -eq 0 ]]; then
  echo "Error: no valid IPv4 addresses found in ${INPUT_FILE}" >&2
  exit 1
fi

# Generate YAML content
create_yaml() {
  printf '%s:\n' "$GROUP_NAME"
  local ip
  for ip in "${ips[@]}"; do
    printf '  - %s\n' "$ip"
  done
}

if [[ $DRY_RUN -eq 1 ]]; then
  create_yaml
  exit 0
fi

# Ensure destination directory and write file
mkdir -p "$OUTPUT_DIR"

TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

create_yaml > "$TMPFILE"

# Move into place atomically and set permissions
mv "$TMPFILE" "$OUTPUT_FILE"
chmod 0644 "$OUTPUT_FILE"
trap - EXIT

cat <<EOF
ClusterShell groups file written:
  $OUTPUT_FILE

Group name: $GROUP_NAME
Members: ${#ips[@]} IP(s)

Use with clush like:
  clush -w @${GROUP_NAME} hostname
EOF
