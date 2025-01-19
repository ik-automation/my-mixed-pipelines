local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local railsCommon = import 'gitlab-dashboards/rails_common_graphs.libsonnet';
local workhorseCommon = import 'gitlab-dashboards/workhorse_common_graphs.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';

serviceDashboard.overview('web')
.addPanel(
  row.new(title='Workhorse'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(workhorseCommon.workhorsePanels(serviceType='web', serviceStage='$stage', startRow=1001))
.addPanel(
  row.new(title='Rails'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(railsCommon.railsPanels(serviceType='web', serviceStage='$stage', startRow=3001))
.addPanel(
  row.new(title='puma parent processes', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'puma_parent',
      {
        environment: '$environment',
        env: '$environment',
        groupname: 'puma_parent',
        type: 'web',
        stage: '$stage',
      },
      startRow=1
    )
  ),
  gridPos={
    x: 0,
    y: 4000,
    w: 24,
    h: 1,
  },
)
.addPanel(
  row.new(title='puma worker processes', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'puma_worker',
      {
        environment: '$environment',
        env: '$environment',
        groupname: 'puma_worker',
        type: 'web',
        stage: '$stage',
      },
      startRow=1
    )
  ),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  },
)
.overviewTrailer()
