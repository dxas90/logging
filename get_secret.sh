#!/bin/bash
set -euo pipefail

ITEM_ID="${ITEM_ID:-e5e828fd-10c5-46bc-a420-92434a3a4b7d}"

usage() {
  cat <<'EOF' >&2
Usage: get_secret FIELD_NAME
Fetches a Bitwarden field value using the Bitwarden CLI for the item ID embedded in this script.
FIELD_NAME should be the exact field key (for example: username, password, notes).
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

field_name="$1"

# Check if bw CLI is installed
if ! command -v bw &> /dev/null; then
  echo "Error: Bitwarden CLI (bw) is not installed" >&2
  exit 1
fi

# Check if already logged in / session exists
if ! bw unlock --check &> /dev/null; then
  echo "Error: Bitwarden vault is locked. Please run 'bw unlock' first." >&2
  exit 1
fi

bw sync &> /dev/null
# Get the item and extract the field value using jq
bw get item "${ITEM_ID}" | jq -r ".fields[] | select(.name == \"${field_name}\") | .value"
