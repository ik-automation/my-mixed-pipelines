local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local common = import 'gitlab-dashboards/container_common_graphs.libsonnet';
local crCommon = import 'gitlab-dashboards/container_registry_graphs.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local statPanel = grafana.statPanel;

basic.dashboard(
  'Application Detail',
  tags=['container registry', 'docker', 'registry'],
)
.addTemplate(templates.gkeCluster)
.addTemplate(templates.stage)
.addTemplate(templates.namespaceGitlab)
.addTemplate(
  template.custom(
    'Deployment',
    'gitlab-(cny-)?registry,',
    'gitlab-(cny-)?registry',
    hide='variable',
  )
)
.addTemplate(template.new(
  'cluster',
  '$PROMETHEUS_DS',
  'label_values(registry_storage_action_seconds_count{environment="$environment"}, cluster)',
  current=null,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
  allValues='.*',
))
.addPanel(

  row.new(title='Version'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(crCommon.version(startRow=1))
.addPanel(

  row.new(title='Host Resources Usage'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(common.generalCounters(startRow=1001))
.addPanel(

  row.new(title='HTTP API'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(crCommon.http(startRow=2001))
.addPanel(

  row.new(title='Storage Drivers'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(crCommon.storageDrivers(startRow=3001))
.addPanel(

  row.new(title='Cache'),
  gridPos={
    x: 0,
    y: 4000,
    w: 24,
    h: 1,
  }
)
.addPanels(crCommon.cache(startRow=4001))
.addPanel(
  row.new(title='Network'),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    statPanel.new(
      title='Uploaded Bytes',
      description='The number of bytes uploaded to the registry.',
      reducerFunction='sum',
      unit='bytes',
    )
    .addTarget(
      promQuery.target(
        'sum(increase(registry_storage_blob_upload_bytes_sum{environment="$environment", stage="$stage"}[$__interval]))',
      )
    ),
    statPanel.new(
      title='Downloaded Bytes',
      description='The number of bytes downloaded from the registry.',
      reducerFunction='sum',
      unit='bytes',
    )
    .addTarget(
      promQuery.target(
        'sum(increase(registry_storage_blob_download_bytes_sum{environment="$environment", stage="$stage"}[$__interval]))',
      )
    ),
  ], cols=2, rowHeight=8, startRow=5001),
)
