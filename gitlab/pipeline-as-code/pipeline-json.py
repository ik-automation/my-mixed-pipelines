# child_generator.py
import sys
import os, glob
import json

# python3 pipeline-json.py
def generate_header():
    result = {
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
      },
      "stages": ["lint", "plan", "apply"],
      ".if-mr-or-default": {
        "rules": [
          {
            "if": "$CI_PIPELINE_SOURCE == \"parent_pipeline\" || $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH",
            "changes": [
              "${INSTANCE}/**/*",
              "${TF_SRC}/**/*",
              "${CI_PROJECT_DIR}/${ENV_BASE_DIR}/monitors/terraform/*",
              "${CI_PROJECT_DIR}/${ENV_BASE_DIR}/synthetics/terraform/*",
              "monitors/**/*.{hcl,tf,tfvars}",
              "synthetics/**/*.{hcl,tf,tfvars}",
              "common.hcl",
              ".gitlab-ci.yml"
            ]
          }
        ]
      }
    }
    return result

def generate_validate_job(name):
    result = {
      f"tg:validate:[{name}]": {
            "stage": "lint",
            "extends": [".terragrunt-validate"],
            "variables": {
                "ASSUME_ROLE": "FALSE",
                "INSTANCE": f"{name}"
            },
            "rules": [
                "!reference [.rule-never-on-schedule, rules]",
                "!reference [.if-mr-or-default, rules]"
            ]
        }
    }
    return result

def generate_plan_job(name):
    result = {
      f"tg:plan:[{name}]": {
          "stage": "plan",
          "extends": [".terragrunt-plan"],
          "resource_group": f"plan-{name}",
          "variables": {
              "ASSUME_ROLE": "FALSE",
              "INSTANCE": f"{name}"
          },
          "rules": [
              "!reference [.rule-never-on-schedule, rules]",
              "!reference [.if-mr-or-default, rules]"
          ]
        }
    }
    return result

def generate_apply_job(name):
    result = {
      f"tg:apply:[{name}]": {
          "stage": "apply",
          "extends": [".terragrunt-apply"],
          "resource_group": f"apply-{name}",
          "variables": {
              "ASSUME_ROLE": "FALSE",
              "INSTANCE": f"{name}"
          },
          "needs": [
            f"tg:plan:[{name}]"
          ],
          "rules": [
              "!reference [.rule-never-on-schedule, rules]",
              "!reference [.if-mr-or-default, rules]"
          ]
        }
    }
    return result

def main(names, applyEnabled):
    if applyEnabled:
      rule = "$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH"
    else:
      rule = '$CI_PIPELINE_SOURCE == "parent_pipeline"'

    data = generate_header()

    for name in names:
      data.update(generate_validate_job(name))

    for name in names:
      data.update(generate_plan_job(name))

    if applyEnabled:
      for name in names:
        data.update(generate_apply_job(name))

    with open("child_pipeline.json", "w+") as f_out:
        json.dump(data, f_out, indent=4)

def list_filtered_folders(path):
    result = []
    for folder, dirs, files in os.walk(path):
        # Check if the current directory's path contains "config"
        if "config" in folder:
            # Check if any file in the directory has a .tfvars extension
            if any(file.endswith('.tfvars') for file in files):
                result.append(folder.split(f'{path}/')[1])
    return result

if __name__ == "__main__":

    isApplyEnabled = False
    if os.getenv("CI_PIPELINE_SOURCE") == 'merge_request_event':
      print('merge request detected. plan only')
    elif os.getenv("CI_COMMIT_BRANCH") == os.getenv("CI_DEFAULT_BRANCH"):
      print('enable apply')
      isApplyEnabled = True

    if os.getenv("GITLAB_CI"):
      fileDir = os.getenv("CI_PROJECT_DIR")
    else:
      fileDir = os.path.dirname(os.path.realpath('__file__'))

    dirs = list_filtered_folders(fileDir)
    print(f"found '{len(dirs)}' directories to process")
    main(dirs, isApplyEnabled)
