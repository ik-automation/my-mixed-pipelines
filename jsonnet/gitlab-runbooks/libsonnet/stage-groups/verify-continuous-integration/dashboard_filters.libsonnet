local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;

local runnerTypeTemplate(hide='all') =
  template.new(
    'runner_type',
    '$PROMETHEUS_DS',
    query=|||
      label_values(gitlab_ci_queue_retrieval_duration_seconds_bucket{environment="$environment"}, runner_type)
    |||,
    refresh='load',
    hide=hide,
    sort=true,
    multi=true,
    includeAll=true,
  );

{
  runnerTypeTemplate:: runnerTypeTemplate,
}
