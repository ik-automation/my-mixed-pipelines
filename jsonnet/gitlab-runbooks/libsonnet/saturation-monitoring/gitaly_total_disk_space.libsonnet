local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  gitaly_total_disk_space: resourceSaturationPoint({
    title: 'Gitaly Total Disk Utilization',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: ['gitaly'],
    description: |||
      Gitaly Total Disk Utilization.

      This saturation metric monitors the total available capacity across the entire Gitaly fleet.
      By ensuring that we keep sufficient headroom on the saturation resource, we are able to
      spread load across the fleet.

      When this alert fires, consider adding new Gitaly nodes. The [Gitaly Capacity Planner](https://dashboards.gitlab.net/d/alerts-gitaly_capacity_planner/alerts-gitaly-capacity-planner?orgId=1)
      dashboard can help determine how many new nodes will be needed.
    |||,
    grafana_dashboard_uid: 'sat_gitaly_total_disk_space',
    resourceLabels: ['shard'],
    query: |||
      1 - (
        sum by (%(aggregationLabels)s) (
          node_filesystem_avail_bytes{%(selector)s, device="/dev/sdb"}
        )
        /
        sum by (%(aggregationLabels)s) (
          node_filesystem_size_bytes{%(selector)s, device="/dev/sdb"}
        )
      )
    |||,
    slos: {
      soft: 0.69,
      hard: 0.70,
    },
  }),
}
