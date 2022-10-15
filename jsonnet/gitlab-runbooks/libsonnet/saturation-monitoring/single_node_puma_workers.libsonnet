local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  single_node_puma_workers: resourceSaturationPoint({
    title: 'Puma Worker Saturation per Node',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: ['web', 'api', 'git', 'sidekiq', 'websockets'],
    description: |||
      Puma thread utilization per node.

      Puma uses a fixed size thread pool to handle HTTP requests. This metric shows how many threads are busy handling requests. When this resource is saturated,
      we will see puma queuing taking place. Leading to slowdowns across the application.

      Puma saturation is usually caused by latency problems in downstream services: usually Gitaly or Postgres, but possibly also Redis.
      Puma saturation can also be caused by traffic spikes.
    |||,
    grafana_dashboard_uid: 'sat_single_node_puma_workers',
    resourceLabels: ['fqdn'],
    query: |||
      sum by(%(aggregationLabels)s) (avg_over_time(instance:puma_active_connections:sum{%(selector)s}[%(rangeInterval)s]))
      /
      sum by(%(aggregationLabels)s) (instance:puma_max_threads:sum{%(selector)s})
    |||,
    slos: {
      soft: 0.85,
      hard: 0.90,
    },
  }),
}
