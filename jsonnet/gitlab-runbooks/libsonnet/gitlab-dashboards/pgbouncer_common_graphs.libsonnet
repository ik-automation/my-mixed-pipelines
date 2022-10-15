local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

// TECHNICAL DEBT:
// Before https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/9981 was rolled out
// our metrics were off by a factor of 1 million.
// This was fixed on 30 April 2020 at 08h00 (1588233600 in unix time)
//
// If you are reading this in the year 2021 or beyond, when a change in metrics back in
// April 2020 no longer matters, please feel free to remove this.
local WAIT_TIME_CORRECTION_FACTOR = '(vector((time() < bool 1588233600) * 1000000) == 1000000 or vector(1))';

local saturationQuery(aggregationLabels, nodeSelector, poolSelector) =
  local formatConfig = {
    nodeSelector: nodeSelector,
    poolSelector: poolSelector,
    aggregationLabels: std.join(', ', aggregationLabels),
  };

  // Hack alert/PromQL explainer: we need to join from the top onto the
  // bottom joining on the `database` label.
  // In order to do this, we need to do a bit of manipulation of
  // label values to match the `database` column in the case of
  // pgbouncer_databases_pool_size{name="gitlabhq_production_sidekiq"}
  // Hence the label_replace
  |||
    sum by (%(aggregationLabels)s) (
      pgbouncer_pools_server_active_connections{%(poolSelector)s} +
      pgbouncer_pools_server_testing_connections{%(poolSelector)s} +
      pgbouncer_pools_server_used_connections{%(poolSelector)s} +
      pgbouncer_pools_server_login_connections{%(poolSelector)s}
    )
    /
    sum by (%(aggregationLabels)s) (
      label_replace(
        pgbouncer_databases_pool_size{%(nodeSelector)s},
        "database", "gitlabhq_production_sidekiq", "name", "gitlabhq_production_sidekiq"
      )
    )
  ||| % formatConfig;

{
  workloadStats(serviceType, startRow)::
    local formatConfig = {
      serviceType: serviceType,
    };

    layout.grid([
      basic.timeseries(
        title='Queries Pooled per Node',
        description='Total number of SQL queries pooled - stats_total_query_count',
        query=|||
          sum(rate(pgbouncer_stats_queries_pooled_total{type="%(serviceType)s", environment="$environment"}[$__interval])) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='ops',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      basic.timeseries(
        title='Total Time in Queries per Node',
        description='Total number of seconds spent by pgbouncer when actively connected to PostgreSQL, executing queries - stats.total_query_time',
        query=|||
          sum(rate(pgbouncer_stats_queries_duration_seconds_total{type="%(serviceType)s", environment="$environment"}[$__interval])) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='ops',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      basic.timeseries(
        title='SQL Transactions Pooled per Node',
        description='Total number of SQL transactions pooled - stats.total_xact_count',
        query=|||
          sum(rate(pgbouncer_stats_sql_transactions_pooled_total{type="%(serviceType)s", environment="$environment"}[$__interval])) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='ops',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      basic.timeseries(
        title='Time in Transaction per Server',
        description='Total number of seconds spent by pgbouncer when connected to PostgreSQL in a transaction, either idle in transaction or executing queries - stats.total_xact_time',
        query=|||
          sum(rate(pgbouncer_stats_server_in_transaction_seconds_total{type="%(serviceType)s", environment="$environment"}[$__interval])) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='s',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
    ], cols=2, rowHeight=10, startRow=startRow),
  networkStats(serviceType, startRow)::
    local formatConfig = {
      serviceType: serviceType,
    };

    layout.grid([
      basic.timeseries(
        title='Sent Bytes',
        description='Total volume in bytes of network traffic sent by pgbouncer, shown as bytes - stats.total_sent',
        query=
        |||
          sum(rate(pgbouncer_stats_sent_bytes_total{type="%(serviceType)s", environment="$environment"}[$__interval])) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='Bps',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      basic.timeseries(
        title='Received Bytes',
        description='Total volume in bytes of network traffic received by pgbouncer, shown as bytes - stats.total_received',
        query=
        |||
          sum(rate(pgbouncer_stats_received_bytes_total{type="%(serviceType)s", environment="$environment"}[$__interval])) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        format='Bps',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),

    ], cols=2, rowHeight=10, startRow=startRow),
  connectionPoolingPanels(serviceType, user, startRow)::
    local nodeSelector = 'type="%(serviceType)s", environment="$environment"' % { serviceType: serviceType };
    local poolSelector = '%(nodeSelector)s, user="%(user)s", database!="pgbouncer"' % { nodeSelector: nodeSelector, user: user };

    local formatConfig = {
      serviceType: serviceType,
      nodeSelector: nodeSelector,
      poolSelector: poolSelector,
      WAIT_TIME_CORRECTION_FACTOR: WAIT_TIME_CORRECTION_FACTOR,
    };

    layout.grid([
      basic.timeseries(
        title='Server Connection Pool Active Connections per Node',
        description='Number of active connections per node',
        query=
        |||
          sum(max_over_time(pgbouncer_pools_server_active_connections{%(poolSelector)s}[$__interval])) by (fqdn)
        ||| % formatConfig,
        legendFormat='{{ fqdn }}',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=1
      ),
      basic.saturationTimeseries(
        title='Connection Saturation per Pool',
        description='Shows connection saturation per pgbouncer pool. Lower is better.',
        yAxisLabel='Server Pool Utilization',
        query=saturationQuery(
          aggregationLabels=['database', 'env', 'environment', 'shard', 'stage', 'type'],
          nodeSelector=nodeSelector,
          poolSelector=poolSelector,
        ),
        legendFormat='{{ database }} pool',
        interval='30s',
        intervalFactor=3,
      ),
      basic.saturationTimeseries(
        title='Connection Saturation per Pool per Node',
        description='Shows connection saturation per pgbouncer pool, per pgbouncer node. Lower is better.',
        yAxisLabel='Server Pool Utilization',
        query=saturationQuery(
          aggregationLabels=['database', 'env', 'environment', 'fqdn', 'job', 'shard', 'stage', 'type'],
          nodeSelector=nodeSelector,
          poolSelector=poolSelector,
        ),
        legendFormat='{{ fqdn }} {{ database }} pool',
        interval='30s',
        intervalFactor=3,
        linewidth=1,
      ),
      basic.latencyTimeseries(
        title='Total Connection Wait Time',
        description='Total aggregated time spend waiting for a backend connection. Lower is better',
        query=|||
          sum by (database, environment, type) (rate(pgbouncer_stats_client_wait_seconds_total{%(nodeSelector)s, database!="pgbouncer"}[$__interval]) / on() group_left() %(WAIT_TIME_CORRECTION_FACTOR)s)
        ||| % formatConfig,
        legendFormat='{{ database }}',
        format='s',
        yAxisLabel='Latency',
        interval='1m',
        intervalFactor=1
      ),
      basic.latencyTimeseries(
        title='Average Wait Time per SQL Transaction',
        description='Average time spent waiting for a backend connection from the pool. Lower is better',
        query=|||
          sum by (database, environment, type, fqdn, job) (rate(pgbouncer_stats_client_wait_seconds_total{%(nodeSelector)s, database!="pgbouncer"}[$__interval]) / on() group_left() %(WAIT_TIME_CORRECTION_FACTOR)s)
          /
          sum by (database, environment, type, fqdn, job) (rate(pgbouncer_stats_sql_transactions_pooled_total{%(nodeSelector)s, database!="pgbouncer"}[$__interval]))
        ||| % formatConfig,
        legendFormat='{{ fqdn }} {{ job }} {{ database }}',
        format='s',
        yAxisLabel='Latency',
        interval='1m',
        linewidth=1,
        intervalFactor=1
      ),
      basic.queueLengthTimeseries(
        title='Waiting Client Connections per Pool (⚠️ possibly inaccurate, occassionally polled value, do not make assumptions based on this)',
        query=
        |||
          sum(avg_over_time(pgbouncer_pools_client_waiting_connections{%(poolSelector)s}[$__interval])) by (database)
        ||| % formatConfig,
        legendFormat='{{ database }} pool',
        intervalFactor=5,
      ),
      basic.queueLengthTimeseries(
        title='Active Backend Server Connections per Database',
        yAxisLabel='Active Connections',
        query=
        |||
          sum(avg_over_time(pgbouncer_pools_server_active_connections{%(poolSelector)s}[$__interval])) by (database)
        ||| % formatConfig,
        legendFormat='{{ database }} database',
        intervalFactor=5,
      ),
      basic.queueLengthTimeseries(
        title='Active Backend Server Connections per User',
        yAxisLabel='Active Connections',
        query=|||
          sum(avg_over_time(pgbouncer_pools_server_active_connections{%(poolSelector)s}[$__interval])) by (user)
        ||| % formatConfig,
        legendFormat='{{ user }}',
        intervalFactor=5,
      ),
      // This requires https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/9980
      // for pgbouncer nodes
      basic.saturationTimeseries(
        title='pgbouncer Single Threaded CPU Saturation per Node',
        description=|||
          pgbouncer is single-threaded. This graph shows maximum utilization across all cores on each host. Lower is better.

          Missing data? [https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/9980](https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/9980)
        |||,
        query=|||
          sum(
            rate(
              namedprocess_namegroup_cpu_seconds_total{groupname=~"pgbouncer.*", %(nodeSelector)s}[5m]
            )
          ) by (groupname, fqdn, type, stage, environment)
        ||| % formatConfig,
        legendFormat='{{ groupname }} {{ fqdn }}',
        interval='30s',
        intervalFactor=1,
      ),
    ], cols=2, rowHeight=10, startRow=startRow),
}
