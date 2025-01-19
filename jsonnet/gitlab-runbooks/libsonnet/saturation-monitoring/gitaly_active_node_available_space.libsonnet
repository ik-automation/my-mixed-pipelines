local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local selectors = import 'promql/selectors.libsonnet';

{
  gitaly_active_node_available_space: resourceSaturationPoint({
    title: 'Gitaly Active Node Available Space',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: ['gitaly'],
    description: |||
      Available space on active gitaly nodes

      Active nodes are Gitaly nodes that are currently receiving new repositories

      We allow new Gitaly nodes to receive traffic until their disk is about 80%
      full. After which we mark the weight of the node as 0 in the
      [Gitaly shard weights assigner](https://gitlab.com/gitlab-com/gl-infra/gitaly-shard-weights-assigner/-/blob/master/assigner.rb#L9).

      To make sure we always have enough shards receiving new repositories, we want
      to have at least 10% of the total storage to be available for new projects.
      When this resource gets saturated, we could be creating to many projects on
      a limited set of nodes, which could cause these nodes to be busier than usual.

      When this alert fires, consider adding new gitaly nodes when the
      gitaly_total_disk_space component is also close to saturation. Or
      [rebalance](https://gitlab.com/gitlab-com/runbooks/-/blob/master/docs/gitaly/storage-rebalancing.md)
      some Gitaly nodes moving some projects off to empty nodes so they can also
      receive new traffic.
    |||,
    grafana_dashboard_uid: 'sat_gitaly_active_available_space',
    resourceLabels: ['shard'],
    query: |||
      1 - (
        sum by (%(aggregationLabels)s) (
          node_filesystem_avail_bytes{%(selector)s, %(gitalyDiskSelector)s}
          and
          (instance:node_filesystem_avail:ratio{%(selector)s, %(gitalyDiskSelector)s} > 0.2)
        )
        /
        sum by (%(aggregationLabels)s)(
          node_filesystem_size_bytes{%(selector)s, %(gitalyDiskSelector)s}
        )
      )
    |||,
    queryFormatConfig: {
      gitalyDiskSelector: selectors.serializeHash({
        shard: { oneOf: ['default', 'praefect'] },
        device: '/dev/sdb',
      }),
    },
    slos: {
      soft: 0.90,
      hard: 0.95,
    },
  }),
}
