local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;

serviceDashboard.overview('plantuml')
.addPanel(
  row.new(title='Stackdriver Logs'),
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
      title='Error messages',
      description='Stackdriver Errors',
      query='sum(stackdriver_gke_container_logging_googleapis_com_log_entry_count{severity="ERROR", namespace_id="plantuml"}) by (cluster, container) / 60',
      legendFormat='{{ container }}',
      format='ops',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='Info messages',
      description='Stackdriver Errors',
      query='sum(stackdriver_gke_container_logging_googleapis_com_log_entry_count{severity="INFO", namespace_id="plantuml"}) by (cluster, container) / 60',
      legendFormat='{{ container }}',
      format='ops',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),

  ], cols=2, rowHeight=10, startRow=1001)
)
.addPanel(
  row.new(title='Stackdriver LoadBalancer'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='HTTP Requests CACHE HIT',
      description='HTTP Requests',
      query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{cache_result!="MISS", environment="$environment", forwarding_rule_name=~".*plantuml.*"}) by (response_code) / 60',
      legendFormat='{{ response_code }}',
      format='ops',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='HTTP Requests bytes CACHE HIT',
      description='HTTP Requests',
      query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_request_bytes_count{cache_result!="MISS", environment="$environment", forwarding_rule_name=~".*plantuml.*"}) by (response_code)',
      legendFormat='{{ response_code }}',
      format='bytes',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='HTTP Requests CACHE MISS',
      description='HTTP Requests',
      query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*plantuml.*"}) by (response_code) / 60',
      legendFormat='{{ response_code }}',
      format='ops',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='HTTP Requests bytes CACHE MISS',
      description='HTTP Requests',
      query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_request_bytes_count{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*plantuml.*"}) by (response_code)',
      legendFormat='{{ response_code }}',
      format='bytes',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
  ], cols=2, rowHeight=10, startRow=2001)
)

.addPanel(
  row.new(title='Stackdriver LoadBalancer Latencies'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='90th Percentile Latency CACHE MISS',
      description='90th Percentile Latency CACHE MISS',
      query='histogram_quantile(0.9,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*plantuml.*"}[10m]))',
      legendFormat='{{ response_code }}',
      format='ms',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='60th Percentile Latency CACHE MISS',
      description='60th Percentile Latency CACHE MISS',
      query='histogram_quantile(0.6,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*plantuml.*"}[10m]))',
      legendFormat='{{ response_code }}',
      format='ms',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='90th Percentile Latency CACHE HIT',
      description='90th Percentile Latency CACHE MISS',
      query='histogram_quantile(0.9,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*plantuml.*"}[10m]))',
      legendFormat='{{ response_code }}',
      format='ms',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='60th Percentile Latency CACHE HIT',
      description='60th Percentile Latency CACHE MISS',
      query='histogram_quantile(0.6,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*plantuml.*"}[10m]))',
      legendFormat='{{ response_code }}',
      format='ms',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
  ], cols=2, rowHeight=10, startRow=3001)
)
.overviewTrailer()
