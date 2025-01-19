local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local combined = metricsCatalog.combined;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

function(
  type,
  extraTags=[],
)
  {
    type: type,
    tier: 'db',

    tags: [
      // pgbouncer_primary indicates that the service runs pgbouncer in front of a primary
      'pgbouncer_primary',

      // pgbouncer tag implies that this server runs either pgbouncer in
      // front of a primary, or a replica
      'pgbouncer',
    ] + extraTags,

    // pgbouncer doesn't have a `cny` stage
    serviceIsStageless: true,

    serviceLevelIndicators: {
      local baseSelector = {
        type: type,
        tier: 'db',
      },
      service: {
        userImpacting: true,
        featureCategory: 'not_owned',
        description: |||
          All transactions destined for the Postgres primary instance are routed through the pgbouncer service.
          This SLI models those transactions in aggregate.

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
