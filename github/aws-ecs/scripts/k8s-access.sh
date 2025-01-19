#!/bin/bash

set -eu

: "${ENVIRONMENT}"
: "${NAMESPACE}"
: "${REGION}"
: "${CLUSTER_NAME}"

AWS_IAM_AUTHENTICATOR_VERSION=v0.5.7

help() {
	echo "-----------------------------------------------------------------------"
	echo "                      Available commands                              -"
	echo "-----------------------------------------------------------------------"
	echo "   > test - Test Access"
	echo "   > helm - run helper"
}

test() {
  echo "++++Test Access++++"
  set +x
  kubectl version --client=true --short=true
  aws --region ${REGION} eks update-kubeconfig --name ${CLUSTER_NAME}
  kubectl config current-context --namespace=${NAMESPACE}
  kubectl config set-context --current --namespace=${NAMESPACE}

  curl -sL https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/${AWS_IAM_AUTHENTICATOR_VERSION}/aws-iam-authenticator_${AWS_IAM_AUTHENTICATOR_VERSION##*v}_linux_amd64 -o /usr/local/bin/aws-iam-authenticator && \
  chmod +x /usr/local/bin/aws-iam-authenticator

  kubectl get pods
  set -x
}

case $1 in
	help) "$@"; exit;;
  test) "$@"; exit;;
esac
