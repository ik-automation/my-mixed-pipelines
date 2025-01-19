local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_xid_wraparound: resourceSaturationPoint({
    title: 'Transaction ID Wraparound',
    severity: 's1',
    horizontallyScalable: false,

    // Use patroni tag, not postgres since we only want clusters that have primaries
    // not postgres-archive, or postgres-delayed nodes for example
    appliesTo: metricsCatalog.findServicesWithTag(tag='postgres_with_primaries'),

    alertRunbook: 'docs/patroni/pg_xid_wraparound_alert.md',
    description: |||
      Risk of DB shutdown in the near future, approaching transaction ID wraparound.

      This is a critical situation.

      This saturation metric measures how close the database is to Transaction ID wraparound.

      When wraparound occurs, the database will automatically shutdown to prevent data loss, causing a full outage.

      Recovery would require entering single-user mode to run vacuum, taking the site down for a potentially multi-hour maintenance session.

      To avoid reaching the db shutdown threshold, consider the following short-term actions:

      1. Escalate to the SRE Datastores team, and then,

      2. Find and terminate any very old transactions. The runbook for this alert has details.  Do this first.  It is the most critical step and may be all that is necessary to let autovacuum do its job.

      3. Run a manual vacuum on tables with oldest relfrozenxid.  Manual vacuums run faster than autovacuum.

      4. Add autovacuum workers or reduce autovacuum cost delay, if autovacuum is chronically unable to keep up with the transaction rate.

      Long running transaction dashboard: https://dashboards.gitlab.net/d/alerts-long_running_transactions/alerts-long-running-transactions?orgId=1
    |||,
    grafana_dashboard_uid: 'sat_pg_xid_wraparound',
    resourceLabels: ['datname'],
    queryFormatConfig: {
      wraparoundValue: '2^31 - 10^6',  // Keep this as a string
    },
    query: |||
      (
        max without (series) (
          label_replace(pg_database_wraparound_age_datfrozenxid{%(selector)s}, "series", "datfrozenxid", "", "")
          or
          label_replace(pg_database_wraparound_age_datminmxid{%(selector)s}, "series", "datminmxid", "", "")
        )
        and on (instance, job) (pg_replication_is_replica{%(selector)s} == 0)
      )
      /
      (%(wraparoundValue)s)
    |||,
    slos: {
      soft: 0.60,
      hard: 0.70,
    },
  }),
}
