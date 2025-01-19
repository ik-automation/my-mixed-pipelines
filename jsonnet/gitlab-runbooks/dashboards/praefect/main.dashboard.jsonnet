local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local row = grafana.row;

local selector = {
  env: '$environment',
  stage: '$stage',
};

local formatConfig = {
  selector: selectors.serializeHash(selector),
};

serviceDashboard.overview('praefect')
.addPanel(
  row.new(title='Praefect Replication', collapse=false),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Praefect Replications by Reason',
      description=|||
        The reasons why Praefect has kicked off a replication job.
      |||,
      query=|||
        sum by (reason) (
          rate(gitaly_praefect_tx_replications_total{%(selector)s}[$__rate_interval])
        )
      ||| % formatConfig,
      legendFormat='{{ reason }}',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='Replication Rate',
      legend_show=true,
      linewidth=2
    ),
    basic.multiTimeseries(
      queries=[{
        legendFormat: 'p' + percentile,
        query: |||
          histogram_quantile(%(percentile)g, sum by (le) (
            rate(gitaly_praefect_replication_delay_bucket{%(selector)s}[$__rate_interval]))
          )
        ||| % formatConfig {
          percentile: percentile / 100,
        },
      } for percentile in [50, 90, 95, 99]],
      title='Replication Queuing Latency',
      description=|||
        Replication queueing latency is the time between scheduling a replication and the start of the execution
        of the replication.
      |||,
      format='s',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='Replication Delay',
      linewidth=2
    ),
    basic.multiTimeseries(
      queries=[{
        legendFormat: 'p' + percentile,
        query: |||
          histogram_quantile(%(percentile)g, sum by (le) (
            rate(gitaly_praefect_replication_latency_bucket{%(selector)s}[$__rate_interval]))
          )
        ||| % formatConfig {
          percentile: percentile / 100,
        },
      } for percentile in [50, 90, 95, 99]],
      title='Replication Latency',
      description=|||
        Replication latency is the duration of replication jobs from the start of execution, following after queueing,
        until the replication job completes.
      |||,
      format='s',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='Replication Latency',
      linewidth=2
    ),
    basic.timeseries(
      title='Inflight Praefect Replications by Change Type',
      description=|||
        Inflight replications, by change type.
      |||,
      query=|||
        sum by (change_type) (
          gitaly_praefect_replication_jobs{%(selector)s}
        )
      ||| % formatConfig,
      legendFormat='{{ change_type }}',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='Inflight Replication Count',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='Inflight Praefect Replications by Node',
      description=|||
        Inflight replications, by node.
      |||,
      query=|||
        sum by (fqdn) (
          gitaly_praefect_replication_jobs{%(selector)s}
        )
      ||| % formatConfig,
      legendFormat='{{ fqdn }}',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='Inflight Replication Count',
      legend_show=true,
      linewidth=2
    ),
  ], cols=1, rowHeight=10, startRow=1001)
)
.overviewTrailer()
