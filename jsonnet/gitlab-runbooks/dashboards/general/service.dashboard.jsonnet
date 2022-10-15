local keyMetrics = import 'gitlab-dashboards/key_metrics.libsonnet';
local nodeMetrics = import 'gitlab-dashboards/node_metrics.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local templates = import 'grafana/templates.libsonnet';

basic.dashboard(
  'Service Platform Metrics',
  tags=['general'],
)
.addTemplate(templates.type)
.addTemplate(templates.stage)
.addPanels(
  keyMetrics.headlineMetricsRow(
    '$type',
    3001,
    selectorHash={ env: '$environment', environment: '$environment', type: '$type', stage: '$stage' },
    rowHeight=10
  )
)
.addPanel(
  nodeMetrics.nodeMetricsDetailRow('environment="$environment", stage="$stage", type="$type"'),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  }
)
.trailer()
+ {
  links+: platformLinks.services + platformLinks.triage,
}
