local redisHelpers = import './lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis',
    railsStorageSelector={ storage: 'shared_state' },
    descriptiveName='Persistent Redis',
  )
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis')
)
