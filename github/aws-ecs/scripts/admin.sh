#!/bin/bash

: "${WORKING_DIRECTORY}"
: "${ENVIRONMENT}"
: "${SERVICE_NAME}"
: "${SERVICE_VERSION}"
: "${AWS_DEFAULT_REGION}"
: "${ADMIN_HOST_BUCKET:-value_not_set}"

DEBUG_OPTIONS=""

if [ "${DEBUG_ENABLE,,}" == "true" ]; then DEBUG_OPTIONS="--verbose"; fi

help() {
	echo "-----------------------------------------------------------------------"
	echo "                      Available commands                              -"
	echo "-----------------------------------------------------------------------"
	echo "   > bootstrap - Bootstrap prerequisits"
	echo "   > build     - Build artifact froum source"
  echo "   > s3_sync   - Upload artifacts to s3"
}

print_env() {
	[[ "$@" ]] && echo "options: $@"
	env
}

s3_sync() {
	echo "++++++SYNC to S3 '${ADMIN_HOST_BUCKET}' ++++++"
	cd $WORKING_DIRECTORY
  aws s3 sync build/ s3://${ADMIN_HOST_BUCKET} --exclude index.html --cache-control 'max-age=60, public' --delete
  aws s3 cp build/index.html s3://${ADMIN_HOST_BUCKET} --cache-control "no-cache, no-store"
  aws s3 cp robots.txt s3://${ADMIN_HOST_BUCKET}
}

bootstrap() {
	echo "++++++BOOTSTRAP++++++"
	cd ${WORKING_DIRECTORY}
	yarn install --prefer-offline ${DEBUG_OPTIONS}
	npm run eslint:ci
}

build() {
	echo "++++++BUILD++++++"
	cd $WORKING_DIRECTORY
	yarn getversion
	cat .env.${ENVIRONMENT}
  npm run build:ci
}

case $1 in
	help) "$@"; exit;;
	print_env) "$@"; exit;;
	bootstrap) "$@"; exit;;
	build) "$@"; exit;;
  s3_sync) "$@"; exit;;
esac
