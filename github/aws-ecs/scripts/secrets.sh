#!/bin/bash

set -eu

: "${ENVIRONMENT}"
: "${NAMESPACE}"
: "${CLUSTER_NAME}"
: "${SERVICE_NAME}"

AWS_IAM_AUTHENTICATOR_VERSION=v0.5.7

echo "Setup EKS secrets '${SERVICE_NAME}'"

help() {
	echo "-----------------------------------------------------------------------"
	echo "                      Available commands                              -"
	echo "-----------------------------------------------------------------------"
	echo "   > bootstrap - Bootstrap dependencies"
	echo "   > plan      - Run command"
  echo "   > secrets   - Read secrets from SSM"
	echo "   > helm      - run helper"
}

bootstrap() {
  echo "++++BOOTSTRAP++++"
  set -x
  kubectl version --client=true --short=true
  aws --region ${REGION} eks update-kubeconfig --name ${CLUSTER_NAME}
  kubectl config current-context --namespace=${NAMESPACE}
  kubectl config set-context --current --namespace=${NAMESPACE}
  set +x

  curl -sL https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/${AWS_IAM_AUTHENTICATOR_VERSION}/aws-iam-authenticator_${AWS_IAM_AUTHENTICATOR_VERSION##*v}_linux_amd64 -o /usr/local/bin/aws-iam-authenticator && \
    chmod +x /usr/local/bin/aws-iam-authenticator

  kubectl get pods
}

read_secrets() {
  aws ssm get-parameter --name "/singleton/${ENVIRONMENT}/secrets" --with-decryption --query Parameter.Value --output text > "helm/${SERVICE_NAME}/enc/${ENVIRONMENT}.yaml"
}

helm_plan() {
  echo "++++PLAN++++"
  echo "PLAN helm chart ${SERVICE_NAME} in ${NAMESPACE}"
  helm list -n "${NAMESPACE}"
  helm history -n "${NAMESPACE}" "${SERVICE_NAME}" || true
  helm template "${SERVICE_NAME}" "./helm/${SERVICE_NAME}" \
    --output-dir result \
    --timeout 600s \
    -f "helm/${SERVICE_NAME}/values.yaml" \
    -f "helm/${SERVICE_NAME}/env-values/${ENVIRONMENT}.yaml" \
    -f "helm/${SERVICE_NAME}/enc/${ENVIRONMENT}.yaml" \
    -n "${NAMESPACE}" \
    --debug
  kubectl diff -f result --recursive=true
}

helm_apply() {
  echo "++++APPLY++++"
  echo "Deploying helm chart ${SERVICE_NAME} in ${NAMESPACE}"
  helm upgrade "${SERVICE_NAME}" "./helm/${SERVICE_NAME}" \
    --install --wait --timeout 600s \
    -f "helm/${SERVICE_NAME}/values.yaml" \
    -f "helm/${SERVICE_NAME}/env-values/${ENVIRONMENT}.yaml" \
    -f "helm/${SERVICE_NAME}/enc/${ENVIRONMENT}.yaml" \
    -n "${NAMESPACE}" \
    --history-max 2 \
    --debug
  helm history -n "${NAMESPACE}" "${SERVICE_NAME}" || true
}

case $1 in
	help) "$@"; exit;;
  bootstrap) "$@"; exit;;
	helm_plan) "$@"; exit;;
  helm_apply) "$@"; exit;;
  read_secrets) "$@"; exit;;
esac
