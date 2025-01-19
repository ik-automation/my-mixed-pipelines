#!/usr/bin/env bash
# vim: ai:ts=2:sw=2:expandtab

set -euo pipefail

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RULES_JSONNET_FILE=protected-grafana-dashboards.jsonnet

cd "${SCRIPT_DIR}"

source "grafana-tools.lib.sh"

usage() {
  cat <<-EOF
  Usage $0 [Dh]

  DESCRIPTION
    This script deletes dashboards not managed through git
    GRAFANA_API_TOKEN must be set in the environment

    GRAFANA_FOLDER (optional): Override folder.
    Useful for testing.

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

if [[ -z ${GRAFANA_API_TOKEN:-} ]]; then
  echo "You must set GRAFANA_API_TOKEN to use this script, or run in dry run mode"
  usage
  exit 1
fi

find_orphaned_dashboards() {
  call_grafana_api 'https://dashboards.gitlab.net/api/search?limit=5000&type=dash-db' | jq --argjson protected "$(jsonnet "$RULES_JSONNET_FILE")" -cM '
    .[] |
    . as $i |
    select([$protected.dashboardUids[] | contains($i.uid)] | any | not) |
    select($i.folderTitle == null or ([$protected.folderTitles[] | contains($i.folderTitle)] | any | not))
    ' | while IFS= read -r line; do
    local dashboard_id
    dashboard_id=$(jq -nr --argjson input "$line" '$input.id')

    (
      call_grafana_api "https://dashboards.gitlab.net/api/dashboards/id/$dashboard_id/versions" |
        jq --argjson input "$line" -cM '
          max_by(.created) |
          select(((now - (.created | fromdate)) / 86400) > 7) |
          {
            dashboard_id: $input.id,
            dashboard_uid: $input.uid,
            dashboard_url: $input.url,
            folderTitle: $input.folderTitle,
            created: .created,
            createdBy: .createdBy
          }'
    ) || true
  done
}

find_empty_folders() {
  nonEmptyFolders=$(call_grafana_api "https://dashboards.gitlab.net/api/search?limit=5000&type=dash-db" | jq -cM '[ .[] | select(.folderId != null) | .folderUid ] | unique')
  call_grafana_api 'https://dashboards.gitlab.net/api/search?limit=5000&type=dash-folder' | jq --argjson nonEmptyFolders "$nonEmptyFolders" --argjson protected "$(jsonnet "$RULES_JSONNET_FILE")" -cMr '
    (
      [
        .[] |
        . as $i |
        select([$protected.folderTitles[] | contains($i.title)] | any | not) |
        select($i.uid != "playground-FOR-TESTING-ONLY") |
        .uid
      ]
      -
      $nonEmptyFolders
    ) |
    .[]
  '
}

if [[ -n $dry_run ]]; then
  find_orphaned_dashboards "$@" | jq -r '[.dashboard_id,.dashboard_url,.folderTitle,.created,.createdBy]|@csv'
else
  find_orphaned_dashboards "$@" | jq -rcM '.dashboard_uid' | while read -r dashboard_uid; do
    call_grafana_api "https://dashboards.gitlab.net/api/dashboards/uid/$dashboard_uid" -XDELETE
  done

  find_empty_folders | while read -r folder_uid; do
    call_grafana_api "https://dashboards.gitlab.net/api/folders/$folder_uid" -XDELETE
  done
fi
