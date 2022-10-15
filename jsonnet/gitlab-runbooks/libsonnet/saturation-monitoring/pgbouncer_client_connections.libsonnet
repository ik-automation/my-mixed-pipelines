local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local pgbouncer_client_conn(maxClientConns, name, appliesToServiceTypes) =
  local formatConfig = {
    name: name,
    nameLower: std.asciiLower(name),
  };

  resourceSaturationPoint({
    title: 'PGBouncer Client Connections per Process (%(name)s)' % formatConfig,
    severity: 's2',
    horizontallyScalable: true,  // Add more pgbouncer processes
    appliesTo: appliesToServiceTypes,
    description: |||
      Client connections per pgbouncer process for %(name)s connections.

      pgbouncer is configured to use a `max_client_conn` setting. This limits the total number of client connections per pgbouncer.

      When this limit is reached, client connections may be refused, and `max_client_conn` errors may appear in the pgbouncer logs.

      This could affect users as Rails clients are left unable to connect to the database. Another potential knock-on effect
      is that Rails clients could fail their readiness checks for extended periods during a deployment, leading to saturation of
      the older nodes.
    ||| % formatConfig,
    grafana_dashboard_uid: 'sat_pgb_client_conn_%(nameLower)s' % formatConfig,
    resourceLabels: ['fqdn'],
    burnRatePeriod: '5m',
    queryFormatConfig: {
      /** This value is configured in chef - make sure that it's kept in sync */
      maxClientConns: maxClientConns,
    },
    query: |||
      avg_over_time(pgbouncer_used_clients{%(selector)s}[%(rangeInterval)s])
      /
      %(maxClientConns)g
    |||,
    slos: {
      soft: 0.80,
      hard: 0.85,
    },
  });

{
  pgbouncer_client_conn_primary: pgbouncer_client_conn(maxClientConns=12000, name='Primary', appliesToServiceTypes=['pgbouncer', 'pgbouncer-registry', 'pgbouncer-ci']),
  pgbouncer_client_conn_replicas: pgbouncer_client_conn(maxClientConns=20000, name='Replicas', appliesToServiceTypes=['patroni', 'patroni-registry', 'patroni-ci']),
}
