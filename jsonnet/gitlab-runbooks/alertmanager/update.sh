#!/usr/bin/env bash

set -eux

declare -r project='gitlab-ops'

gcloud auth activate-service-account --key-file "${SERVICE_KEY}"
gcloud config set project "${project}"
gcloud container clusters get-credentials "${CLUSTER}" --region "${REGION}"
kubectl apply --filename ./k8s_alertmanager_secret.yaml
