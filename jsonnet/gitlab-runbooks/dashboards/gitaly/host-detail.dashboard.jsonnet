local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local nodeMetrics = import 'gitlab-dashboards/node_metrics.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local saturationDetail = import 'gitlab-dashboards/saturation_detail.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local quantilePanel = import 'grafana/quantile_panel.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local metricsCatalogDashboards = import 'gitlab-dashboards/metrics_catalog_dashboards.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';
local gitalyCommandStats = import 'gitlab-dashboards/gitaly_command_stats.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local singleMetricRow = import 'key-metric-panels/single-metric-row.libsonnet';

local serviceType = 'gitaly';

local ratelimitLockPercentage(selector) =
  basic.percentageTimeseries(
    'Request % acquiring rate-limit lock within 1m, by host + method',
    description='Percentage of requests that acquire a Gitaly rate-limit lock within 1 minute, by host and method',
    query=|||
      sum(
        rate(
          gitaly_rate_limiting_acquiring_seconds_bucket{
            %(selector)s,
            le="60"
          }[$__interval]
        )
      ) by (environment, type, stage, fqdn, grpc_method)
      /
      sum(
        rate(
          gitaly_rate_limiting_acquiring_seconds_bucket{
            %(selector)s,
            le="+Inf"
          }[$__interval]
        )
      ) by (environment, type, stage, fqdn, grpc_method)
    ||| % { selector: selector },
    legendFormat='{{fqdn}} - {{grpc_method}}'
  );

local inflightGitalyCommandsPerNode(selector) =
  basic.timeseries(
    title='Inflight Git Commands on Node',
    description='Number of Git commands running concurrently per node. Lower is better.',
    query=|||
      avg_over_time(gitaly_commands_running{%(selector)s}[$__interval])
    ||| % { selector: selector },
    legendFormat='{{ fqdn }}',
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local oomKillsPerNode(selector) =
  basic.timeseries(
    title='OOM Kills on Node',
    description='Number of OOM Kills per server.',
    query=|||
      increase(node_vmstat_oom_kill{%(selector)s}[$__interval])
    ||| % { selector: selector },
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local gitalySpawnTimeoutsPerNode(selector) =
  basic.timeseries(
    title='Gitaly Spawn Timeouts per Node',
    description='Golang uses a global lock on process spawning. In order to control contention on this lock Gitaly uses a safety valve. If a request is unable to obtain the lock within a period, a timeout occurs. These timeouts are serious and should be addressed. Non-zero is bad.',
    query=|||
      increase(gitaly_spawn_timeouts_total{%(selector)s}[$__interval])
    ||| % { selector: selector },
    legendFormat='{{ fqdn }}',
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local gitalyCGroupCPUUsagePerCGroup(selector) =
  basic.timeseries(
    title='cgroup: CPU per cgroup',
    description='Rate of CPU usage on every cgroup available on the Gitaly node.',
    query=|||
      topk(20, sum by (id) (rate(container_cpu_usage_seconds_total{%(selector)s}[$__interval])))
    ||| % { selector: selector },
    format='percentunit',
    interval='1m',
    linewidth=1,
    legend_show=false,
    legendFormat='{{ id }}',
  );

local gitalyCGroupCPUQuantile(selector) =
  quantilePanel.timeseries(
    title='cgroup: CPU',
    description='P99/PX CPU usage of all cgroups available on the Gitaly node.',
    query=|||
      rate(
        container_cpu_usage_seconds_total{%(selector)s}[$__interval]
      )
    ||| % { selector: selector },
    format='percentunit',
    interval='1m',
    linewidth=1,
    legendFormat='cgroup: CPU',
  );

local gitalyCGroupMemoryUsagePerCGroup(selector) =
  basic.timeseries(
    title='cgroup: Memory per cgroup',
    description='RSS usage on every cgroup available on the Gitaly node.',
    query=|||
      topk(20, sum by (id) (container_memory_usage_bytes{%(selector)s}))
    ||| % { selector: selector },
    format='bytes',
    interval='1m',
    linewidth=1,
    legend_show=false,
    legendFormat='{{ id }}',
  );

local gitalyCGroupMemoryQuantile(selector) =
  quantilePanel.timeseries(
    title='cgroup: Memory',
    description='P99/PX RRS usage of all cgroups available on the Gitaly node.',
    query=|||
      container_memory_usage_bytes{%(selector)s}
    ||| % { selector: selector },
    format='bytes',
    interval='1m',
    linewidth=1,
    legendFormat='cgroup: Memory',
  );

local selectorHash = {
  environment: '$environment',
  env: '$environment',
  type: 'gitaly',
  fqdn: { re: '$fqdn' },
};
local selectorSerialized = selectors.serializeHash(selectorHash);

local headlineRow(startRow=1) =
  local metricsCatalogServiceInfo = metricsCatalog.getService('gitaly');
  local formatConfig = { serviceType: serviceType };
  local selectorHashWithExtras = selectorHash { type: serviceType };

  local columns =
    singleMetricRow.row(
      serviceType='gitaly',
      aggregationSet=aggregationSets.nodeServiceSLIs,
      selectorHash=selectorHashWithExtras,
      titlePrefix='Gitaly Per-Node Service Aggregated SLIs',
      stableIdPrefix='node-latency-%(serviceType)s' % formatConfig,
      legendFormatPrefix='',
      showApdex=metricsCatalogServiceInfo.hasApdex(),
      showErrorRatio=metricsCatalogServiceInfo.hasErrorRate(),
      showOpsRate=true,
    );
  layout.splitColumnGrid(columns, [7, 1], startRow=startRow);

basic.dashboard(
  'Host Detail',
  tags=['type:gitaly'],
)
.addTemplate(templates.fqdn(query='gitlab_version_info{type="gitaly", component="gitaly", environment="$environment"}', current='file-01-stor-gprd.c.gitlab-production.internal'))
.addPanels(
  headlineRow(startRow=100)
)
.addPanels(
  metricsCatalogDashboards.sliMatrixForService(
    title='🔬 Node SLIs',
    aggregationSet=aggregationSets.nodeComponentSLIs,
    serviceType='gitaly',
    selectorHash=selectorHash,
    startRow=200
  )
)
.addPanel(
  metricsCatalogDashboards.sliDetailMatrix(
    'gitaly',
    'goserver',
    selectorHash,
    [
      { title: 'Overall', aggregationLabels: '', selector: {}, legendFormat: 'goserver' },
    ],
  ), gridPos={ x: 0, y: 2000 }
)
.addPanel(nodeMetrics.nodeMetricsDetailRow(selectorHash), gridPos={ x: 0, y: 3000 })
.addPanel(
  saturationDetail.saturationDetailPanels(selectorHash, components=[
    'cgroup_memory',
    'cpu',
    'disk_space',
    'disk_sustained_read_iops',
    'disk_sustained_read_throughput',
    'disk_sustained_write_iops',
    'disk_sustained_write_throughput',
    'memory',
    'open_fds',
    'single_node_cpu',
    'go_memory',
  ]),
  gridPos={ x: 0, y: 4000, w: 24, h: 1 }
)
.addPanel(
  row.new(title='Node Performance', collapse=true).addPanels(
    layout.grid([
      inflightGitalyCommandsPerNode(selectorSerialized),
      oomKillsPerNode(selectorSerialized),
    ], startRow=5001),
  ),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  },
)
.addPanel(
  row.new(title='Gitaly Safety Mechanisms', collapse=true)
  .addPanels(
    layout.grid([
      gitalySpawnTimeoutsPerNode(selectorSerialized),
      ratelimitLockPercentage(selectorSerialized),
    ], startRow=5101)
  ),
  gridPos={
    x: 0,
    y: 5100,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly process activity', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'gitaly processes',
      selectorHash
      {
        groupname: { re: 'gitaly' },
      },
      aggregationLabels=[],
      startRow=5201
    )
  ),
  gridPos={
    x: 0,
    y: 5200,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='git process activity', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'git processes',
      selectorHash
      {
        groupname: { re: 'git.*' },
      },
      aggregationLabels=['groupname'],
      startRow=5301
    )
  ),
  gridPos={
    x: 0,
    y: 5300,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly-ruby process activity', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'gitaly-ruby processes',
      selectorHash
      {
        groupname: 'gitaly-ruby',
      },
      aggregationLabels=[],
      startRow=5401
    )
  ),
  gridPos={
    x: 0,
    y: 5400,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly command stats by command', collapse=true)
  .addPanels(
    gitalyCommandStats.metricsForNode(
      selectorHash,
      includeDetails=false,
      aggregationLabels=['cmd', 'subcmd'],
      startRow=5501
    )
  ),
  gridPos={
    x: 0,
    y: 5500,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly command stats by RPC', collapse=true)
  .addPanels(
    gitalyCommandStats.metricsForNode(
      selectorHash,
      includeDetails=false,
      aggregationLabels=['grpc_service', 'grpc_method'],
      startRow=5601
    )
  ),
  gridPos={
    x: 0,
    y: 5600,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly command stats by commands per RPC', collapse=true)
  .addPanels(
    gitalyCommandStats.metricsForNode(
      selectorHash,
      aggregationLabels=['grpc_method', 'cmd', 'subcmd'],
      startRow=5701
    )
  ),
  gridPos={
    x: 0,
    y: 5700,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='cgroup', collapse=true)
  .addPanels(
    layout.grid([
      gitalyCGroupCPUUsagePerCGroup(selectorSerialized),
      gitalyCGroupCPUQuantile(selectorSerialized),
      gitalyCGroupMemoryUsagePerCGroup(selectorSerialized),
      gitalyCGroupMemoryQuantile(selectorSerialized),
    ], startRow=5801)
  ),
  gridPos={
    x: 0,
    y: 5800,
    w: 24,
    h: 1,
  }
)
.trailer()
+ {
  links+: platformLinks.triage + platformLinks.services +
          [platformLinks.dynamicLinks('Gitaly Detail', 'type:gitaly')],
}
