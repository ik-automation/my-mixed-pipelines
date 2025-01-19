#!/usr/bin/env bash

# Generate stack component pipeline alongside with resources to be deleted

set -e

: "${REGION}"
: "${ENV}"
: "${CI_COMMIT_REF_SLUG}"
: "${SCHEDULED_PIPELINE}"

ENV_BASE_DIR="graveyard"
COMPONENT_DIR=$PWD
COMPONENT_LOCATION=$ROOT_FOLDER/$TF_COMPONENT

GREP_REGEX="${TF_COMPONENT}/environments/${ENV}/.*/*.tfvars"

if [[ -z "${GITLAB_CI}" ]]; then
  if [[ "$(git branch --show-current)" == "master" ]]; then
    INSTANCES_DELETED=$(git diff --name-only --diff-filter D HEAD^ HEAD | grep "${GREP_REGEX}") || true
  else
    INSTANCES_DELETED=$(git diff --name-only --diff-filter D master..$(git branch --show-current) | grep "${GREP_REGEX}") || true
  fi
else
  if [[ "$CI_COMMIT_REF_SLUG" == "master" ]]; then
    INSTANCES_DELETED=$(git diff --name-only --diff-filter D HEAD^ HEAD | grep "${GREP_REGEX}") || true
  else
    git fetch
    INSTANCES_DELETED=$(git diff --name-only --diff-filter D $CI_MERGE_REQUEST_DIFF_BASE_SHA HEAD | grep "${GREP_REGEX}") || true
  fi
fi

echo "instances: $INSTANCES"
echo "deleted: $INSTANCES_DELETED"

## Generate a json file containing all details for the job generation.
# The goal is to create a json file containing an array of json objects containing the job details for each instance.
# First, a function is defined to create the json object with job details, component, env base dir, env, region and instance.
# Second, create an array based on the inputs (instances paths found in the above commands). Then capture each of them with the structure <component>/<env_base_dir>/<env>/<region>/<instance>.
# Finally the defined function gets called to create the object and it is placed in the array.
# At the end the result is written in a file called resources_to_delete.json in the componet dir
# works only in BASH
jq -Rn '
  def job_details($component; $env; $region; $instance): {
    "component": ($component),
    "environment": ($env),
    "region": ($region),
    "instance": ($instance)
  };

  [ inputs
    | capture("^(?<component>[^:]+)/environments/(?<env>[^:]+)/(?<region>.*)/(?<instance>.*)/.*.tfvars$"; "")
    | select(.)
    | job_details(.component; .env; .region; .instance)
  ]
' < <(printf '%s\n' "${INSTANCES_DELETED[@]}") > "$COMPONENT_DIR"/resources_to_delete.json

jsonnet -V ENV=$ENV \
  -V BRANCH=$CI_COMMIT_REF_SLUG \
  -V SCHEDULED_PIPELINE=$SCHEDULED_PIPELINE \
  -V INSTANCES=$INSTANCES \
  -V REGION=$REGION \
  -V COMPONENT=$TF_COMPONENT \
  -V ENABLED_JOBS=$ENABLED_JOBS \
  -S $ROOT_FOLDER/.gitlab/child-pipeline.jsonnet \
  --ext-str-file RESOURCES_TO_DELETE_LIST=resources_to_delete.json \
  -m $COMPONENT_LOCATION

## If the script run successfully remove the variables file
echo "========================="
echo "*** Parameters List (deleted resources) ***"
echo "========================="
if test -f "$COMPONENT_DIR/resources_to_delete.json"; then
  cat "$COMPONENT_DIR/resources_to_delete.json"
  rm -rf "$COMPONENT_DIR/resources_to_delete.json"
fi
