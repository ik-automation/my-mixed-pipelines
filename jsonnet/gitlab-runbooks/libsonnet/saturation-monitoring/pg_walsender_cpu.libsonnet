local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_walsender_cpu: resourceSaturationPoint({
    title: 'Walsender CPU Saturation',
    severity: 's3',
    horizontallyScalable: false,

    // Unfortunately this saturation metric relies on node_exporter data from prometheus-default shards,
    // and postgres_exporter data from the prometheus-db shards, so we need to evaluate it in Thanos
    // which is not ideal.
    dangerouslyThanosEvaluated: true,
    appliesTo: metricsCatalog.findServicesWithTag(tag='patroni'),
    description: |||
      This saturation metric measures the total amount of time that the primary postgres instance is spending sending WAL segments
      to replicas. It is expressed as a percentage of all CPU available on the primary postgres instance.

      The more replicas connected, the higher this metric will be.

      Since it's expressed as a percentage of all CPU, this should always remain low, since the CPU primarily needs to be available for
      handling SQL statements.
    |||,
    grafana_dashboard_uid: 'sat_pg_walsender_cpu',
    resourceLabels: [],
    burnRatePeriod: '5m',
    query: |||
      sum by (%(aggregationLabels)s) (
        sum by(%(aggregationLabels)s, fqdn) (
          rate(namedprocess_namegroup_cpu_seconds_total{%(selector)s, groupname=~"pg.worker.walsender|pg.worker.walwriter|wal-g"}[%(rangeInterval)s])
          and on (fqdn) (pg_replication_is_replica{%(selector)s} == 0)
        )
        /
        count by (%(aggregationLabels)s, fqdn) (
          node_cpu_seconds_total{%(selector)s, mode="idle"} and on(fqdn) (pg_replication_is_replica{%(selector)s} == 0)
        )
      )
    |||,
    slos: {
      soft: 0.10,
      hard: 0.20,
    },
  }),
}
