local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_btree_bloat: resourceSaturationPoint({
    title: 'Postgres btree bloat',
    severity: 's3',
    horizontallyScalable: false,
    appliesTo: metricsCatalog.findServicesWithTag(tag='gitlab_monitor_bloat'),
    description: |||
      This measures the total bloat in Postgres Btree indexes, as a percentage of total index size.

      The larger this measure, the more pages will unnecessarily be retrieved during index scans.
    |||,
    grafana_dashboard_uid: 'sat_pg_btree_bloat',
    resourceLabels: ['fqdn'],
    burnRatePeriod: '5m',

    // Note that we only measure bloat once every 60 minutes but the prometheus series will expire after
    // 5 minutes. For this reason, we use `avg_over_time(...[58m])`. Once we upgrade to
    // at least 2.26 of Prometheus, we can switch this to `last_over_time(...[1h])` function instead.
    query: |||
      sum by (%(aggregationLabels)s) (avg_over_time(gitlab_database_bloat_btree_bloat_size{job="gitlab-monitor-database-bloat", %(selector)s}[58m]))
      /
      sum by (%(aggregationLabels)s) (avg_over_time(gitlab_database_bloat_btree_real_size{job="gitlab-monitor-database-bloat", %(selector)s}[58m]))
    |||,
    slos: {
      soft: 0.30,
      hard: 0.40,
    },
  }),
}
