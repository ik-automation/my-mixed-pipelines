local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local registryHelpers = import './lib/registry-helpers.libsonnet';
local registryBaseSelector = registryHelpers.registryBaseSelector;
local redisArchetype = import 'service-archetypes/redis-archetype.libsonnet';
local redisHelpers = import './lib/redis-helpers.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-registry-cache',
    descriptiveName='Redis Rate-Limiting'
  )
  {
    monitoringThresholds+: {
      apdexScore: 0.9995,
    },
    serviceLevelIndicators+: {
      registry_redis_client: {
        userImpacting: true,
        description: |||
          Aggregation of all container registry Redis operations.
        |||,

        apdex: histogramApdex(
          histogram='registry_redis_single_commands_bucket',
          selector=registryBaseSelector,
          satisfiedThreshold=0.25,
          toleratedThreshold=0.5
        ),

        requestRate: rateMetric(
          counter='registry_redis_single_commands_count',
          selector=registryBaseSelector
        ),

        errorRate: rateMetric(
          counter='registry_redis_single_errors_count',
          selector=registryBaseSelector
        ),

        significantLabels: ['instance', 'command'],
      },
    },
  }
  // TODO: ensure that kubeConfig is setup with kube nodepool selectors
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-registry-cache')
)
