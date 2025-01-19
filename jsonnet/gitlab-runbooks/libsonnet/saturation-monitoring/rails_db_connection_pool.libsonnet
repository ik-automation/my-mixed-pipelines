local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  rails_db_connection_pool: resourceSaturationPoint({
    title: 'Rails DB Connection Pool Utilization',
    severity: 's4',
    horizontallyScalable: true,  // Add more replicas for achieve greater scalability
    appliesTo: ['web', 'api', 'git', 'sidekiq', 'websockets'],
    description: |||
      Rails uses connection pools for its database connections. As each
      node may have multiple connection pools, this is by node and by
      database host.

      Read more about this resource in our [documentation](https://docs.gitlab.com/ee/development/database/client_side_connection_pool.html#client-side-connection-pool).

      If this resource is saturated, it may indicate that our connection
      pools are not correctly sized, perhaps because an unexpected
      application thread is using a database connection.
    |||,
    grafana_dashboard_uid: 'sat_rails_db_connection_pool',
    resourceLabels: ['instance', 'host', 'port'],
    burnRatePeriod: '5m',
    query: |||
      (
        avg_over_time(gitlab_database_connection_pool_busy{class="ActiveRecord::Base", %(selector)s}[%(rangeInterval)s])
        +
        avg_over_time(gitlab_database_connection_pool_dead{class="ActiveRecord::Base", %(selector)s}[%(rangeInterval)s])
      )
      /
      gitlab_database_connection_pool_size{class="ActiveRecord::Base", %(selector)s}
    |||,
    slos: {
      soft: 0.90,
      hard: 0.99,
      alertTriggerDuration: '15m',
    },
  }),
}
