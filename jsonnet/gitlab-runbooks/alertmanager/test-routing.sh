#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
  echo "$@"
  exit 1
}

echo Running tests for displayed configuration
amtool config routes show --config.file "$1" -o extended

jsonnet --string "${SCRIPT_DIR}/routing-tests.jsonnet" --ext-str configFile="$1" | while read -r line; do
  sh -c "${line}"
done
