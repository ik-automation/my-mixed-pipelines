local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';

{
  single_node_cpu: resourceSaturationPoint({
    title: 'Average CPU Utilization per Node',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findVMProvisionedServices(first='gitaly'),
    description: |||
      Average CPU utilization per Node.

      If average CPU is saturated, it may indicate that a fleet is in need to horizontal or vertical scaling. It may also indicate
      imbalances in load in a fleet.
    |||,
    grafana_dashboard_uid: 'sat_single_node_cpu',
    resourceLabels: labelTaxonomy.labelTaxonomy(labelTaxonomy.labels.node),
    burnRatePeriod: '5m',
    query: |||
      avg without(cpu, mode) (1 - rate(node_cpu_seconds_total{mode="idle", %(selector)s}[%(rangeInterval)s]))
    |||,
    slos: {
      soft: 0.90,
      hard: 0.95,
      alertTriggerDuration: '10m',
    },
  }),
}
