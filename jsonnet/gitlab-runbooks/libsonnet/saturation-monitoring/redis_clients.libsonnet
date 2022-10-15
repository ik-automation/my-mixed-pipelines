local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  redis_clients: resourceSaturationPoint({
    title: 'Redis Client Utilization per Node',
    severity: 's3',
    horizontallyScalable: false,
    appliesTo: metricsCatalog.findServicesWithTag(tag='redis'),
    description: |||
      Redis client utilization per node.

      A redis server has a maximum number of clients that can connect. When this resource is saturated,
      new clients may fail to connect.

      More details at https://redis.io/topics/clients#maximum-number-of-clients
    |||,
    grafana_dashboard_uid: 'sat_redis_clients',
    resourceLabels: ['fqdn'],
    query: |||
      max_over_time(redis_connected_clients{%(selector)s}[%(rangeInterval)s])
      /
      redis_config_maxclients{%(selector)s}
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
