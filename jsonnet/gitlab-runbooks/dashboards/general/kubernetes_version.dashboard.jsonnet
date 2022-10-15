local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local graphPanel = grafana.graphPanel;
local tablePanel = grafana.tablePanel;
local basic = import 'grafana/basic.libsonnet';

local masterVersionTablePanel =
  tablePanel.new(
    'Master Version',
    datasource='$PROMETHEUS_DS',
    styles=[
      {
        type: 'hidden',
        pattern: 'Time',
        alias: 'Time',
      },
      {
        type: 'hidden',
        pattern: 'Value',
        alias: 'Value',
      },
    ],
  )
  .addTarget(  // Master Version
    promQuery.target(
      |||
        max (kubernetes_build_info{environment="$environment", job="apiserver"}) by (node, gitVersion)
      |||,
      format='table',
      instant=true
    )
  );

local masterVersionPanel =
  graphPanel.new(
    'Master Version Over Time',
    datasource='$PROMETHEUS_DS',
  )
  .addTarget(  // Master Version over time
    promQuery.target(
      |||
        count (kubernetes_build_info{environment="$environment", job="apiserver"}) by (gitVersion)
      |||,
    )
  );

local nodeVersionsTablePanel =
  tablePanel.new(
    'Node Versions',
    datasource='$PROMETHEUS_DS',
    styles=[
      {
        type: 'hidden',
        pattern: 'Time',
        alias: 'Time',
      },
      {
        type: 'hidden',
        pattern: 'Value',
        alias: 'Value',
      },
    ],
  )
  .addTarget(  // Node Versions
    promQuery.target(
      |||
        max(kube_node_info{environment="$environment"}) by (cluster, node, kernel_version, kubelet_version, kubeproxy_version)
      |||,
      format='table',
      instant=true
    )
  );

local nodeVersionsPanel =
  graphPanel.new(
    'Node Versions Over Time',
    datasource='$PROMETHEUS_DS',
  )
  .addTarget(  // Node Versions over time
    promQuery.target(
      |||
        count (kube_node_info{environment="$environment"}) by (cluster, node, kubelet_version)
      |||,
    )
  );

basic.dashboard(
  'Kubernetes Version Matrix',
  tags=['general', 'kubernetes'],
)
.addPanel(masterVersionTablePanel, gridPos={ x: 0, y: 0, w: 24, h: 3 })
.addPanel(masterVersionPanel, gridPos={ x: 0, y: 1, w: 24, h: 10 })
.addPanel(nodeVersionsTablePanel, gridPos={ x: 0, y: 2, w: 24, h: 18 })
.addPanel(nodeVersionsPanel, gridPos={ x: 0, y: 3, w: 24, h: 10 })
