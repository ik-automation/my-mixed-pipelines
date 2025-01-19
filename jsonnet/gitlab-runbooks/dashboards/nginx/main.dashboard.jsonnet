local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

serviceDashboard.overview('nginx')
.addPanel(
  row.new(title='NGINX Ingress'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Connections by State',
      description='Current number of client connections with state {active, reading, writing, waiting}',
      query='sum by (env, stage, state) (nginx_ingress_controller_nginx_process_connections{env="$environment", stage="$stage"})',
      interval='1m',
      intervalFactor=2,
      legendFormat='{{ state }}',
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='Total Connections',
      description='Total number of connections with state {accepted, handled}',
      query='sum by (env, stage, state) (rate(nginx_ingress_controller_nginx_process_connections_total{env="$environment", stage="$stage"}[$__interval]))',
      interval='1m',
      intervalFactor=2,
      legendFormat='{{ state }}',
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
  ], cols=2, rowHeight=10, startRow=1001)
)
.overviewTrailer()
