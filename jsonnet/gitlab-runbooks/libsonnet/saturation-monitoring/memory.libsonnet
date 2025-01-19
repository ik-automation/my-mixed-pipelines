local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';

local memoryDefinition = {
  title: 'Memory Utilization per Node',
  severity: 's4',
  horizontallyScalable: true,
  description: |||
    Memory utilization per device per node.
  |||,
  grafana_dashboard_uid: 'sat_memory',
  resourceLabels: [labelTaxonomy.getLabelFor(labelTaxonomy.labels.node)],
  // Filter out fqdn nodes as these could be CI runners
  query: |||
    instance:node_memory_utilization:ratio{%(selector)s} or instance:node_memory_utilisation:ratio{%(selector)s}
  |||,
  slos: {
    soft: 0.90,
    hard: 0.98,
  },
};

{
  memory: resourceSaturationPoint(memoryDefinition {
    // Exclude redis-cache because it always runs at its maxmemory
    // level, and the oscillations mean the forecasts aren't useful
    appliesTo: std.filter(function(s) s != 'redis-cache', metricsCatalog.findVMProvisionedServices(first='gitaly')),
  }),
  memory_redis_cache: resourceSaturationPoint(memoryDefinition {
    // Give redis-cache its own non-capacity-planning saturation point.
    appliesTo: ['redis-cache'],
    capacityPlanningStrategy: 'exclude',
    grafana_dashboard_uid: 'sat_memory_redis_cache',
    description: |||
      %s

      redis-cache has a separate saturation point for this to exclude it from capacity planning calculations.
    ||| % memoryDefinition.description,
  }),
}
