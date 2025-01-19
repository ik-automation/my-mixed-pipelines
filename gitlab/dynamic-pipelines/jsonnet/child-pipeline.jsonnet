local default = import 'default.libsonnet';
local utils = import 'global.libsonnet';

local instances_str = std.stripChars(std.extVar('INSTANCES'), ',');
local instances = if instances_str == "" then [] else std.split(instances_str, ",");
local environment = std.extVar('ENV');
local region = std.extVar('REGION');
local component = std.extVar('COMPONENT');
local enabled_jobs_str = std.stripChars(std.extVar('ENABLED_JOBS'), ',');
local enabled_jobs = std.split(enabled_jobs_str, ",");
local plan_job_name = 'tf:plan:' + component + ':' + environment + ':' + region + ':';
local apply_job_name = 'tf:apply:' + component + ':' + environment + ':' + region + ':';
local is_plan_job_enabled = std.member(enabled_jobs, "plan");
local is_apply_job_enabled = std.member(enabled_jobs, "apply");
// Deletion workflow
local plan_graveyard_job_name = 'tf:plan:graveyard:' + component + ':' + environment + ':' + region + ':';
local plan_graveyard_snippet_name = '.%s-only-plan-graveyard-%s' % [component, environment];
local apply_graveyard_job_name = 'tf:apply:graveyard:' + component + ':' + environment + ':' + region + ':';
local apply_graveyard_snippet_name = '.%s-only-apply-graveyard-%s' % [component, environment];
// deleted instances
local resources_to_delete_list = if std.extVar('RESOURCES_TO_DELETE_LIST') == "" then [] else std.parseJson(std.extVar('RESOURCES_TO_DELETE_LIST'));

// Validate where or not component is supported
// 2. Add component for graveyard to support it
local components = ["basic-auth", "dynamodb", "elasticache", "elasticsearch", "opensearch", "rds", "rds-aurora", "sftp"];
local is_graveyard_component_plan_delete = std.count(components, component) == 1 && std.length(resources_to_delete_list) > 0;
// 3. Add component for pipeline to create a delition stage
local components_delete = ["basic-auth", "dynamodb", "elasticache", "elasticsearch", "opensearch", "rds", "rds-aurora", "sftp"];
local is_graveyard_component_apply_delete = std.count(components_delete, component) == 1 && std.length(resources_to_delete_list) > 0;
// Artifacts workflow
local branch = std.extVar('BRANCH');
local scheduled_pipeline = std.extVar('SCHEDULED_PIPELINE');

local instance_name(instance) = if std.length(instance) > 1 then instance else "this";

local plan_job(instance, branch) =
  {
    extends: [
      "." + component + "-only-plan-" + environment,
    ] + (if branch == "master" && scheduled_pipeline == "false" then [".terragrunt-plan-artifacts"] else []),
    resource_group: std.format("%s-%s-%s-plan", [component, instance_name(instance), environment]),
    variables: {
      INSTANCE: instance
    }
  };

local apply_job(instance) =
  {
    extends: "." + component + "-only-apply-" + environment,
    variables: {
      INSTANCE: instance
    },
    resource_group: std.format("%s-%s-%s-apply", [component, instance_name(instance), environment]),
    needs: std.prune([
      (if std.member(enabled_jobs, "plan") then { "job": plan_job_name + instance_name(instance) }),
    ])
  };

local plan_job_graveyard(source) =
  {
    extends: "." + component + "-only-plan-graveyard-" + environment,
    resource_group: std.format("%s-%s-%s-plan", [component, source['instance'], environment]),
    variables: {
      TF_COMPONENT: component,
      ENV_BASE_DIR: "graveyard",
      ENV: environment,
      REGION: region,
      INSTANCE: source['instance']
    },
  };

local apply_job_graveyard(source) =
  {
    extends: "." + component + "-only-apply-graveyard-" + environment,
    variables: {
      TF_COMPONENT: component,
      ENV_BASE_DIR: "graveyard",
      ENV: environment,
      REGION: region,
      INSTANCE: source['instance']
    },
    resource_group: std.format("%s-%s-%s-apply", [component, source['instance'], environment]),
    needs: std.prune([
      (if std.member(enabled_jobs, "plan") then { "job": plan_graveyard_job_name + source['instance'] }),
    ])
  };

// Deletion workflow
local add_graveyard_plan_snippets() =
  {
    extends: [
      std.format('.%s-only-plan-defaults', component),
      ".terragrunt-plan-graveyard"
    ],
    variables: {
      ENV: environment,
      WORKING_DIR: 'graveyard',
    } + if component == "rds" then {
      ASSUME_AWS_ROLE_NAME: "gitlab-ci-paas-rds-admin",
      ASSUME_AWS_ROLE_DURATION: 7200
    } else {} // Empty object if the condition is not met
  };

local add_graveyard_apply_snippets() =
  {
    extends: [
      std.format('.%s-only-apply-defaults', component),
      ".terragrunt-apply-graveyard"
    ],
    variables: {
      ENV: environment,
      WORKING_DIR: 'graveyard',
    } + if component == "rds" then {
      ASSUME_AWS_ROLE_NAME: "gitlab-ci-paas-rds-admin",
      ASSUME_AWS_ROLE_DURATION: 7200
    } else {} // Empty object if the condition is not met
  };

{
  'generated-child-pipeline.yml': std.manifestJson({
    include: utils.add_include(component)
  } + {
    [if default.is_only_add_snippet then default.only_action_environment_name("plan")]: default.only_defaults_environment_snippet("plan")
  } + {
    [if default.is_only_add_snippet then default.only_action_environment_name("apply")]: default.only_defaults_environment_snippet("apply")
  } + {
    [plan_job_name + (instance_name(instance))]: plan_job(instance, branch)
    for instance in instances if is_plan_job_enabled
  } + {
    [apply_job_name + (instance_name(instance))]: apply_job(instance)
    for instance in instances if is_apply_job_enabled
  } + {
    [plan_graveyard_job_name + inputs_to_delete['instance']]: plan_job_graveyard(inputs_to_delete)
    for inputs_to_delete in resources_to_delete_list if is_plan_job_enabled
  } + {
    [if is_graveyard_component_plan_delete then plan_graveyard_snippet_name]: add_graveyard_plan_snippets(),
  } + {
    [apply_graveyard_job_name + inputs_to_delete['instance']]: apply_job_graveyard(inputs_to_delete)
    for inputs_to_delete in resources_to_delete_list if is_apply_job_enabled && is_graveyard_component_apply_delete
  } + {
    [if is_graveyard_component_apply_delete then apply_graveyard_snippet_name]: add_graveyard_apply_snippets(),
  }),
}
