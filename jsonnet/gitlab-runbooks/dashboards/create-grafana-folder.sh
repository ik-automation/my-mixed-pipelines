#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Usage create-grafana-folder.sh uid "Title"
uid=$1
title=$2

curl -v --fail \
  -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://dashboards.gitlab.net/api/folders/" \
  -d @- <<EOF
{
    "uid": "${uid}",
    "title": "${title}"
}
EOF
