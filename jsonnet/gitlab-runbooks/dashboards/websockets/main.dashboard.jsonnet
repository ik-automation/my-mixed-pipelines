local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local railsCommon = import 'gitlab-dashboards/rails_common_graphs.libsonnet';
local workhorseCommon = import 'gitlab-dashboards/workhorse_common_graphs.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';

serviceDashboard.overview('websockets')
.addPanel(
  row.new(title='Connections'),
  gridPos={
    x: 0,
    y: 500,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      basic.timeseries(
        stableId='action_cable_active_connections',
        title='ActionCable Active Connections',
        decimals=2,
        yAxisLabel='Connections',
        description=|||
          Number of ActionCable connections active at the time of sampling.
        |||,
        query=|||
          sum(
            action_cable_active_connections{
              environment="$environment",
              stage="$stage",
            }
          )
        |||,
      ),
    ],
    startRow=750
  )
)
.addPanel(
  row.new(title='Workhorse'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(workhorseCommon.workhorsePanels(serviceType='websockets', serviceStage='$stage', startRow=1001))
.addPanels(
  layout.grid(
    [
      basic.timeseries(
        title='Workhorse Git HTTP Sessions',
        query=|||
          gitlab_workhorse_git_http_sessions_active:total{environment="$environment",stage="$stage",type="websockets"}
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
.addPanels(railsCommon.railsPanels(serviceType='websockets', serviceStage='$stage', startRow=3001))
.overviewTrailer()
