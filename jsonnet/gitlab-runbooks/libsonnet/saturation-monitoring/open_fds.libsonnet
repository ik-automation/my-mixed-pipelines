local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;

{
  open_fds: resourceSaturationPoint({
    title: 'Open file descriptor utilization per instance',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findServicesExcluding(excluding=['cloud-sql', 'nat', 'waf', 'kube']),
    description: |||
      Open file descriptor utilization per instance.

      Saturation on file descriptor limits may indicate a resource-descriptor leak in the application.

      As a temporary fix, you may want to consider restarting the affected process.
    |||,
    grafana_dashboard_uid: 'sat_open_fds',
    resourceLabels: ['job', 'instance'],
    query: |||
      (
        process_open_fds{%(selector)s}
        /
        process_max_fds{%(selector)s}
      )
      or
      (
        ruby_file_descriptors{%(selector)s}
        /
        ruby_process_max_fds{%(selector)s}
      )
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
