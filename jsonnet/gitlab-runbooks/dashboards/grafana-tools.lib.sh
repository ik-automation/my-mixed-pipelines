#!/usr/bin/env bash

function call_grafana_api() {
  local status_code
  local response_file
  response_file=$(mktemp)

  status_code=$(
    curl -H 'Expect:' --http1.1 --compressed --silent \
      -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -o "${response_file}" \
      -w "%{http_code}" \
      "$@"
  )

  if [[ $status_code =~ ^2.*$ ]]; then
    cat "$response_file"
    rm -f "$response_file"
    return 0
  fi

  echo >&2 "API call to $1 failed with $status_code:"
  cat >&2 "$response_file"
  echo >&2
  rm -f "$response_file"
  return 1
}

function resolve_folder_id() {
  call_grafana_api "https://dashboards.gitlab.net/api/folders/$1" | jq '.id'
}

function prepare() {
  if [[ ! -d "../vendor" ]]; then
    echo >&2 "../vendor directory not found, running scripts/bundler.sh to install dependencies..."
    "../scripts/bundler.sh"
  fi
}

function get_description() {
  local uploader_identifier="${CI_JOB_URL:-$USER}"
  echo "Uploaded by ${uploader_identifier} at $(date -u)"
}

function augment_dashboard() {
  local uid=$1
  local folder=$2

  local description
  description=$(get_description)

  jq -Mc --arg uid "$uid" --arg folder "$folder" --arg description "$description" '
  . * {
      uid: $uid,
      title: "\($folder): \(.title)",
      tags: (["managed", $folder] + .tags),
      description: "\($description)"
    }
  '
}

# This consumes dashboards in the form
# {
#   grafana_uid: dashboard,
#   grafana_uid_2: dashboard_2,
# }
# and produces one line per dashboard, including the description, etc
function augment_shared_dashboards() {
  local folder=$1

  local description
  description=$(get_description)

  jq -Mc --arg folder "$folder" --arg description "$description" '
  . as $d |
  keys[]|
  . as $key |
  $d[.] as $dashboard |
  $dashboard * {
      uid: "\($folder)-\($key)",
      title: "\($folder): \($dashboard.title)",
      tags: (["managed", $folder] + $dashboard.tags),
      description: "\($description)"
    }
  '
}

# Generates dashboards, outputs one dashboard per line
function generate_dashboards_for_file() {
  local file=$1
  local basename
  local uid
  basename=$(basename "$file")
  local relative=${file#"./"}

  folder=${GRAFANA_FOLDER:-$(dirname "$relative")}
  uid="${folder}-${basename%%.*}"

  if [[ "$file" == *".shared.jsonnet" ]]; then
    compiled_json=$(jsonnet_compile "${file}")
    if [[ $(echo "${compiled_json}" | jq 'length') -eq '0' ]]; then
      echo ''
    else
      echo "${compiled_json}" | augment_shared_dashboards "${folder}"
    fi
  elif [[ "$file" == *".jsonnet" ]]; then
    compiled_json=$(jsonnet_compile "${file}")
    if [[ $(echo "${compiled_json}" | jq 'length') -eq '0' ]]; then
      echo ''
    else
      echo "${compiled_json}" | augment_dashboard "${uid}" "${folder}"
    fi
  else
    augment_dashboard "${uid}" "${folder}" <"${file}"
  fi
}

# Generates a snapshot HTTP requests from stdin, one per line
prepare_snapshot_requests() {
  jq -c '
{
  dashboard: .,
  expires: 259200
} * {
  dashboard: {
    id: -1,
    editable: true,
    tags: ["playground"]
  }
}'
}

# Generates a dashboard HTTP requests from stdin, one per line
prepare_dashboard_requests() {
  local folderId=$1

  jq -c --arg folderId "$folderId" '
  {
    dashboard: .,
    folderId: $folderId | tonumber,
    overwrite: true
  }
'
}

function jsonnet_compile() {
  jsonnet -J . -J ../libsonnet -J ../metrics-catalog/ -J ../vendor -J ../services "$@" || {
    echo >&2 "Failed to compile:" "$@"
    return 1
  }
}

# Returns a list of dashboard files
find_dashboards() {
  local find_opts
  find_opts=(
    "."
    # All *.jsonnet and *.json dashboards...
    "("
    "-name" '*.jsonnet'
    "-o"
    "-name" '*.json'
    ")"
    -not -name '.*'             # Exclude dot files
    -not -name '*_test.jsonnet' # Exclude test files
    -not -path "**/.*"          # Exclude dot dirs
    -not -path "./vendor/*"     # Exclude vendored files
    -mindepth 2                 # Exclude files in the root folder
  )

  if [[ $# == 0 ]]; then
    find "${find_opts[@]}"
  else
    for var in "$@"; do
      echo "${var}"
    done
  fi
}
