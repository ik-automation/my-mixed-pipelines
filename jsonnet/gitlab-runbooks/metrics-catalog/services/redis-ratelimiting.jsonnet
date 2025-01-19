local redisHelpers = import './lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-ratelimiting',
    railsStorageSelector={ storage: 'rate_limiting' },
    descriptiveName='Redis Rate-Limiting'
  )
  {
    monitoringThresholds+: {
      apdexScore: 0.9995,
    },
  }
  // TODO: ensure that kubeConfig is setup with kube nodepool selectors
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-ratelimiting')
)
