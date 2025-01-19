local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local pgbouncerAsyncPool(tag, role) =
  resourceSaturationPoint({
    title: 'Postgres Async (Sidekiq) %s Connection Pool Utilization per Node' % [role],
    severity: 's4',
    horizontallyScalable: role == 'replica',  // Replicas can be scaled horizontally, primary cannot
    appliesTo: metricsCatalog.findServicesWithTag(tag=tag),
    description: |||
      pgbouncer async connection pool utilization per database node, for %(role)s database connections.

      Sidekiq maintains it's own pgbouncer connection pool. When this resource is saturated,
      database operations may queue, leading to additional latency in background processing.
    ||| % { role: role },
    grafana_dashboard_uid: 'sat_pgbouncer_async_pool_' + role,
    resourceLabels: ['fqdn', 'instance'],
    burnRatePeriod: '5m',
    query: |||
      (
        avg_over_time(pgbouncer_pools_server_active_connections{user="gitlab", database="gitlabhq_production_sidekiq", %(selector)s}[%(rangeInterval)s]) +
        avg_over_time(pgbouncer_pools_server_testing_connections{user="gitlab", database="gitlabhq_production_sidekiq", %(selector)s}[%(rangeInterval)s]) +
        avg_over_time(pgbouncer_pools_server_used_connections{user="gitlab", database="gitlabhq_production_sidekiq", %(selector)s}[%(rangeInterval)s]) +
        avg_over_time(pgbouncer_pools_server_login_connections{user="gitlab", database="gitlabhq_production_sidekiq", %(selector)s}[%(rangeInterval)s])
      )
      / on(%(aggregationLabels)s) group_left()
      sum by (%(aggregationLabels)s) (
        avg_over_time(pgbouncer_databases_pool_size{name="gitlabhq_production_sidekiq", %(selector)s}[%(rangeInterval)s])
      )
    |||,
    slos: {
      soft: 0.90,
      hard: 0.95,
      alertTriggerDuration: '10m',
    },
  });

local pgbouncerSyncPool(tag, role) =
  resourceSaturationPoint({
    title: 'Postgres Sync (Web/API/Git) %s Connection Pool Utilization per Node' % [role],
    severity: 's3',
    horizontallyScalable: role == 'replica',  // Replicas can be scaled horizontally, primary cannot
    appliesTo: metricsCatalog.findServicesWithTag(tag=tag),
    description: |||
      pgbouncer sync connection pool Saturation per database node, for %(role)s database connections.

      Web/api/git applications use a separate connection pool to sidekiq.

      When this resource is saturated, web/api database operations may queue, leading to rails worker
      saturation and 503 errors in the web.
    ||| % { role: role },
    grafana_dashboard_uid: 'sat_pgb_sync_pool_' + role,
    resourceLabels: ['fqdn', 'instance'],
    burnRatePeriod: '5m',
    query: |||
      (
        avg_over_time(pgbouncer_pools_server_active_connections{user=~"gitlab|gitlab-registry", database=~"gitlabhq_registry|gitlabhq_production", %(selector)s}[%(rangeInterval)s]) +
        avg_over_time(pgbouncer_pools_server_testing_connections{user=~"gitlab|gitlab-registry", database=~"gitlabhq_registry|gitlabhq_production", %(selector)s}[%(rangeInterval)s]) +
        avg_over_time(pgbouncer_pools_server_used_connections{user=~"gitlab|gitlab-registry", database=~"gitlabhq_registry|gitlabhq_production", %(selector)s}[%(rangeInterval)s]) +
        avg_over_time(pgbouncer_pools_server_login_connections{user=~"gitlab|gitlab-registry", database=~"gitlabhq_registry|gitlabhq_production", %(selector)s}[%(rangeInterval)s])
      )
      / on(%(aggregationLabels)s) group_left()
      sum by (%(aggregationLabels)s) (
        avg_over_time(pgbouncer_databases_pool_size{name=~"gitlabhq_registry|gitlabhq_production", %(selector)s}[%(rangeInterval)s])
      )
    |||,
    slos: {
      soft: 0.85,
      hard: 0.95,
      alertTriggerDuration: '10m',
    },
  });


{
  pgbouncer_async_primary_pool: pgbouncerAsyncPool('pgbouncer_async_primary', 'primary'),
  pgbouncer_async_replica_pool: pgbouncerAsyncPool('pgbouncer_async_replica', 'replica'),
  pgbouncer_sync_primary_pool: pgbouncerSyncPool('pgbouncer_primary', 'primary'),
  pgbouncer_sync_replica_pool: pgbouncerSyncPool('patroni', 'replica'),
}
