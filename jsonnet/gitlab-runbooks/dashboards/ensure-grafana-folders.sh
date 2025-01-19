#!/usr/bin/env bash
# vim: ai:ts=2:sw=2:expandtab

set -euo pipefail

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

source "grafana-tools.lib.sh"

usage() {
  cat <<-EOF
  Usage $0 [Dh]

  DESCRIPTION
    This script ensures that all Grafana folders exist
    each directory under the dashboards directory
    containing dashboards needs to match with a folder
    in Grafana. This script ensures that.

    GRAFANA_API_TOKEN must be set in the environment

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

dry_run=${dry_run:-}

if [[ -z $dry_run && -z ${GRAFANA_API_TOKEN:-} ]]; then
  echo "You must set GRAFANA_API_TOKEN to use this script, or run in dry run mode"
  usage
  exit 1
fi

prepare

function list_local_folders() {
  (find_dashboards | while read -r line; do
    relative=${line#"./"}
    dirname "$relative"
  done) | sort -u
}

function list_remote_folders() {
  call_grafana_api "https://dashboards.gitlab.net/api/folders/" | jq -r '.[]|.uid' | sort -u
}

function list_missing_folders() {
  comm -23 <(list_local_folders) <(list_remote_folders) | sort -u
}

if [[ -n $dry_run ]]; then
  list_missing_folders
else
  list_missing_folders | while IFS= read -r folder; do
    ./create-grafana-folder.sh "${folder}" "${folder}"
  done
fi
