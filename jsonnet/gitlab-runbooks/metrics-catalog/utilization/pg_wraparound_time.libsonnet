local utilizationMetric = (import 'servicemetrics/utilization_metric.libsonnet').utilizationMetric;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_wraparound_time: utilizationMetric({
    title: 'Postgres XID Wraparound Time',
    unit: 'seconds',
    appliesTo: metricsCatalog.findServicesWithTag(tag='postgres'),
    description: |||
      Given the current transaction (write) rate (over an averaged 24h period) on the primary database instance, measures the
      time it will take for a full XID wraparound cycle to occur. The more transactions/higher the transaction rate, the
      faster the wraparound time, and the less time available to perform vacuums.
    |||,
    rangeDuration: '1d',
    resourceLabels: [],
    queryFormatConfig: {
      txWraparoundExpression: '(2^31 - 10^6)',
    },
    query: |||
      %(txWraparoundExpression)s
      /
      (
        avg by (%(aggregationLabels)s) (deriv(pg_txid_current{%(selector)s}[%(rangeDuration)s]) > 0)
      )
    |||,
  }),
}
