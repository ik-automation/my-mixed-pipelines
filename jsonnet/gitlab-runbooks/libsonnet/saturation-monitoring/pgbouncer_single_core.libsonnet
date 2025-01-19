local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  pgbouncer_single_core: resourceSaturationPoint({
    title: 'PGBouncer Single Core per Node',
    severity: 's2',
    horizontallyScalable: true,  // Add more pgbouncer processes (for patroni) or nodes (for pgbouncer)
    appliesTo: ['pgbouncer', 'patroni'],
    description: |||
      PGBouncer single core CPU utilization per node.

      PGBouncer is a single threaded application. Under high volumes this resource may become saturated,
      and additional pgbouncer nodes may need to be provisioned.
    |||,
    grafana_dashboard_uid: 'sat_pgbouncer_single_core',
    resourceLabels: ['fqdn', 'groupname'],
    burnRatePeriod: '5m',
    query: |||
      sum without(cpu, mode) (
        rate(
          namedprocess_namegroup_cpu_seconds_total{groupname=~"pgbouncer.*", %(selector)s}[%(rangeInterval)s]
        )
      )
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
