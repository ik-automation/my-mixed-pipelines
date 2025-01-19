#!/usr/bin/env bash

set -e

: "${TF_COMPONENT}"
: "${ENV_BASE_DIR}"
: "${ENV}"
: "${REGION}"
: "${ENABLED_JOBS}"
: "${CI_PROJECT_DIR}"
: "${CI_COMMIT_REF_SLUG}"
: "${CI_PIPELINE_SOURCE}"
: "${CI_PARENT_PIPELINE_SOURCE}"

########################
# Build Child Pipelines
########################
## Check required environment variables are present
if [[ -z "$TF_COMPONENT" ]]; then
    echo "Must provide TF_COMPONENT variable" 1>&2
    exit 1
fi

if [[ -z "$ENABLED_JOBS" ]]; then
    echo "Must provide ENABLED_JOBS variable" 1>&2
    exit 1
fi

# Determine if the pipeline is scheduled
if [ "$CI_PIPELINE_SOURCE" == "schedule" ] || [ "$CI_PARENT_PIPELINE_SOURCE" == "schedule" ]; then
    export SCHEDULED_PIPELINE="true"
else
    export SCHEDULED_PIPELINE="false"
fi

EXIT_CODE=22 # https://www.cyberciti.biz/faq/linux-bash-exit-status-set-exit-statusin-bash/
COMPONENT_LOCATION=$CI_PROJECT_DIR/$TF_COMPONENT
export ROOT_FOLDER=$PWD
cd $TF_COMPONENT/$ENV_BASE_DIR/$ENV/$REGION

if [ "$(uname)" == "Darwin" ]; then
  # required to run locally on MacOs
  export INSTANCES=$(find . -name "terragrunt.hcl" -maxdepth 2 -mindepth 1 -exec dirname {} \; | sed "s/\.\///g" | tr '\n' ',')
else
  export INSTANCES=$(find -type f -name terragrunt.hcl -maxdepth 2 -mindepth 1 -exec dirname {} \; | sed "s/\.\///g" | tr '\n' ',')
fi

jsonnet_graveyard_pipeline() {
  echo "execute $CI_PROJECT_DIR/.gitlab/scripts/generate-component-with-graveyard-pipeline.sh"
  $CI_PROJECT_DIR/.gitlab/scripts/generate-component-with-graveyard-pipeline.sh
}

jsonnet_basic_pipeline() {
  set -x
  jsonnet -V ENV=$ENV \
    -V BRANCH=$CI_COMMIT_REF_SLUG \
    -V SCHEDULED_PIPELINE=$SCHEDULED_PIPELINE \
    -V INSTANCES=$INSTANCES \
    -V REGION=$REGION \
    -V COMPONENT=$TF_COMPONENT \
    -V ENABLED_JOBS=$ENABLED_JOBS \
    -V RESOURCES_TO_DELETE_LIST="" \
    -S $CI_PROJECT_DIR/.gitlab/child-pipeline.jsonnet \
    -m $COMPONENT_LOCATION
  set +x
}

# In Bash, the =~ operator is used for pattern matching with regular expressions. When using it with a string on the right side, it treats that string as a regular expression pattern. However, the pattern "rds|dynamodb|elasticache|basic-auth" doesn't match the value of ${TF_COMPONENT} because it doesn't contain the whole string "basic-auth". For this to work, the regular expression pattern to match the exact value of ${TF_COMPONENT}. You can do this by enclosing the pattern within ^ (start of line) and $ (end of line) anchors to match the whole string:

# Should work with any component.
# 1. Add new component for graveyard to support it "rds|dynamodb|..."
export TF_COMPONENTS_REGEX="^(basic-auth|dynamodb|elasticache|elasticsearch|opensearch|rds|rds-aurora|sftp)$"

if [[ ${TF_COMPONENT} =~ $TF_COMPONENTS_REGEX ]]; then
    jsonnet_graveyard_pipeline
  else
    jsonnet_basic_pipeline
fi

if test -f "$COMPONENT_LOCATION/generated-child-pipeline.yml"; then
  echo "==================================="
  echo "*** Generated Pipeline Snippet ***"
  echo "==================================="
  cat $COMPONENT_LOCATION/generated-child-pipeline.yml
  # cleanup if run locally
  if [[ -z "${GITLAB_CI}" ]]; then
    rm -f $COMPONENT_LOCATION/generated-child-pipeline.yml
  fi
else
  # child pipeline not created
  echo "Child pipeline not created. Skip..."
  exit $EXIT_CODE
fi
