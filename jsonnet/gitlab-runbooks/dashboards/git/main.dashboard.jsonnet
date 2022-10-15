local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';
local railsCommon = import 'gitlab-dashboards/rails_common_graphs.libsonnet';
local workhorseCommon = import 'gitlab-dashboards/workhorse_common_graphs.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';

serviceDashboard.overview('git')
.addPanel(
  row.new(title='Workhorse'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(workhorseCommon.workhorsePanels(serviceType='git', serviceStage='$stage', startRow=1001))
.addPanels(
  layout.grid(
    [
      basic.timeseries(
        title='Workhorse Git HTTP Sessions',
        query=|||
          gitlab_workhorse_git_http_sessions_active:total{environment="$environment",stage="$stage",type="git"}
        |||,
        legendFormat='Sessions',
        stableId='workhorse-sessions',
      ),
    ],
    startRow=2000
  )
)
.addPanel(
  row.new(title='Rails'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(railsCommon.railsPanels(serviceType='git', serviceStage='$stage', startRow=3001))
.addPanel(
  row.new(title='sshd processes', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'sshd',
      {
        environment: '$environment',
        groupname: 'sshd',
        type: 'git',
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
