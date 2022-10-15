local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local graphPanel = grafana.graphPanel;
local row = grafana.row;
local seriesOverrides = import 'grafana/series_overrides.libsonnet';
local thresholds = import './thresholds.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local nodeLoadForDuration(duration, nodeSelector) =
  assert (duration == 1 || duration == 5 || duration == 15) : 'Load duration needs to be 1, 5 or 15';
  local formatConfigWithDuration = {
    duration: duration,
    nodeSelector: selectors.serializeHash(nodeSelector),
  };
  basic.timeseries(
    title='loadavg%(duration)d per core' % formatConfigWithDuration,
    description='Loadavg (%(duration)d minute) per core, below 1 is better.' % formatConfigWithDuration,
    query=
    |||
      avg by (environment, type, stage, fqdn) (node_load%(duration)d{%(nodeSelector)s})
      /
      count by (environment, type, stage, fqdn) (node_cpu_seconds_total{mode="idle", %(nodeSelector)s})
    ||| % formatConfigWithDuration,
    legendFormat='{{ fqdn }}',
    interval='1m',
    intervalFactor=1,
    yAxisLabel='loadavg%(duration)d' % formatConfigWithDuration,
    legend_show=false,
    linewidth=1,
    decimals=2,
    thresholds=[
      thresholds.errorLevel('gt', 1),
      thresholds.warningLevel('gt', 0.8),
    ]
  );

{
  nodeMetricsDetailRow(nodeSelector, title='🖥️ Node Metrics')::
    local formatConfig = {
      nodeSelector: selectors.serializeHash(nodeSelector),
    };
    row.new(title, collapse=true)
    .addPanels(layout.grid([
      graphPanel.new(
        'Node CPU',
        linewidth=1,
        fill=0,
        description='The amount of non-idle time consumed by nodes for this service',
        datasource='$PROMETHEUS_DS',
        decimals=2,
        sort='decreasing',
        legend_show=false,
        legend_values=false,
        legend_alignAsTable=false,
        legend_hideEmpty=true,
      )
      .addTarget(  // Primary metric
        promQuery.target(
          |||
            avg(instance:node_cpu_utilization:ratio{%(nodeSelector)s}) by (fqdn)
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          intervalFactor=5,
        )
      )
      .resetYaxes()
      .addYaxis(
        format='percentunit',
        label='Average CPU Utilization',
      )
      .addYaxis(
        format='short',
        max=1,
        min=0,
        show=false,
      ),
      basic.saturationTimeseries(
        'Node Maximum Single Core Utilization',
        description='The maximum utilization of a single core on each node. Lower is better',
        query=
        |||
          max(1 - rate(node_cpu_seconds_total{%(nodeSelector)s, mode="idle"}[$__interval])) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        legend_show=false,
        linewidth=1
      ),

      graphPanel.new(
        'Node Network Utilization',
        linewidth=1,
        fill=0,
        description='Network utilization for nodes for this service',
        datasource='$PROMETHEUS_DS',
        decimals=2,
        sort='decreasing',
        legend_show=false,
        legend_values=false,
        legend_alignAsTable=false,
        legend_hideEmpty=true,
      )
      .addSeriesOverride(seriesOverrides.networkReceive)
      .addTarget(
        promQuery.target(
          |||
            sum(rate(node_network_transmit_bytes_total{%(nodeSelector)s}[$__interval])) by (fqdn)
          ||| % formatConfig,
          legendFormat='send {{ fqdn }}',
          intervalFactor=5,
        )
      )
      .addTarget(
        promQuery.target(
          |||
            sum(rate(node_network_receive_bytes_total{%(nodeSelector)s}[$__interval])) by (fqdn)
          ||| % formatConfig,
          legendFormat='receive {{ fqdn }}',
          intervalFactor=5,
        )
      )
      .resetYaxes()
      .addYaxis(
        format='Bps',
        label='Network utilization',
      )
      .addYaxis(
        format='short',
        max=1,
        min=0,
        show=false,
      ),
      basic.saturationTimeseries(
        title='Memory Utilization',
        description='Memory utilization. Lower is better.',
        query=
        |||
          instance:node_memory_utilization:ratio{%(nodeSelector)s}
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        interval='1m',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),

      // Node-level disk metrics
      // Reads on the left, writes on the right
      //
      // IOPS ---------------
      basic.timeseries(
        title='Disk Read IOPs',
        description='Disk Read IO operations per second. Lower is better.',
        query=
        |||
          max(
            rate(node_disk_reads_completed_total{%(nodeSelector)s}[$__interval])
          ) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='ops',
        interval='1m',
        intervalFactor=1,
        yAxisLabel='Operations/s',
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title='Disk Write IOPs',
        description='Disk Write IO operations per second. Lower is better.',
        query=
        |||
          max(
            rate(node_disk_writes_completed_total{%(nodeSelector)s}[$__interval])
          ) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='ops',
        interval='1m',
        intervalFactor=1,
        yAxisLabel='Operations/s',
        legend_show=false,
        linewidth=1
      ),
      // Disk Throughput ---------------
      basic.timeseries(
        title='Disk Read Throughput',
        description='Disk Read throughput datarate. Lower is better.',
        query=
        |||
          max(
            rate(node_disk_read_bytes_total{%(nodeSelector)s}[$__interval])
          ) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='Bps',
        interval='1m',
        intervalFactor=1,
        yAxisLabel='Bytes/s',
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title='Disk Write Throughput',
        description='Disk Write throughput datarate. Lower is better.',
        query=
        |||
          max(
            rate(node_disk_written_bytes_total{%(nodeSelector)s}[$__interval])
          ) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='Bps',
        interval='1m',
        intervalFactor=1,
        yAxisLabel='Bytes/s',
        legend_show=false,
        linewidth=1
      ),
      // Disk Total Time ---------------
      basic.timeseries(
        title='Disk Read Total Time',
        description='Total time spent in read operations across all disks on the node. Lower is better.',
        query=
        |||
          sum(
            rate(node_disk_read_time_seconds_total{%(nodeSelector)s}[$__interval])
          ) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='s',
        interval='30s',
        intervalFactor=1,
        yAxisLabel='Total Time/s',
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title='Disk Write Total Time',
        description='Total time spent in write operations across all disks on the node. Lower is better.',
        query=
        |||
          sum(
            rate(node_disk_write_time_seconds_total{%(nodeSelector)s}[$__interval])
          ) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='s',
        interval='30s',
        intervalFactor=1,
        yAxisLabel='Total Time/s',
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title='CPU Scheduling Waiting',
        description='CPU scheduling waiting on the run queue, as a percentage of time. Aggregated to worst CPU per node. Lower is better.',
        query=
        |||
          max by (fqdn) (
            rate(node_schedstat_waiting_seconds_total{%(nodeSelector)s}[5m])
          )
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='percentunit',
        interval='1m',
        intervalFactor=1,
        yAxisLabel='Total Time/s',
        legend_show=false,
        linewidth=1,
        thresholds=[
          thresholds.errorLevel('gt', 1),
          thresholds.warningLevel('gt', 0.75),
        ]
      ),
    ] + [
      // Node-level load averages
      (
        nodeLoadForDuration(duration, nodeSelector)
      )
      for duration in [1, 5, 15]
    ])),
  nodeLoadForDuration:: nodeLoadForDuration,
}
