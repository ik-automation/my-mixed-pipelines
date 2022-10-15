local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  opensearch_cpu: resourceSaturationPoint({
    title: 'Average CPU Utilization for Opensearch',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['logging'],
    description: |||
      Average CPU utilization.

      This resource measures the CPU utilization for the selected cluster or domain. If it is becoming saturated, it may indicate that the fleet needs horizontal or
      vertical scaling. The metrics are coming from cloudwatch_exporter.
    |||,
    grafana_dashboard_uid: 'sat_opensearch_cpu',
    resourceLabels: [],
    query: |||
      avg_over_time(aws_es_cpuutilization_average[%(rangeInterval)s])/100
    |||,
    slos: {
      soft: 0.65,
      hard: 0.80,
    },
  }),
}
