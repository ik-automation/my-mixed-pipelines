local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  workhorse_image_scaling: resourceSaturationPoint({
    title: 'Workhorse Image Scaler Exhaustion per Node',
    severity: 's4',
    horizontallyScalable: true,  // Add more replicas for achieve greater scalability
    appliesTo: ['web'],
    description: |||
      Workhorse can scale images on-the-fly as requested. Since the actual work will be
      performed by dedicated processes, we currently define a hard cap for how many
      such requests are allowed to be in the system concurrently.

      If this resource is fully saturated, Workhorse will start ignoring image scaling
      requests and serve the original image instead, which will ensure continued operation,
      but comes at the cost of additional client latency and GCS egress traffic.
    |||,
    grafana_dashboard_uid: 'sat_wh_image_scaling',
    resourceLabels: ['fqdn'],
    burnRatePeriod: '5m',
    query: |||
      avg_over_time(gitlab_workhorse_image_resize_processes{%(selector)s}[%(rangeInterval)s])
        /
      gitlab_workhorse_image_resize_max_processes{%(selector)s}
    |||,
    slos: {
      soft: 0.90,
      hard: 0.95,
      alertTriggerDuration: '15m',
    },
  }),
}
