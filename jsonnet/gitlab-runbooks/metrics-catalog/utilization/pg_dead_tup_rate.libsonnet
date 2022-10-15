local utilizationMetric = (import 'servicemetrics/utilization_metric.libsonnet').utilizationMetric;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
{
  pg_dead_tup_rate: utilizationMetric({
    title: 'Tracks the rate of dead tuple generation',
    unit: 'tuples',
    appliesTo: metricsCatalog.findServicesWithTag(tag='postgres'),
    description: |||
      Monitors the total rate at which dead tuples are being generated across all tables on the postgres instance.
    |||,
    resourceLabels: ['relname'],
    query: |||
      sum by (%(aggregationLabels)s) (
        deriv(pg_stat_user_tables_n_dead_tup{%(selector)s}[%(rangeDuration)s]) > 0
        and on (instance, job) (pg_replication_is_replica==0)
      )
    |||,
  }),
}
