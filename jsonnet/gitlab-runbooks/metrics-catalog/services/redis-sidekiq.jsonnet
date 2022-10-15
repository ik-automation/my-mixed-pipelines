local redisHelpers = import './lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-sidekiq',
    railsStorageSelector={ storage: 'queues' },
    descriptiveName='Redis Sidekiq'
  )
  {
    serviceLevelIndicators+: {
      rails_redis_client+: {
        description: |||
          Aggregation of all Redis operations issued to the Redis Sidekiq service from the Rails codebase.

          If this SLI is experiencing a degradation, it may be caused by saturation in the Redis Sidekiq instance caused by
          high traffic volumes from Sidekiq clients (Rails or other sidekiq jobs), or very large messages being delivered
          via Sidekiq.

          Reviewing Sidekiq job logs may help the investigation.
        |||,
      },
    },
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-sidekiq')
)
