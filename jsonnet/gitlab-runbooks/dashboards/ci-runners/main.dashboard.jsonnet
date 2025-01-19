local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local nodeMetrics = import 'gitlab-dashboards/node_metrics.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local row = grafana.row;
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';

local selectorHash = {
  environment: '$environment',
  env: '$environment',
  type: 'ci',
};

serviceDashboard.overview('ci-runners')
.addPanel(
  nodeMetrics.nodeMetricsDetailRow(selectorHash, title='🖥️ HAProxy Node Metrics'),
  gridPos={
    x: 0,
    y: 350,
    w: 24,
    h: 1,
  },
)
.addPanel(
  row.new(title='HAProxy process', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'haproxy',
      {
        environment: '$environment',
        groupname: 'haproxy',
        type: 'ci',
        stage: '$stage',
      },
      startRow=401
    )
  ),
  gridPos={
    x: 0,
    y: 400,
    w: 24,
    h: 1,
  }
)
.overviewTrailer()
