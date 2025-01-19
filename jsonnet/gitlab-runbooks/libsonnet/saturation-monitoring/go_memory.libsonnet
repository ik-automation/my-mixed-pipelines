local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  go_memory: resourceSaturationPoint({
    title: 'Go Memory Utilization per Node',
    severity: 's4',
    dangerouslyThanosEvaluated: true,
    horizontallyScalable: true,
    appliesTo: std.setInter(
      std.set(metricsCatalog.findServicesWithTag(tag='golang')),
      std.set(metricsCatalog.findVMProvisionedServices())
    ),
    description: |||
      Go's memory allocation strategy can make it look like a Go process is saturating memory when measured using RSS, when in fact
      the process is not at risk of memory saturation. For this reason, we measure Go processes using the `go_memstat_alloc_bytes`
      metric instead of RSS.
    |||,
    grafana_dashboard_uid: 'sat_go_memory',
    resourceLabels: ['fqdn'],
    query: |||
      sum by (%(aggregationLabels)s) (
        go_memstats_alloc_bytes{%(selector)s}
      )
      /
      sum by (%(aggregationLabels)s) (
        node_memory_MemTotal_bytes{%(selector)s}
      )
    |||,
    slos: {
      soft: 0.90,
      hard: 0.98,
    },
  }),
}
