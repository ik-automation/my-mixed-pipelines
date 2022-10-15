local generateMarkdownLinks(toolingLinks) =
  [
    |||
      * [%(title)s](%(url)s)
    ||| % {
      title: tl.title,
      url: tl.url,
    }

    for tl in toolingLinks
  ];

local renderLinks(toolingLinks, options={}) =
  local optionsWithDefaults = {
    prometheusSelectorHash: {},
  } + options;
  std.flatMap(function(toolingLinkDefinition) toolingLinkDefinition(optionsWithDefaults), toolingLinks);

local generateMarkdown(toolingLinks, options={}) =
  std.join('', generateMarkdownLinks(renderLinks(toolingLinks, options)));

{
  cloudSQL: (import './cloud_sql.libsonnet').cloudSQL,
  continuousProfiler:: (import './continuous_profiler.libsonnet').continuousProfiler,
  elasticAPM:: (import './elastic_apm.libsonnet').elasticAPM,
  grafana:: (import './grafana.libsonnet').grafana,
  grafanaUid:: (import './grafana.libsonnet').grafanaUid,
  sentry:: (import './sentry.libsonnet').sentry,
  bigquery:: (import './bigquery.libsonnet').bigquery,
  kibana:: (import './kibana.libsonnet').kibana,
  gkeDeployment:: (import './gke_deployment.libsonnet').gkeDeployment,
  googleLoadBalancer: (import './google_load_balancer.libsonnet').googleLoadBalancer,
  googleCloudRun: (import './google_cloud_run.libsonnet').googleCloudRun,
  stackdriverLogs: (import './stackdriver_logs.libsonnet').stackdriverLogs,
  generateMarkdown:: generateMarkdown,
  renderLinks:: renderLinks,
}
