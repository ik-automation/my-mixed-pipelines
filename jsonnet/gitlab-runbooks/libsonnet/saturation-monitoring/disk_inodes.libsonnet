local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  disk_inodes: resourceSaturationPoint({
    title: 'Disk inode Utilization per Device per Node',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findVMProvisionedServices(first='gitaly'),
    description: |||
      Disk inode utilization per device per node.

      If this is too high, its possible that a directory is filling up with
      files. Consider logging in an checking temp directories for large numbers
      of files
    |||,
    grafana_dashboard_uid: 'sat_disk_inodes',
    resourceLabels: ['fqdn', 'device'],
    query: |||
      1 - (
        node_filesystem_files_free{fstype=~"(ext.|xfs)", %(selector)s}
        /
        node_filesystem_files{fstype=~"(ext.|xfs)", %(selector)s}
      )
    |||,
    slos: {
      soft: 0.75,
      hard: 0.80,
      alertTriggerDuration: '15m',
    },
  }),
}
