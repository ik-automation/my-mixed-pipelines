local redisHelpers = import './lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-sessions',
    railsStorageSelector={ storage: 'sessions' },
    descriptiveName='Redis Sessions',
  )
  {
    serviceLevelIndicators+: {
      rails_redis_client+: {
        description: |||
          Aggregation of all Redis Sessions operations issued from the Rails codebase.

          If this SLI is experiencing a degradation then logins and general session activity will be delayed, likely causing widepsread service degradation across the entire system
        |||,
      },
    },
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-sessions')
)
