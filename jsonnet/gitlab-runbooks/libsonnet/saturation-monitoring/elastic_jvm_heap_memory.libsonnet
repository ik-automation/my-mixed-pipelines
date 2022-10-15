local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  elastic_jvm_heap_memory: resourceSaturationPoint({
    title: 'JVM Heap Utilization per Node',
    severity: 's4',
    horizontallyScalable: true,
    capacityPlanningStrategy: 'exclude',
    appliesTo: ['logging', 'search'],
    description: |||
      JVM heap memory utilization per node.
    |||,
    grafana_dashboard_uid: 'sat_elastic_jvm_heap_memory',
    resourceLabels: ['name'],
    query: |||
      elasticsearch_jvm_memory_used_bytes{area="heap", %(selector)s}
      /
      elasticsearch_jvm_memory_max_bytes{area="heap", %(selector)s}
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
