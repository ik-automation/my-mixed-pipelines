local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  elastic_thread_pools: resourceSaturationPoint({
    title: 'Thread pool utilization',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['logging', 'search'],
    description: |||
      Utilization of each thread pool on each node.

      Descriptions of the threadpool types can be found at
      https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-threadpool.html.
    |||,
    grafana_dashboard_uid: 'sat_elastic_thread_pools',
    resourceLabels: ['name', 'exported_type'],
    burnRatePeriod: '5m',
    query: |||
      (
        avg_over_time(elasticsearch_thread_pool_active_count{exported_type!="snapshot", %(selector)s}[%(rangeInterval)s])
        /
        (avg_over_time(elasticsearch_thread_pool_threads_count{exported_type!="snapshot", %(selector)s}[%(rangeInterval)s]) > 0)
      )
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
