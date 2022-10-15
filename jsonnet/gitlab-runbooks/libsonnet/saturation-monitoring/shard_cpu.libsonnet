local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  shard_cpu: resourceSaturationPoint({
    title: 'Average CPU Utilization per Shard',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findVMProvisionedServices(first='gitaly'),
    description: |||
      This resource measures average CPU utilization across an all cores in a shard of a
      service fleet. If it is becoming saturated, it may indicate that the
      shard needs horizontal or vertical scaling.
    |||,
    grafana_dashboard_uid: 'sat_shard_cpu',
    resourceLabels: ['shard'],
    burnRatePeriod: '5m',
    query: |||
      1 - avg by (%(aggregationLabels)s) (
        rate(node_cpu_seconds_total{mode="idle", %(selector)s}[%(rangeInterval)s])
      )
    |||,
    slos: {
      soft: 0.85,
      hard: 0.95,
    },
  }),
}
