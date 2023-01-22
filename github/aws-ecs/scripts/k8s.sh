#!/bin/bash

set -eu

: "${WORKING_DIRECTORY}"
: "${ENVIRONMENT}"
: "${SERVICE_NAME}"
: "${SERVICE_VERSION}"
: "${NAMESPACE}"
: "${REGION}"
: "${CLUSTER_NAME}"
: "${TIMESTAMP}"

AWS_IAM_AUTHENTICATOR_VERSION=v0.5.7

echo "Bootstrap EKS cluster and deploy service '${SERVICE_NAME}'"

help() {
	echo "-----------------------------------------------------------------------"
	echo "                      Available commands                              -"
	echo "-----------------------------------------------------------------------"
	echo "   > bootstrap - Bootstrap dependencies"
	echo "   > command   - Run command"
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

helm_deploy() {
  echo "++++COMMAND++++"
  echo "Deploying helm chart ${SERVICE_NAME} in ${NAMESPACE}"
  helm list -n "${NAMESPACE}"
  helm history -n "${NAMESPACE}" "${SERVICE_NAME}" || true
  set -x
  helm upgrade "${SERVICE_NAME}" "./helm/${SERVICE_NAME}" \
  --install --wait --timeout 900s \
  -f "helm/${SERVICE_NAME}/values.yaml" \
  -f "helm/${SERVICE_NAME}/env-values/${ENVIRONMENT}.yaml" \
  -n "${NAMESPACE}" \
  --history-max 2 \
  --atomic \
  --set service_version="${SERVICE_VERSION}",timestamp=2022-03-03_10-05 \
  --debug
  set +x
  kubectl get pods
}

case $1 in
	help) "$@"; exit;;
  bootstrap) "$@"; exit;;
	helm_deploy) "$@"; exit;;
esac
