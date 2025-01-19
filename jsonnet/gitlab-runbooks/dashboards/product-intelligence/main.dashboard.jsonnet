local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';

basic.dashboard(
  'Product Intelligence',
  tags=['product_intelligence'],
  time_from='now-7d',
)
.addPanel(
  row.new(title='Snowplow'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  },
)
.addPanel(
  basic.timeseries(
    title='GitLab.com Backend sucessful events ratio 1h',
    legendFormat='$environment',
    format='percentunit',
    max=1.2,
    query=|||
      sum(rate(gitlab_snowplow_successful_events_total{env="$environment"}[1h])) / sum(rate(gitlab_snowplow_events_total{env="$environment"}[1h]))
    |||
  ),
  gridPos={
    x: 0,
    y: 0,
    w: 12,
    h: 15,
  }
)
.addPanel(
  basic.multiTimeseries(
    title='GitLab.com Backend Events total 1h',
    queries=[
      {
        legendFormat: 'All',
        query: 'sum(increase(gitlab_snowplow_events_total{env="$environment"}[1h]))',
      },
      {
        legendFormat: 'Successfull',
        query: 'sum(increase(gitlab_snowplow_successful_events_total{env="$environment"}[1h]))',
      },
      {
        legendFormat: 'Failed',
        query: 'sum(increase(gitlab_snowplow_failed_events_total{env="$environment"}[1h]))',
      },
    ]
  ),
  gridPos={
    x: 12,
    y: 0,
    w: 12,
    h: 15,
  }
)
.addPanel(
  row.new(title='Redis Hll'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  },
).addPanel(
  basic.timeseries(
    title='GitLab.com events fired 1h',
    legendFormat='Environment {{ environment }}',
    query=|||
      increase(redis_commands_total{cmd="pfadd",env="$environment"}[1h]) and on(fqdn) redis_instance_info { role="master" }
    |||
  ),
  gridPos={
    x: 0,
    y: 0,
    w: 12,
    h: 15,
  }
)
