local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  kube_pool_cpu: resourceSaturationPoint({
    title: 'Average Node Pool CPU Utilization',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findKubeProvisionedServicesWithDedicatedNodePool(),
    description: |||
      This resource measures average CPU utilization across an all cores in the node pool for
      a service fleet.

      If it is becoming saturated, it may indicate that the fleet needs horizontal scaling.
    |||,
    grafana_dashboard_uid: 'sat_kube_pool_cpu',
    resourceLabels: [],
    burnRatePeriod: '5m',
    query: |||
      1 - avg by (%(aggregationLabels)s) (
        rate(node_cpu_seconds_total:labeled{mode="idle", %(selector)s}[%(rangeInterval)s])
      )
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
