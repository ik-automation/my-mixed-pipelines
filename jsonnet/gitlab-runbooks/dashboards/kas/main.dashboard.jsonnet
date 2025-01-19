local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';

serviceDashboard.overview('kas')
.addPanel(
  row.new(title='Kubernetes Agent'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.multiTimeseries(
      title='Number of connected agents and agentk Pods',
      queries=[
        {
          legendFormat: 'Number of connected agentk Pods',
          query: 'sum(grpc_server_requests_in_flight{app="kas", stage="$stage", env="$environment", grpc_service="gitlab.agent.agent_configuration.rpc.AgentConfiguration", grpc_method="GetConfiguration"})',
        },
        {
          legendFormat: 'Number of connected agents',
          query: 'avg(connected_agents_count{app="kas", stage="$stage", env="$environment"})',
        },
      ],
      yAxisLabel='Count',
      legend_show=true,
    ),
  ], cols=1, rowHeight=10, startRow=1001)
)
.overviewTrailer()
