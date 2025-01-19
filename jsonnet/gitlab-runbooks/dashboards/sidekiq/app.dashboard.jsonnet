local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local common = import 'gitlab-dashboards/container_common_graphs.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;

basic.dashboard(
  'Application Info',
  tags=['sidekiq'],
)
.addTemplate(templates.gkeCluster)
.addTemplate(templates.stage)
.addTemplate(templates.namespaceGitlab)
.addTemplate(
  template.custom(
    'Deployment',
    'gitlab-sidekiq-export,',
    'gitlab-sidekiq-export',
    hide='variable',
  )
)
.addPanel(

  row.new(title='Stackdriver Metrics'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(common.logMessages(startRow=1))
.addPanel(

  row.new(title='General Counters'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(common.generalRubyCounters(startRow=1001))
+ {
  links+: platformLinks.triage +
          platformLinks.services +
          [platformLinks.dynamicLinks('Sidekiq Detail', 'type:sidekiq')],
}
