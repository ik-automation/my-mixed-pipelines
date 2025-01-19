#!/usr/bin/env bash
# vim: ai:ts=2:sw=2:expandtab

set -euo pipefail

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

VENDOR_DIR="${SCRIPT_DIR}/../vendor"

if [[ ! -d "${VENDOR_DIR}" ]]; then
  echo >&2 "${VENDOR_DIR} directory not found, running scripts/bundler.sh to install dependencies..."
  "${SCRIPT_DIR}/../scripts/bundler.sh"
fi

# Install jsonnet dashboards
for mixin in *.mixin.libsonnet; do
  name="${mixin%.mixin.libsonnet}"
  rm -rf "$name"
  mkdir "$name"
  jsonnet -J "${VENDOR_DIR}" -m "$name" "$mixin"
done
