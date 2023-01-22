#!/bin/bash

set -euo pipefail

: "${ENV}"

# Make sure HELM_BIN is set (normally by the helm command)
HELM_BIN="${HELM_BIN:-helm}"

echo "  ======================================"
echo -e "\t Environment: ${ENV}"
echo -e "\t Deploy UI-PROXY"
echo "  ======================================"

clean_up() {
  echo "cleanup ..."
}
trap clean_up EXIT

${HELM_BIN} upgrade --install --timeout 600s --wait \
    --history-max 2 \
    -f ./helm/ui-proxy/values.yaml \
    -f "./helm/ui-proxy/${ENV}.values.yaml" \
    -n app ui-proxy ./helm/ui-proxy

helm list -n app
