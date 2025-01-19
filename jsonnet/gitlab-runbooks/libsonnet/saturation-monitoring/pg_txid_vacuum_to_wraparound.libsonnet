local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_txid_vacuum_to_wraparound: resourceSaturationPoint({
    title: 'Total autovacuum time to TXID wraparound horizon',
    severity: 's1',
    horizontallyScalable: false,
    appliesTo: metricsCatalog.findServicesWithTag(tag='postgres_fluent_csvlog_monitoring'),
    description: |||
      This saturation metric measures the capacity of the Postgres primary instance to perform autovacuum operations
      on all tables.

      It measures the total time spent in vacuum operations, over a 24 hour period divided the maximum number of autovacuum processes
      to give the total vacuum activity, in seconds. This value is divided by the TXID wraparound horizon for the database to
      produce a percentage.

      This value will approach 100% as two situation occur:

      1. The amount of time spent performing autovacuum operations goes up, due to high dead-tuple generation in the database.
      1. The write transaction volume goes up, decreasing the wraparound horizon.

      If the total time spent vacuuming approached the wraparound time horizon, this would mean that the database would be at risk
      of being unable to complete a vacuum of all tables within the wraparound time horizon. This would put the database at risk of XID
      wraparound and immediate shutdown.
    |||,
    grafana_dashboard_uid: 'sat_pg_txid_vac_wraparound',
    resourceLabels: [],
    queryFormatConfig: {
      txWraparoundExpression: '(2^31 - 10^6)',  // Keep this as a string as we use it as an expression
    },
    query: |||
      (
        sum by (%(aggregationLabels)s) (
          increase(fluentd_pg_auto_vacuum_elapsed_seconds_total{%(selector)s}[1d])
        )
        / on(environment, type) group_left() (
          pg_settings_autovacuum_max_workers and
          on (instance) pg_replication_is_replica == 0
        )
      )
      /
      (
        %(txWraparoundExpression)s
        /
        (
          avg by (%(aggregationLabels)s) (
            deriv(pg_txid_current{%(selector)s}[1d]) and
            on (instance) pg_replication_is_replica == 0
          )
        )
      )
    |||,
    slos: {
      soft: 0.20,
      hard: 0.33,
    },
  }),
}
