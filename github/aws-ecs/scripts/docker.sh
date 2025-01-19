#!/bin/bash

set -eu

: "${WORKING_DIRECTORY}"
: "${ENVIRONMENT}"
: "${SERVICE_NAME}"
: "${SERVICE_VERSION}"
: "${IMAGE}"
: "${IMAGE_TAG}"
: "${BRANCH}"
: "${DOCKERFILE}"
: "${CREATED}"
: "${BUILD_URL}"
: "${TIMESTAMP}"

echo "Build a docker container and push it to ECR so that it can be deployed"

help() {
	echo "-----------------------------------------------------------------------"
	echo "                      Available commands                              -"
	echo "-----------------------------------------------------------------------"
	echo "   > bootstrap - Bootstrap prerequisits"
	echo "   > build - Build artifact froum source"
	echo "   > helm - run helper"
}

print_env() {
	[[ "$@" ]] && echo "options: $@"
	env
}

push() {
  docker images
	echo "++++PUSH++++"
  set -x
  echo "push version ${IMAGE}:latest"
  docker push "${IMAGE}:latest"
  TAGS=(
    "${IMAGE_TAG}"
    "${BRANCH}-latest"
  )
  for el in "${TAGS[@]}" ; do
    KEY="${el}"
    echo "push version ${IMAGE}:${KEY}"
    docker tag "${IMAGE}" "${IMAGE}:${KEY}"
    docker push "${IMAGE}:${KEY}"
  done
}

build() {
  echo "++++BUILD++++"
  cd ${WORKING_DIRECTORY}
  docker build -t "${IMAGE}" . \
  --label "org.opencontainers.image.created=${CREATED}" \
  --label "org.opencontainers.image.build-url=${BUILD_URL}" \
  --build-arg SERVICE_VERSION=${SERVICE_VERSION} \
  --build-arg TIMESTAMP=${TIMESTAMP} \
  --build-arg ENVIRONMENT=${ENVIRONMENT} \
  -f ${DOCKERFILE} --progress=plain
}

case $1 in
	help) "$@"; exit;;
  build) "$@"; exit;;
	push) "$@"; exit;;
esac
