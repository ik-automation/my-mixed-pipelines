local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  kube_node_ips: resourceSaturationPoint({
    title: 'Node IP subnet saturation',
    severity: 's3',
    dangerouslyThanosEvaluated: true,
    horizontallyScalable: false,
    appliesTo: ['kube'],
    description: |||
      This resource measures the number of nodes per subnet.

      If it is becoming saturated, it may indicate that clusters need to be rebuilt with
      a larger subnet.
    |||,
    grafana_dashboard_uid: 'sat_kube_node_ips',
    resourceLabels: ['cluster'],
    staticLabels: {
      type: 'kube',
      tier: 'inf',
      stage: 'main',
    },
    burnRatePeriod: '5m',
    query: |||
      sum(:kube_pod_info_node_count:) by (%(aggregationLabels)s)
      /
      sum(
        gitlab:gcp_subnet_max_ips * on (subnet) group_right gitlab:cluster:subnet:mapping
      ) by (%(aggregationLabels)s)
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
