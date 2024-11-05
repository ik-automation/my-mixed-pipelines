{
  // plan and apply default snippets
  // alternative to static configuration in gitlab-ci.yml

  // import global variables
  local component = std.extVar('COMPONENT'),
  local environment = std.extVar('ENV'),

  // NOTE: add an entry to support more stacks
  local plan_apply_dynamic_components = [
      "acm", "appconfig", "api-gateway",
      "backup", "basic-auth",
      "cognito-clients", "cognito-pools",
      "datadog", "dynamodb",
      "ecr", "elasticache", "elasticsearch", "eventbridge",
      "glue",
      "iam",
      "kms",
      "msk",
      "opensearch", "organization",
      "rds", "rds-aurora", "redshift", "route53-zones",
      "ses", "sftp", "sns", "sqs", "sso", "s3-bucket",
      "vault", "vpc"
    ],

  // NOTE: add an entry if require vault token
  local is_vault_jwt_required = std.count(["vault"], component) == 1,

  // functions avaialble for import in external files
  is_only_add_snippet:: std.count(plan_apply_dynamic_components, component) == 1,
  only_action_environment_name(action):: std.format('.%s-only-%s-%s', [component, action, environment]),
  only_defaults_environment_snippet(action)::
  {
    extends: std.format('.%s-only-%s-defaults', [component, action]),
    variables: {
      ENV: environment,
    } + if is_vault_jwt_required then {
      TF_VAR_vault_jwt: "$VAULT_ID_TOKEN",
    } else {} // Empty object if the condition is not met
  },
}
