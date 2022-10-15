local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  kube_pool_max_nodes: resourceSaturationPoint({
    title: 'Kube Pool Max Node Limit',
    severity: 's3',
    // Not all information required to evaluate this saturation point is available in
    // the Prometheus instance. For that reason, we need to evaluate this metric in Thanos
    // This is not ideal. We should re-evaluate this once https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/13179
    // is merged
    dangerouslyThanosEvaluated: true,

    horizontallyScalable: true,
    appliesTo: metricsCatalog.findKubeProvisionedServicesWithDedicatedNodePool(),
    description: |||
      A GKE kubernetes node pool is close to it's maximum number of nodes.

      The maximum is defined in terraform, via the `max_node_count` field of a node pool. The limit is per-zone, so for
      single zone clusters the number of nodes will match the limit, for regional clusters, the limit is multiplied by
      the number of zones the cluster is deployed over.
    |||,
    runbook: 'docs/kube/kubernetes.md#hpascalecapability',
    grafana_dashboard_uid: 'sat_kube_pool_max_nodes',
    resourceLabels: ['cluster', 'label_pool', 'shard'],
    query: |||
      count by (cluster, env, environment, label_pool, tier, type, stage, shard) (
        kube_node_labels:labeled{%(selector)s}
      )
      / on(cluster, env, environment, label_pool) group_left() (
        label_replace(
          terraform_report_google_cluster_node_pool_max_node_count,
          "label_pool", "$0", "pool_name", ".*"
        )
        * on(cluster, env, environment) group_left()
        count by (cluster, env, environment) (
          group by (cluster, env, environment, label_topology_kubernetes_io_zone) (
            kube_node_labels:labeled{%(selector)s}
          )
        )
      )
    |||,
    slos: {
      soft: 0.90,
      hard: 0.95,
    },
  }),
}
