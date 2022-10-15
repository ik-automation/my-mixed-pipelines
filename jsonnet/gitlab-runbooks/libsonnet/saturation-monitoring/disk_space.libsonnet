local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';

{
  disk_space: resourceSaturationPoint({
    title: 'Disk Space Utilization per Device per Node',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findVMProvisionedServices(first='gitaly'),
    description: |||
      Disk space utilization per device per node.
    |||,
    grafana_dashboard_uid: 'sat_disk_space',
    resourceLabels: [labelTaxonomy.getLabelFor(labelTaxonomy.labels.node), 'device'],
    // We filter on `fqdn!=""` to filter out any nameless workers. This is done mostly for the ci-runner fleet
    query: |||
      (
        1 - node_filesystem_avail_bytes{fstype=~"ext.|xfs", %(selector)s} / node_filesystem_size_bytes{fstype=~"ext.|xfs", %(selector)s}
      )
    |||,
    slos: {
      soft: 0.85,
      hard: 0.90,
      alertTriggerDuration: '15m',
    },
  }),
}
