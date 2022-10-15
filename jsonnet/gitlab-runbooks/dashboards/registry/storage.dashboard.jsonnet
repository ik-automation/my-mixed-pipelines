local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local statPanel = grafana.statPanel;
local promQuery = import 'grafana/prom_query.libsonnet';

basic.dashboard(
  'Storage Detail',
  tags=['container registry', 'docker', 'registry', 'type:registry'],
)
.addTemplate(templates.gkeCluster)
.addTemplate(templates.stage)
.addTemplate(templates.namespaceGitlab)
.addTemplate(
  template.custom(
    'Deployment',
    'gitlab-registry,',
    'gitlab-registry',
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
  row.new(title='GCS Bucket'),
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
      title='Total Size',
      description='Total size of objects per bucket. Values are measured once per day.',
      query='stackdriver_gcs_bucket_storage_googleapis_com_storage_total_bytes{bucket_name=~"gitlab-.*-registry", environment="$environment"}',
      legendFormat='{{ bucket_name }}',
      format='bytes'
    ),
    basic.timeseries(
      title='Object Count',
      description='Total number of objects per bucket, grouped by storage class. Values are measured once per day.',
      query='sum by (storage_class) (stackdriver_gcs_bucket_storage_googleapis_com_storage_object_count{bucket_name=~"gitlab-.*-registry", environment="$environment"})',
      legendFormat='{{ storage_class }}'
    ),
    basic.timeseries(
      title='Daily Throughput',
      description='Total daily storage in byte*seconds used by the bucket, grouped by storage class.',
      query='sum by (storage_class) (stackdriver_gcs_bucket_storage_googleapis_com_storage_total_byte_seconds{bucket_name=~"gitlab-.*-registry", environment="$environment"})',
      format='Bps',
      yAxisLabel='Bytes/s',
      legendFormat='{{ storage_class }}'
    ),
  ], cols=3, rowHeight=10, startRow=1)
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='RPS (Overall)',
      query='sum(rate(registry_storage_action_seconds_count{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))',
      legend_show=false
    ),
    basic.timeseries(
      title='RPS (Per Action)',
      query=|||
        sum by (action) (
          rate(registry_storage_action_seconds_count{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval])
        )
      |||,
      legendFormat='{{ action }}'
    ),
    basic.timeseries(
      title='Estimated p95 Latency (Overall)',
      query=|||
        histogram_quantile(
          0.950000,
          sum by (le) (
            rate(registry_storage_action_seconds_bucket{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval])
          )
        )
      |||,
      format='s',
      legend_show=false
    ),
    basic.timeseries(
      title='Estimated p95 Latency (Per Action)',
      query=|||
        histogram_quantile(
          0.950000,
          sum by (action,le) (
            rate(registry_storage_action_seconds_bucket{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval])
          )
        )
      |||,
      format='s',
      legendFormat='{{ action }}'
    ),
    basic.timeseries(
      title='Rate Limited Requests Rate',
      description='Rate of 429 Too Many Requests responses received from GCS',
      query='sum(rate(registry_storage_rate_limit_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))',
      legend_show=false,
      format='ops'
    ),
  ], cols=3, rowHeight=10, startRow=1001)
)
.addPanel(
  row.new(title='Cloud CDN Requests'),
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
      title='Percentage of HTTP Requests CACHE HIT by response',
      description='HTTP Requests',
      query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code) / sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code)',
      legendFormat='{{ response_code }}',
      format='percentunit',
      max=1,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='HTTP Requests CACHE HIT (bytes)',
      description='HTTP Requests',
      query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_request_bytes_count{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code)',
      legendFormat='{{ response_code }}',
      format='bytes',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='Percentage of HTTP Requests CACHE MISS by response',
      description='HTTP Requests',
      query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code) / sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code)',
      legendFormat='{{ response_code }}',
      format='percentunit',
      max=1,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='HTTP Requests CACHE MISS (bytes)',
      description='HTTP Requests',
      query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_request_bytes_count{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code)',
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
  row.new(title='Cloud CDN Latencies'),
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
      title='60th Percentile Latency CACHE HIT',
      description='60th Percentile Latency CACHE MISS',
      query='histogram_quantile(0.6,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}[10m]))',
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
      query='histogram_quantile(0.9,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}[10m]))',
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
      query='histogram_quantile(0.6,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}[10m]))',
      legendFormat='{{ response_code }}',
      format='ms',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='90th Percentile Latency CACHE MISS',
      description='90th Percentile Latency CACHE MISS',
      query='histogram_quantile(0.9,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}[10m]))',
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

.addPanel(
  row.new(title='Cloud CDN Redirects'),
  gridPos={
    x: 0,
    y: 4000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.percentageTimeseries(
      title='Percentage of Redirects to CDN',
      description='The percentage of blob HEAD/GET requests redirected to Google Cloud CDN.',
      query=|||
        sum (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage", backend="cdn"}[$__interval]))
        /
        sum (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))
      |||,
      interval='5m',
      intervalFactor=2,
      legend_show=false,
      linewidth=2
    ),
    basic.timeseries(
      title='Number of Redirects (Per Backend)',
      description='The number of blob HEAD/GET requests redirected to Google Cloud Storage or Google Cloud CDN.',
      query='sum by (backend) (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))',
      format='short',
      legendFormat='{{ backend }}',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='Count',
      linewidth=2
    ),
    basic.percentageTimeseries(
      title='Percentage of Redirects to CDN Skipped',
      description=|||
        The percentage of blob HEAD/GET requests that were not redirected to Google Cloud CDN because of a given reason:
          - `non_eligible`: This means that the request JWT token was not marked with the `cdn_redirect` flag by Rails. The number
          of JWT tokens marked as such is currently controlled by the `container_registry_cdn_redirect` feature flag (percentage of time).

          - `gcp`: This means that the request originates within GCP, and as such we redirected it to GCS and not CDN.
      |||,
      query=|||
        sum (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage", bypass="true"}[$__interval]))
        /
        sum (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))
      |||,
      interval='5m',
      intervalFactor=2,
      legend_show=false,
      linewidth=2
    ),
    basic.timeseries(
      title='Number of Redirects to CDN Skipped (Per Reason)',
      description=|||
        The number of blob HEAD/GET requests that were not redirected to Google Cloud CDN because of a given reason:
          - `non_eligible`: This means that the request JWT token was not marked with the `cdn_redirect` flag by Rails. The number
          of JWT tokens marked as such is currently controlled by the `container_registry_cdn_redirect` feature flag (percentage of time).

          - `gcp`: This means that the request originates within GCP, and as such we redirected it to GCS and not CDN.
      |||,
      query='sum by (bypass_reason) (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage", bypass="true"}[$__interval]))',
      format='short',
      legendFormat='{{ bypass_reason }}',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='Count',
      linewidth=2
    ),
  ], cols=4, rowHeight=10, startRow=4001)
)
