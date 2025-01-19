local redisArchetype = import 'service-archetypes/redis-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;

function(
  type,
  railsStorageSelector,
  descriptiveName,
  featureCategory='not_owned',
)
  redisArchetype(type, descriptiveName, featureCategory)
  {
    serviceLevelIndicators+: {
      rails_redis_client: {
        userImpacting: true,
        featureCategory: featureCategory,
        description: |||
          Aggregation of all %(descriptiveName)s operations issued from the Rails codebase.
        ||| % { descriptiveName: descriptiveName },
        significantLabels: ['type'],

        apdex: histogramApdex(
          histogram='gitlab_redis_client_requests_duration_seconds_bucket',
          selector=railsStorageSelector,
          satisfiedThreshold=0.5,
          toleratedThreshold=0.75,
        ),

        requestRate: rateMetric(
          counter='gitlab_redis_client_requests_total',
          selector=railsStorageSelector,
        ),

        errorRate: rateMetric(
          counter='gitlab_redis_client_exceptions_total',
          selector=railsStorageSelector,
        ),
      },
    },
  }
