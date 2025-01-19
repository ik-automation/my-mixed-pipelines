local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local k8sPodsCommon = import 'gitlab-dashboards/kubernetes_pods_common.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';

basic.dashboard(
  'Pod Info',
  tags=[
    'consul',
  ],
)
.addTemplate(templates.gkeCluster)
.addTemplate(templates.stage)
.addTemplate(templates.namespaceDefault('consul'))
.addTemplate(templates.Node)
.addTemplate(
  template.custom(
    name='Daemonset',
    query='consul-consul',
    current='consul-consul',
    hide='variable',
  )
)
.addPanel(

  row.new(title='Consul Version'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.version(deploymentKind='Daemonset', startRow=1))
.addPanel(
  row.new(title='Daemonset Info'),
  gridPos={
    x: 0,
    y: 500,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.deployment(deploymentKind='Daemonset', startRow=501))
.addPanels(k8sPodsCommon.status(deploymentKind='Daemonset', startRow=502))
.addPanel(

  row.new(title='CPU'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.cpu(deploymentKind='Daemonset', startRow=1001))
.addPanel(

  row.new(title='Memory'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.memory(deploymentKind='Daemonset', startRow=2001, container='consul'))
.addPanel(

  row.new(title='Network'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.network(deploymentKind='Daemonset', startRow=3001))
+ {
  links+: platformLinks.triage +
          platformLinks.services,
}
