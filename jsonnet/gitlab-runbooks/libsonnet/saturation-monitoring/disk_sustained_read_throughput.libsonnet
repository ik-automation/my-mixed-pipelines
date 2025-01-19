local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  disk_sustained_read_throughput: resourceSaturationPoint({
    title: 'Disk Sustained Read Throughput Utilization per Node',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findServicesWithTag(tag='disk_performance_monitoring'),
    description: |||
      Disk sustained read throughput utilization per node.
    |||,
    grafana_dashboard_uid: 'sat_disk_sus_read_throughput',
    resourceLabels: ['fqdn', 'device'],
    query: |||
      rate(node_disk_read_bytes_total{device!="sda", %(selector)s}[%(rangeInterval)s])
      /
      node_disk_max_read_bytes_seconds{device!="sda", %(selector)s}
    |||,
    burnRatePeriod: '20m',
    slos: {
      soft: 0.70,
      hard: 0.80,
      alertTriggerDuration: '25m',
    },
  }),
}
