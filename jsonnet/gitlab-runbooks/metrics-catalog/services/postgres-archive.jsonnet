local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local combined = metricsCatalog.combined;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';


local selector = { type: 'postgres-archive', tier: 'db' };

metricsCatalog.serviceDefinition({
  type: 'postgres-archive',
  tier: 'db',

  serviceDependencies: {
    patroni: true,
  },

  tags: [
    // postgres tag implies the service is monitored with the postgres_exporter recipe from
    // https://gitlab.com/gitlab-cookbooks/gitlab-exporters
    'postgres',

    // postgres_with_replicas tag implies the service has replicas.
    // this is not the case for sentry instances
    'postgres_with_replicas',

    // gitlab_monitor_bloat implies the service is monitoring bloat with
    // a job="gitlab-monitor-database-bloat" instance of GitLab Monitor
    'gitlab_monitor_bloat',
  ],

  serviceLevelIndicators: {
    transactions: {
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        Represents all SQL transactions issued to the primary Postgres instance.
        Errors represent transaction rollbacks.
      |||,

      requestRate: combined([
        rateMetric(
          counter='pg_stat_database_xact_commit',
          selector=selector,
        ),
        rateMetric(
          counter='pg_stat_database_xact_rollback',
          selector=selector,
        ),
      ]),

      errorRate: rateMetric(
        counter='pg_stat_database_xact_rollback',
        selector=selector,
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Postgres Archive', index='postgres_archive', includeMatchersForPrometheusSelector=false),
      ],
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Developer guides exist in developer documentation': 'postgres-archive is an infrastructure component, developers do not interact with it',
  }),
})
