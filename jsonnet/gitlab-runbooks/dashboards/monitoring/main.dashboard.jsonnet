local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local graphPanel = grafana.graphPanel;
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';

serviceDashboard.overview('monitoring')
.addPanel(
  row.new(title='Grafana CloudSQL Details', collapse=true)
  .addPanels(
    layout.grid([
      basic.timeseries(
        title='CPU Utilization',
        description=|||
          CPU utilization.

          See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
          more details.
        |||,
        query='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_cpu_utilization{database_id=~".+:grafana-(pre|internal)-.+", environment="$environment"}',
        legendFormat='{{ database_id }}',
        format='percent'
      ),

      basic.timeseries(
        title='Memory Utilization',
        description=|||
          Memory utilization.

          See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
          more details.
        |||,
        query='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_memory_utilization{database_id=~".+:grafana-(pre|internal)-.+", environment="$environment"}',
        legendFormat='{{ database_id }}',
        format='percent'
      ),

      basic.timeseries(
        title='Disk Utilization',
        description=|||
          Data utilization in bytes.

          See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
          more details.
        |||,
        query='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_disk_bytes_used{database_id=~".+:grafana-(pre|internal)-.+", environment="$environment"}',
        legendFormat='{{ database_id }}',
        format='bytes'
      ),

      basic.timeseries(
        title='Transactions',
        description=|||
          Delta count of number of transactions. Sampled every 60 seconds.

          See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
          more details.
        |||,
        query=|||
          sum by (database_id) (
            avg_over_time(stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_transaction_count{database_id=~".+:grafana-(pre|internal)-.+", environment="$environment"}[$__interval])
          )
        |||,
        legendFormat='{{ database_id }}',
      ),
    ], cols=4, rowHeight=10, startRow=1000)
  ),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  },
)
.addPanel(
  row.new(title='Grafana Latencies', collapse=true)
  .addPanels(
    layout.grid([
      basic.latencyTimeseries(
        title='Grafana API Dataproxy Request Duration (logn scale)',
        legend_show=false,
        format='ms',
        query=|||
          grafana_api_dataproxy_request_all_milliseconds{environment="$environment", quantile="0.5"}
        |||,
        legendFormat='p50 {{ pod }}',
        intervalFactor=2,
        logBase=10,
        min=10
      )
      .addTarget(
        promQuery.target(
          |||
            grafana_api_dataproxy_request_all_milliseconds{environment="$environment", quantile="0.9"}
          |||,
          legendFormat='p90 {{ pod }}',
          intervalFactor=2,
        )
      )
      .addTarget(
        promQuery.target(
          |||
            grafana_api_dataproxy_request_all_milliseconds{environment="$environment", quantile="0.99"}
          |||,
          legendFormat='p99 {{ pod }}',
          intervalFactor=2,
        )
      ) + {
        thresholds: [
          thresholds.warningLevel('gt', 10000),
          thresholds.errorLevel('gt', 30000),
        ],
      },

      basic.timeseries(
        title='Grafana Datasource RPS',
        legend_show=false,
        query=|||
          sum(rate(grafana_datasource_request_total{environment="$environment"}[$__interval])) by (datasource)
        |||,
        legendFormat='{{ datasource }}',
        intervalFactor=2,
      ),

      basic.latencyTimeseries(
        title='Grafana Datasource Request Duration (logn scale)',
        legend_show=false,
        format='s',
        query=|||
          avg(grafana_datasource_request_duration_seconds{environment="$environment"} >= 0) by (datasource)
        |||,
        legendFormat='{{ datasource }}',
        intervalFactor=2,
        logBase=10,
      ) + {
        thresholds: [
          thresholds.warningLevel('gt', 10),
          thresholds.errorLevel('gt', 30),
        ],
      },
    ], cols=3, rowHeight=10, startRow=1000),
  ),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  },
)
.overviewTrailer()
