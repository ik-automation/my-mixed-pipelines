local utilizationMetric = (import 'servicemetrics/utilization_metric.libsonnet').utilizationMetric;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_table_size: utilizationMetric({
    title: 'Tracks the biggest tables in Postgres',
    unit: 'bytes',
    appliesTo: metricsCatalog.findServicesWithTag(tag='postgres'),
    description: |||
      Monitors the size of the biggest tables in Postgres
    |||,
    resourceLabels: ['relname'],
    topk: 10,
    query: |||
      avg by (%(aggregationLabels)s) (
        avg_over_time(pg_total_relation_size_bytes{%(selector)s}[%(rangeDuration)s])
        and on (job, instance) (
          pg_replication_is_replica{%(selector)s} == 0
        )
      )
    |||,
  }),
}
