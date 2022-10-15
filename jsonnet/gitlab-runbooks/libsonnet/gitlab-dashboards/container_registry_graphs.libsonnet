local basic = import 'grafana/basic.libsonnet';
local colorScheme = import 'grafana/color_scheme.libsonnet';
local layout = import 'grafana/layout.libsonnet';

{
  http(startRow)::
    layout.grid([
      basic.timeseries(
        title='Requests',
        query='sum(irate(registry_http_requests_total{cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"}[1m])) by (method, route, code)',
        legendFormat='{{ method }} {{ route }}: {{ code }}',
      ),
      basic.timeseries(
        title='In-Flight Requests',
        query='sum(registry_http_in_flight_requests{cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"}) by (method, route, code)',
        legendFormat='{{ method }} {{ route }}',
      ),
    ], cols=3, rowHeight=10, startRow=startRow),

  storageDrivers(startRow)::
    layout.grid([
      basic.timeseries(
        title='Action Latency',
        query='avg(increase(registry_storage_action_seconds_sum{job=~".*registry.*", cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"}[$__interval])) by (action)',
        legendFormat='{{ action }}',
        format='s'
      ),
    ], cols=3, rowHeight=10, startRow=startRow),

  cache(startRow)::
    layout.grid([
      basic.timeseries(
        title='Request Rate',
        query='sum(irate(registry_storage_cache_total{cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"}[1m])) by (type)',
        legend_show=false,
        format='ops'
      ),
      basic.gaugePanel(
        'Hit %',
        query='sum(rate(registry_storage_cache_total{cluster=~"$cluster", environment="$environment", namespace="$namespace", stage="$stage", exported_type="Hit"}[$__interval])) / sum(rate(registry_storage_cache_total{cluster=~"$cluster", environment="$environment", namespace="$namespace", stage="$stage", exported_type="Request"}[$__interval]))',
        max=1,
        unit='percentunit',
        color=[
          { color: colorScheme.criticalColor, value: null },
          { color: colorScheme.errorColor, value: 0.5 },
          { color: colorScheme.normalRangeColor, value: 0.75 },
        ],
      ),
    ], cols=3, rowHeight=10, startRow=startRow),

  version(startRow)::
    layout.grid([
      basic.timeseries(
        title='Version',
        query='count(gitlab_build_info{app="registry", cluster=~"$cluster", environment="$environment", namespace="$namespace", stage="$stage"}) by (cluster, version)',
        legendFormat='{{ cluster }}: {{ version }}',
      ),
    ], cols=3, rowHeight=10, startRow=startRow),
}
