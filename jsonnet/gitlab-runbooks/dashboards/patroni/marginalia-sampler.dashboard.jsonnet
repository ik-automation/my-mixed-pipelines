local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local template = grafana.template;

basic.dashboard(
  'Marginalia Sampler',
  tags=['type:patroni'],
)
.addTemplate(template.new(
  'fqdn',
  '$PROMETHEUS_DS',
  'label_values(pg_stat_activity_marginalia_sampler_active_count{env="$environment", environment="$environment"}, fqdn)',
  refresh='time',
  sort=1,
  allValues='.*',
  includeAll=true,
  multi=true,
))
.addTemplate(template.new(
  'application',
  '$PROMETHEUS_DS',
  'label_values(pg_stat_activity_marginalia_sampler_active_count{env="$environment", environment="$environment"}, application)',
  refresh='time',
  sort=1,
  allValues='.*',
  includeAll=true,
  multi=true,
))
.addTemplate(template.new(
  'endpoint',
  '$PROMETHEUS_DS',
  'label_values(pg_stat_activity_marginalia_sampler_active_count{env="$environment", environment="$environment", application=~"$application"}, endpoint)',
  refresh='time',
  sort=1,
  allValues='.*',
  includeAll=true,
))
.addTemplate(template.new(
  'state',
  '$PROMETHEUS_DS',
  'label_values(pg_stat_activity_marginalia_sampler_active_count{env="$environment", environment="$environment"}, state)',
  refresh='time',
  sort=1,
  allValues='.*',
  includeAll=true,
))
.addTemplate(template.new(
  'wait_event_type',
  '$PROMETHEUS_DS',
  'label_values(pg_stat_activity_marginalia_sampler_active_count{env="$environment", environment="$environment"}, wait_event_type)',
  refresh='time',
  sort=1,
  allValues='.*',
  includeAll=true,
))
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Unaggregated Series',
      query=|||
        topk(10,
          avg_over_time(pg_stat_activity_marginalia_sampler_active_count{env="$environment", environment="$environment", application=~"$application", fqdn=~"$fqdn", endpoint=~"$endpoint", state=~"$state", wait_event_type=~"$wait_event_type"}[$__interval])
        )
      |||,
      interval='1m',
      linewidth=1,
      legend_show=true,
    ),
    basic.timeseries(
      title='Aggregated By Endpoint',
      query=|||
        topk(10,
          sum by (endpoint) (
            avg_over_time(pg_stat_activity_marginalia_sampler_active_count{env="$environment", environment="$environment", application=~"$application", fqdn=~"$fqdn", endpoint=~"$endpoint", state=~"$state", wait_event_type=~"$wait_event_type"}[$__interval])
          )
        )
      |||,
      interval='1m',
      linewidth=1,
      legend_show=true,
    ),
    basic.timeseries(
      title='Aggregated By State and Wait Event Type',
      query=|||
        topk(10,
          sum by (state, wait_event_type) (
            avg_over_time(pg_stat_activity_marginalia_sampler_active_count{env="$environment", environment="$environment", application=~"$application", fqdn=~"$fqdn", endpoint=~"$endpoint", state=~"$state", wait_event_type=~"$wait_event_type"}[$__interval])
          )
        )
      |||,
      interval='1m',
      linewidth=1,
      legend_show=true,
    ),
  ], cols=1)
)
.trailer()
+ {
  links+: platformLinks.triage + platformLinks.services +
          [platformLinks.dynamicLinks('Patroni Detail', 'type:patroni')],
}
