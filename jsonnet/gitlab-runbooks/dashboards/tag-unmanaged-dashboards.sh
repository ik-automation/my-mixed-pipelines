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
    This script tags dashboards not managed through git

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

dry_run="${dry_run:-}"

if [[ -z "${GRAFANA_API_TOKEN:-}" ]]; then
  echo "You must set GRAFANA_API_TOKEN to use this script, or run in dry run mode"
  usage
  exit 1
fi

find_unmanaged_dashboards() {
  call_grafana_api 'https://dashboards.gitlab.net/api/search?limit=5000&type=dash-db' |
    jq -cM '. - map(select(.tags[] | contains ("managed")))'
}

add_tag() {
  jq -rcM '
    .dashboard.tags = .dashboard.tags + [ "unmanaged" ] |
    .dashboard.schemaVersion = ( .dashboard.schemaVersion + 1 ) |
    .dashboard.version = ( .meta.version + 1 ) |
    .message = "Add unmanaged tag" |
    .folderId = .meta.folderId |
    .overwrite = true
  '
}

if [[ -n "${dry_run}" ]]; then
  find_unmanaged_dashboards | jq -r '.[] | [.id, .uid, .url, .title]|@csv'
else
  find_unmanaged_dashboards | jq -rcM '.[].uid' | while read -r dashboard_uid; do
    echo "Adding tag to '${dashboard_uid}'"
    tmpfile=$(mktemp)
    call_grafana_api "https://dashboards.gitlab.net/api/dashboards/uid/${dashboard_uid}" | add_tag >"${tmpfile}"
    call_grafana_api "https://dashboards.gitlab.net/api/dashboards/db" -XPOST --data-binary "@${tmpfile}"
    rm "${tmpfile}"
  done
fi
