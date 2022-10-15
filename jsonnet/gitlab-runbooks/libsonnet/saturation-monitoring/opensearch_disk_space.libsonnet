local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  opensearch_disk_space: resourceSaturationPoint({
    title: 'Disk Utilization Overall',
    severity: 's3',
    horizontallyScalable: true,
    appliesTo: ['logging'],
    description: |||
      Disk utilization for Opensearch
    |||,
    grafana_dashboard_uid: 'sat_opensearch_disk_space',
    resourceLabels: [],
    query: |||
      aws_es_cluster_used_space_average/(aws_es_free_storage_space_average+aws_es_cluster_used_space_average)
    |||,
    slos: {
      soft: 0.60,
      hard: 0.75,
    },
  }),
}
