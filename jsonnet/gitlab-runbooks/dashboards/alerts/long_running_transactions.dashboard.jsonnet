local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

local styles = [
  {
    type: 'hidden',
    pattern: 'Time',
    mappingType: 1,
  },
  {
    unit: 's',
    type: 'number',
    decimals: 0,
    pattern: 'Value',
    mappingType: 1,
  },
];

basic.dashboard(
  'Long running transactions',
  tags=['alert-target', 'type:patroni'],
)
.addPanels(
  layout.grid(
    [
      basic.table(
        title='Longest Samples Transactions observed running on the Primary',
        styles=styles,
        sort={ col: 3, desc: true },
        query=|||
          topk(10,
            max by (application, endpoint) (
              max_over_time(
                pg_stat_activity_marginalia_sampler_max_tx_age_in_seconds{
                  type="patroni",
                  environment="$environment",
                  command!="autovacuum",
                  command!~"[aA][nN][aA][lL][yY][zZ][eE]",
                }[$__range])
              and on(instance, job)
              pg_replication_is_replica == 0
            )
          )
        |||,
      ),
      basic.table(
        title='Longest Samples Transactions observed running on Secondaries',
        styles=styles,
        sort={ col: 3, desc: true },
        query=|||
          topk(10,
            max by (application, endpoint) (
              max_over_time(
                pg_stat_activity_marginalia_sampler_max_tx_age_in_seconds{
                  type="patroni",
                  environment="$environment",
                  command!="autovacuum",
                  command!~"[aA][nN][aA][lL][yY][zZ][eE]",
                }[$__range])
              and on(instance, job)
              pg_replication_is_replica == 1
            )
          )
        |||,
      ),

    ],
    cols=1,
    rowHeight=12,
  )
)
+ {
  links+: platformLinks.serviceLink('patroni') + platformLinks.triage,
}
