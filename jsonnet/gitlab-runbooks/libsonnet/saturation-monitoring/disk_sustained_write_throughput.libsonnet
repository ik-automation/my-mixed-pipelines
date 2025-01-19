local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  disk_sustained_write_throughput: resourceSaturationPoint({
    title: 'Disk Sustained Write Throughput Utilization per Node',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findServicesWithTag(tag='disk_performance_monitoring'),
    description: |||
      Gitaly runs on Google Cloud's Persistent Disk product. This has a published sustained
      maximum write throughput value. This value can be exceeded for brief periods.

      If a single node is consistently reaching saturation, it may indicate a noisy-neighbour repository,
      possible abuse or it may indicate that the node needs rebalancing.

      More information can be found at
      https://cloud.google.com/compute/docs/disks/performance.
    |||,
    grafana_dashboard_uid: 'sat_disk_sus_write_throughput',
    resourceLabels: ['fqdn', 'device'],
    query: |||
      rate(node_disk_written_bytes_total{device!="sda", %(selector)s}[%(rangeInterval)s])
      /
      node_disk_max_write_bytes_seconds{device!="sda", %(selector)s}
    |||,
    burnRatePeriod: '20m',
    slos: {
      soft: 0.70,
      hard: 0.80,
      alertTriggerDuration: '25m',
    },
  }),
}
