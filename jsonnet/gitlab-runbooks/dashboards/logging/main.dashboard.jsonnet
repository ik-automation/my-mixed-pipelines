local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local graphPanel = grafana.graphPanel;
local promQuery = import 'grafana/prom_query.libsonnet';
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';

serviceDashboard.overview('logging')
.overviewTrailer()
.addPanel(
  row.new(title='PubSub Subscriptions Details', collapse=true)
  .addPanels(
    layout.grid([
      graphPanel.new(
        'PubSub subscriptions Undelivered Messages',
        bars=true,
        lines=false,
        stack=true,
        format='short',
        decimals=0,
        sort='decreasing',
        legend_show=false,
        legend_rightSide=true,
        legend_alignAsTable=true,
        legend_values=true,
        legend_min=true,
        legend_max=true,
        legend_current=true,
        legend_total=false,
        legend_avg=true,
        datasource='$PROMETHEUS_DS',
      )
      .addTarget(
        promQuery.target(
          |||
            max(max_over_time(stackdriver_pubsub_subscription_pubsub_googleapis_com_subscription_num_undelivered_messages{environment="$environment"}[$__interval])) by (subscription_id)
          |||,
          legendFormat='{{ subscription_id }}',
          interval='1m',
          intervalFactor=3,
        )
      ),
      basic.timeseries(
        title='PubSub subscriptions Oldest Unacked Messages',
        legend_show=false,
        query=|||
          max(max_over_time(stackdriver_pubsub_subscription_pubsub_googleapis_com_subscription_oldest_unacked_message_age{environment="$environment"}[$__interval])) by (subscription_id)
        |||,
        format='s',
        legendFormat='{{ subscription_id }}',
      ),
      basic.timeseries(
        title='PubSub subscriptions Oldest Retained Acked Messages',
        legend_show=false,
        query=|||
          max(max_over_time(stackdriver_pubsub_subscription_pubsub_googleapis_com_subscription_oldest_retained_acked_message_age{environment="$environment"}[$__interval])) by (subscription_id)
        |||,
        format='s',
        legendFormat='{{ subscription_id }}',
      ),
    ], cols=3, rowHeight=10, startRow=1000),
  ),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  },
)
.addPanel(
  row.new(title='👀 fluentd process activity', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'fluentd processes',
      {
        env: '$environment',
        groupname: 'fluentd',
      }
    )
  ),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  },
)
