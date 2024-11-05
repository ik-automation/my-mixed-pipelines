# -*- coding: utf-8 -*-

# python pipeline-json.py

## Script Functionality (Bullet Points)
"""
**Generates a YAML file:**
  * Defines header information for a GitLab CI pipeline.
  * Includes variables like `TF_HTTP_USERNAME` and stages like `lint`, `plan`, and `apply`.
  * Sets rules to trigger jobs based on branches and changes.
**Processes Directories:**
  * Identifies directories containing `.tfvars` files (likely Terraform configuration).
**Creates Jobs:**
  * Generates Terraform "validate" jobs for each directory.
  * Generates Terraform "plan" jobs for each directory.
  * Optionally generates Terraform "apply" jobs for each directory (enabled only for the default branch).
**Outputs the YAML:**
  * Writes the generated pipeline definition to a file named `child_pipeline.yml`.

**Additional Notes**

* The script relies on environment variables like `CI_COMMIT_BRANCH` and `CI_PROJECT_DIR` to determine the GitLab CI context.
* It filters directories based on the presence of the `config` subdirectory and `.tfvars` files.
"""

import os, json, yaml

PATH_TOP_LEVEL = 0
PATH_CONFIG = 1
PATH_TEAM = 2

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
      "stages": ["plan", "apply"],
      ".if-mr-or-default": {
        "rules": [
          {
            "if": "$CI_PIPELINE_SOURCE == \"parent_pipeline\" || $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH",
            "changes": [
              "pipeline-json.py",
              "common.hcl",
              ".gitlab-ci.yml"
            ]
          }
        ]
      }
    }
    return result

def generate_plan_job(name):
    path=name.split('/')
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
            "!reference [.if-mr-or-default, rules]",
              {
                "if": "$CI_PIPELINE_SOURCE == \"parent_pipeline\" || $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH",
                  "changes": [
                    f"{name}/*.{{hcl,tf,tfvars}}",
                    f"{path[PATH_TOP_LEVEL]}/terraform/*",
                    f"{path[PATH_TOP_LEVEL]}/config/*.{{hcl,tf,tfvars}}",
                    f"{path[PATH_TOP_LEVEL]}/{path[PATH_CONFIG]}/{path[PATH_TEAM]}/*.{{hcl,tf,tfvars}}" if len(path) > 2 else None
                  ]
              }
          ]
        }
    }
    return result

def generate_apply_job(name):
    path=name.split('/')
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
            "!reference [.if-mr-or-default, rules]",
              {
                "if": "$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH",
                  "changes": [
                    f"{name}/*.{{hcl,tf,tfvars}}",
                    f"{path[PATH_TOP_LEVEL]}/terraform/*",
                    f"{path[PATH_TOP_LEVEL]}/config/*.{{hcl,tf,tfvars}}",
                    f"{path[PATH_TOP_LEVEL]}/{path[PATH_CONFIG]}/{path[PATH_TEAM]}/*.{{hcl,tf,tfvars}}" if len(path) > 2 else None
                  ]
              }
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
      data.update(generate_plan_job(name))
      if applyEnabled:
        data.update(generate_apply_job(name))

    with open("child_pipeline.json", "w+") as f_out:
        json.dump(data, f_out, indent=4)

    with open("child_pipeline.yml", "w+") as f_out:
        # required as yaml not able to process custom gitlab tag !reference
        ymal_string=yaml.dump(data, sort_keys=False).replace("'!reference", "!reference").replace("]'", "]")
        f_out.write(ymal_string)

def list_filtered_folders(path):
    result = []
    for folder, dirs, files in os.walk(path):
        # Check if the current directory's path contains "config"
        if "config" in folder:
            # Check if any file in the directory has a .tfvars extension
            if any(file.endswith('terraform.tfvars') for file in files):
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
