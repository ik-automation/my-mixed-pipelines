local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  elastic_single_node_cpu: resourceSaturationPoint({
    title: 'Average CPU Utilization per Node',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['logging', 'search'],
    description: |||
      Average CPU per Node.

      This resource measures all CPU across a fleet. If it is becoming saturated, it may indicate that the fleet needs horizontal or
      vertical scaling. The metrics are coming from elasticsearch_exporter.
    |||,
    grafana_dashboard_uid: 'sat_elastic_single_node_cpu',
    resourceLabels: ['name'],
    burnRatePeriod: '5m',
    query: |||
      avg_over_time(elasticsearch_process_cpu_percent{%(selector)s}[%(rangeInterval)s]) / 100
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
