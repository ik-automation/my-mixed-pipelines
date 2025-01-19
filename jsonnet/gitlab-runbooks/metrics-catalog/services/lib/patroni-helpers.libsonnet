local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local combined = metricsCatalog.combined;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

{
  gitlabcomObservabilityToolingForPatroni(type):: {
    serviceLevelIndicators+: {
      transactions_primary+: {
        toolingLinks+: [
          toolingLinks.kibana(title='Postgres', index='postgres', type=type, tag='postgres.postgres_csv'),
        ],
      },

      transactions_replica+: {
        toolingLinks+: [
          toolingLinks.kibana(title='Postgres', index='postgres', type=type, tag='postgres.postgres_csv'),
        ],
      },

      pgbouncer+: {
        toolingLinks+: [
          toolingLinks.kibana(title='pgbouncer', index='postgres_pgbouncer', type=type, tag='postgres.pgbouncer'),
        ],
      },
    },
  },
}
