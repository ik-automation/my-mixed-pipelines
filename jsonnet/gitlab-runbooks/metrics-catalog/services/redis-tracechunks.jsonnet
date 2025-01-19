local redisHelpers = import './lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-tracechunks',
    railsStorageSelector={ storage: 'trace_chunks' },
    descriptiveName='Redis Tracechunks',
    featureCategory='continuous_integration',
  )
  {
    serviceLevelIndicators+: {
      rails_redis_client+: {
        description: |||
          Aggregation of all Redis Tracechunks operations issued from the Rails codebase.

          If this SLI is experiencing a degradation then the output of CI jobs may be delayed in becoming visible or in severe situations the data may be lost.
        |||,
      },
    },
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-tracechunks')
)
