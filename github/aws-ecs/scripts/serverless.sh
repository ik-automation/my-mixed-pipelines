#!/bin/bash

: "${WORKING_DIRECTORY}"
: "${ENVIRONMENT}"
: "${AWS_DEFAULT_REGION}"
: "${PROJECT}"

DEBUG_OPTIONS=""

cd $WORKING_DIRECTORY

if [ "${DEBUG_ENABLE,,}" == "true" ]; then DEBUG_OPTIONS="--verbose"; fi

help() {
	echo "-----------------------------------------------------------------------"
	echo "                      Available commands                              -"
	echo "-----------------------------------------------------------------------"
	echo "   > bootstrap            - Bootstrap prerequisits"
	echo "   > build                - Build artifact froum source"
  echo "   > update_function_code - Update function code"
}

update() {
  local name="${1}"
  aws lambda update-function-code --function-name "${PROJECT}-${ENVIRONMENT}-${name}" \
    --publish --zip-file "fileb://${name}.zip"
}

update_function_code() {
	echo "++++++UPDATE SERVERLESS FUNCTIONS ++++++"
  cd artifacts
	ls -la
  declare -a functions=(
    "trigger-adaptive-transcoder"
    "trigger-transcoder"
    "video-uploaded"
    "transcode-error-notify"
    "transcode-success-notify"
    "mailer"
  )
  arraylength=${#functions[@]}
  for (( i=1; i<${arraylength}+1; i++ ));
  do
    update "${functions[$i-1]}"
  done
}

bootstrap() {
	echo "++++++BOOTSTRAP++++++"
	yarn install --prefer-offline ${DEBUG_OPTIONS}
	npm run test
}

build() {
	echo "++++++BUILD++++++"
	npm run package
}

case $1 in
	help) "$@"; exit;;
	bootstrap) "$@"; exit;;
	build) "$@"; exit;;
  update_function_code) "$@"; exit;;
esac
