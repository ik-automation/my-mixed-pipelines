import json

def generate_gitlab_pipeline():
    # Define the pipeline structure as a Python dictionary
    pipeline = {
        "include": [
            {
                "project": "HnBI/platform-as-a-service/common-resources/gitlab-ci-snippets",
                "ref": "master",
                "file": [
                    "ci-runner-config/.gitlab-ci.yml",
                    "terragrunt-workflow/.gitlab-ci.yml"
                ]
            }
        ],
        "variables": {
            "TF_HTTP_USERNAME": "gitlab-ci-token",
            "TF_HTTP_PASSWORD": "${CI_JOB_TOKEN}",
            "PROJECT_ID": "${CI_PROJECT_ID}",
            "DD_APP_KEY": "${DATADOG_APP_KEY}",
            "ENV_BASE_DIR": ""
        },
        "stages": ["lint", "plan", "apply"],
        "workflow": {
            "rules": [
                {"if": "$CI_PIPELINE_SOURCE == \"merge_request_event\""},
                {"if": "$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH"}
            ]
        },
        ".config-paths": {
            "INSTANCE": [
                "monitors/config/customer-retention/apigateway",
                "monitors/config/customer-retention/authentication-app",
                "monitors/config/customer-retention/auth0",
                "monitors/config/customer-retention/authentication-service",
                "monitors/config/customer-retention/customer-data-provider",
                "monitors/config/customer-retention/composer-widgets",
                "monitors/config/customer-retention/generic"
            ]
        },
        "tg:fmt": {
            "extends": [".terragrunt-fmt"],
            "rules": [
                "!reference [.rule-never-on-schedule, rules]",
                {
                    "if": "$CI_PIPELINE_SOURCE == \"merge_request_event\" || $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH",
                    "changes": [
                        "monitors/**/*.{hcl,tf,tfvars}",
                        "synthetics/**/*.{hcl,tf,tfvars}",
                        ".gitlab-ci.yml"
                    ]
                }
            ]
        },
        "tg:lol": {
            "stage": "lint",
            "extends": [".terragrunt-validate"],
            "variables": {
                "ASSUME_ROLE": "FALSE"
            },
            "script": [
                "echo \"test\"",
                "env"
            ],
            "rules": [
                "!reference [.rule-never-on-schedule, rules]",
                {
                    "if": "$CI_PIPELINE_SOURCE == \"merge_request_event\" || $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH",
                    "changes": [
                        "${INSTANCE}/**/*",
                        "${TF_SRC}/**/*",
                        "${CI_PROJECT_DIR}/${ENV_BASE_DIR}/monitors/terraform/*",
                        "${CI_PROJECT_DIR}/${ENV_BASE_DIR}/synthetics/terraform/*",
                        "monitors/**/*.{hcl,tf,tfvars}",
                        "synthetics/**/*.{hcl,tf,tfvars}",
                        ".gitlab-ci.yml"
                    ]
                }
            ]
        },
        "tg:apply": {
            "stage": "apply",
            "extends": [".terragrunt-apply"],
            "variables": {
                "ASSUME_ROLE": "FALSE"
            },
            "rules": [
                "!reference [.rule-never-on-schedule, rules]",
                {
                    "if": "$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH",
                    "changes": [
                        "${INSTANCE}/**/*",
                        "${TF_SRC}/**/*",
                        "${CI_PROJECT_DIR}/${ENV_BASE_DIR}/monitors/terraform/*",
                        "${CI_PROJECT_DIR}/${ENV_BASE_DIR}/synthetics/terraform/*",
                        ".gitlab-ci.yml"
                    ]
                }
            ],
            "resource_group": "apply-$INSTANCE",
            "parallel": {
                "matrix": ["*config-paths"]
            }
        }
    }

    # Write the pipeline to a JSON file
    with open('gitlab_pipeline.json', 'w') as json_file:
        json.dump(pipeline, json_file, indent=4)

# Call the function to generate the pipeline JSON
generate_gitlab_pipeline()
