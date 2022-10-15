local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_vacuum_activity_v2: resourceSaturationPoint({
    title: 'Postgres Autovacuum Activity (non-sampled)',
    severity: 's3',
    horizontallyScalable: true,  // We can add more vacuum workers, but at a resource utilization cost

    // We need to evalutate this in thanos: `pg_settings_autovacuum_max_workers` and
    // `pg_replication_is_replica` are from prometheus-db, while
    // `fluentd_pg_auto_vacuum_elapsed_seconds_total` comes from prometheus.gprd.gitlab.net
    dangerouslyThanosEvaluated: true,

    // Use patroni tag, not postgres since we only want clusters that have primaries
    // not postgres-archive, or postgres-delayed nodes for example
    appliesTo: metricsCatalog.findServicesWithTag(tag='postgres_fluent_csvlog_monitoring'),

    description: |||
      This measures the total amount of time spent each day by autovacuum workers, as a percentage of total autovacuum capacity.

      This resource uses the `auto_vacuum_elapsed_seconds` value logged by the autovacuum worker, and aggregates this across all
      autovacuum jobs. In the case that there are 10 autovacuum workers, the total capacity is 10-days worth of autovacuum time per day.

      Once the system is performing 10 days worth of autovacuum per day, the capacity will be saturated.

      This resource is primarily intended to be used for long-term capacity planning.
    |||,
    grafana_dashboard_uid: 'sat_pg_vacuum_activity_v2',
    resourceLabels: [],
    burnRatePeriod: '1d',
    query: |||
      sum by (%(aggregationLabels)s) (
        rate(fluentd_pg_auto_vacuum_elapsed_seconds_total{env="gprd"}[1d])
        and on (fqdn) (pg_replication_is_replica{%(selector)s} == 0)
      )
      /
      avg by (%(aggregationLabels)s) (
        pg_settings_autovacuum_max_workers{%(selector)s}
        and on (instance, job) (pg_replication_is_replica{%(selector)s} == 0)
      )
    |||,
    slos: {
      soft: 0.70,
      hard: 0.90,
    },
  }),

}
