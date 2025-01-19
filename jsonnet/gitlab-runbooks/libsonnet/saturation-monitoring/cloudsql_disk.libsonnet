local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  cloudsql_disk: resourceSaturationPoint({
    title: 'CloudSQL Disk Utilization',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findServicesWithTag(tag='cloud-sql'),
    description: |||
      CloudSQL Disk utilization.

      See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
      more details
    |||,
    grafana_dashboard_uid: 'sat_cloudsql_disk',
    resourceLabels: ['database_id'],
    burnRatePeriod: '5m',
    staticLabels: {
      type: 'monitoring',
      tier: 'inf',
      stage: 'main',
    },
    query: |||
      avg_over_time(stackdriver_cloudsql_database_cloudsql_googleapis_com_database_disk_utilization{%(selector)s}[%(rangeInterval)s])
    |||,
    slos: {
      soft: 0.85,
      hard: 0.90,
    },
  }),
}
