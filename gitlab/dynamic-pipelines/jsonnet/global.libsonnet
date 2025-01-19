{
  add_include(component)::
    // Define a function-scoped variable.
    // Return an array.
    [
      {
        project: "HnBI/platform-as-a-service/common-resources/gitlab-ci-snippets",
        ref: "master",
        file: "ci-runner-config/.gitlab-ci.yml"
      },
      component + "/defaults-ci.yml",
      ".gitlab/templates/defaults-ci.yml",
      ".gitlab/templates/rules.gitlab-ci.yml",
      ".gitlab/templates/global-tg-workflow.gitlab-ci.yml",
      ".gitlab/templates/global-child-pipeline-workflow.gitlab-ci.yml",
    ],
}
