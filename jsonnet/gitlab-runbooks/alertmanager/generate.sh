#!/usr/bin/env bash
#
# Description: Generate the alertmanager.yml
#

set -euo pipefail
IFS=$'\n\t'

cd "$(dirname "${BASH_SOURCE[0]}")"

secrets_file="${ALERTMANAGER_SECRETS_FILE:-dummy-secrets.jsonnet}"

# Generate the raw YAML.
if ! jsonnet -J ../metrics-catalog -J ../services -J ../libsonnet -J . --ext-code-file "secrets_file=${secrets_file}" --multi . --string alertmanager.jsonnet; then
  echo "Failed to generate jsonnet yaml"
  exit 1
fi

# Pretty-format the YAML.
for file in *.yml *.yaml; do
  tmpfile=$(mktemp)
  ruby -ryaml -e 'puts YAML.load(ARGF.read).to_yaml' "${file}" >"${tmpfile}"
  mv -v "${tmpfile}" "${file}"
done
