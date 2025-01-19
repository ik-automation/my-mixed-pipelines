local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local combined = metricsCatalog.combined;

function(
  type='patroni',
  extraTags=[],
  additionalServiceLevelIndicators={},
  serviceDependencies={},
) {
  type: type,
  tier: 'db',
  tags: [
    // postgres tag implies the service is monitored with the postgres_exporter recipe from
    // https://gitlab.com/gitlab-cookbooks/gitlab-exporters
    'postgres',

    // patroni tag implies that this cluster uses patroni replication
    //
    // Some services (postgres-archive, postgres-delayed) run postgres in a
    // replica mode only (no primary), so should not have the patroni tag
    'patroni',

    // postgres_with_primaries tags implies the service has primaries.
    // this is not the case for -archive and -delayed instances.
    'postgres_with_primaries',

    // postgres_with_replicas tag implies the service has replicas.
    // this is not the case for sentry instances
    'postgres_with_replicas',

    // gitlab_monitor_bloat implies the service is monitoring bloat with
    // a job="gitlab-monitor-database-bloat" instance of GitLab Monitor
    'gitlab_monitor_bloat',

    // pgbouncer tag implies that this server runs either pgbouncer in
    // front of a primary, or a replica
    'pgbouncer',
  ] + extraTags,
  serviceIsStageless: true,
  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },
  serviceDependencies: serviceDependencies,
  // Use recordingRuleMetrics to specify a set of metrics with known high
  // cardinality. The metrics catalog will generate recording rules with
  // the appropriate aggregations based on this set.
  // Use sparingly, and don't overuse.
  recordingRuleMetrics: [
    'gitlab_sql_duration_seconds_bucket',
    'gitlab_sql_primary_duration_seconds_bucket',
    'gitlab_sql_replica_duration_seconds_bucket',
  ],
  serviceLevelIndicators: additionalServiceLevelIndicators {
    local baseSelector = {
      type: type,
      tier: 'db',
    },

    transactions_primary: {
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        Represents all SQL transactions issued to the primary Postgres instance.
        Errors represent transaction rollbacks.
      |||,

      requestRate: combined([
        rateMetric(
          counter='pg_stat_database_xact_commit',
          selector=baseSelector,
          instanceFilter='(pg_replication_is_replica == 0)'
        ),
        rateMetric(
          counter='pg_stat_database_xact_rollback',
          selector=baseSelector,
          instanceFilter='(pg_replication_is_replica == 0)'
        ),
      ]),

      errorRate: rateMetric(
        counter='pg_stat_database_xact_rollback',
        selector=baseSelector,
        instanceFilter='(pg_replication_is_replica == 0)'
      ),

      significantLabels: ['fqdn'],

      toolingLinks: [
      ],
    },

    transactions_replica: {
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        Represents all SQL transactions issued to replica Postgres instances, in aggregate.
        Errors represent transaction rollbacks.
      |||,

      requestRate: combined([
        rateMetric(
          counter='pg_stat_database_xact_commit',
          selector=baseSelector,
          instanceFilter='(pg_replication_is_replica == 1)'
        ),
        rateMetric(
          counter='pg_stat_database_xact_rollback',
          selector=baseSelector,
          instanceFilter='(pg_replication_is_replica == 1)'
        ),
      ]),

      errorRate: rateMetric(
        counter='pg_stat_database_xact_rollback',
        selector=baseSelector,
        instanceFilter='(pg_replication_is_replica == 1)'
      ),

      significantLabels: ['fqdn'],

      toolingLinks: [
      ],
    },

    // Records the operations rate for the pgbouncer instances running on the patroni nodes
    pgbouncer: {
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        All transactions destined for the Postgres secondary instances are routed through the pgbouncer instances
        running on the patroni nodes themselves. This SLI models those transactions in aggregate.

        Error rate uses mtail metrics from pgbouncer logs.
      |||,

      // The same query, with different labels is also used on the patroni nodes pgbouncer instances
      requestRate: combined([
        rateMetric(
          counter='pgbouncer_stats_sql_transactions_pooled_total',
          selector=baseSelector
        ),
        rateMetric(
          counter='pgbouncer_stats_queries_pooled_total',
          selector=baseSelector
        ),
      ]),

      errorRate: rateMetric(
        counter='pgbouncer_pooler_errors_total',
        selector=baseSelector,
      ),

      significantLabels: ['fqdn', 'error'],

      toolingLinks: [
      ],
    },
  },
}
