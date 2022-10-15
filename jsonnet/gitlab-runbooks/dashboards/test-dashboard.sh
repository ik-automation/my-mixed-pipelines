#!/usr/bin/env bash
# vim: ai:ts=2:sw=2:expandtab

set -euo pipefail
# Fail on subshells failing, dashboards are generated in subshells
# But not on macOS, because that ships with an older version of bash
# that does not support this shell option yet
(shopt -p | grep inherit_errexit >/dev/null) && shopt -s inherit_errexit

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

source "grafana-tools.lib.sh"

usage() {
  cat <<-EOF
  Usage $0 [Dh] path-to-file.dashboard.jsonnet

  DESCRIPTION
    This script generates dashboards and uploads
    them to the playground folder on dashboards.gitlab.net

    GRAFANA_API_TOKEN must be set in the environment

    Read dashboards/README.md for more details

  FLAGS
    -D  run in Dry-run
    -h  help

EOF
}

while getopts ":Dh" o; do
  case "${o}" in
    D)
      dry_run="true"
      ;;
    h)
      usage
      exit 0
      ;;
    *) ;;

  esac
done

shift $((OPTIND - 1))

if [[ $# != 1 ]]; then
  usage
  exit 0
fi

dry_run=${dry_run:-}

prepare

dashboard_file=$1

if [[ -n $dry_run ]]; then
  generate_dashboards_for_file "${dashboard_file}"
  exit 0
else
  if [[ -z ${GRAFANA_API_TOKEN:-} ]]; then
    echo "You must set GRAFANA_API_TOKEN to use this script. Review the instructions in dashboards/README.md to details of how to obtain this token."
    exit 1
  fi

  dashboard_json=$(generate_dashboards_for_file "${dashboard_file}")
  if [[ -z "$dashboard_json" ]]; then
    echo 'Empty dashboard. Ignored!'
    exit 0
  fi

  echo "${dashboard_json}" | prepare_snapshot_requests | while IFS= read -r snapshot; do
    # Use http1.1 and gzip compression to workaround unexplainable random errors that
    # occur when uploading some dashboards
    response=$(echo "${snapshot}" | call_grafana_api https://dashboards.gitlab.net/api/snapshots -d @-)

    url=$(echo "${response}" | jq -r '.url')
    title=$(echo "${snapshot}" | jq -r '.dashboard.title')
    echo "Installed ${url} - ${title}"
  done
fi
