local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  private_runners: resourceSaturationPoint({
    title: 'Private Runners utilization',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['ci-runners'],
    description: |||
      Private runners utilization per instance.

      Each runner manager has a maximum number of runners that it can coordinate at any single moment.

      When this metric is saturated, new CI jobs will queue. When this occurs we should consider adding more runner managers,
      or scaling the runner managers vertically and increasing their maximum runner capacity.
    |||,
    grafana_dashboard_uid: 'sat_private_runners',
    resourceLabels: ['instance'],
    staticLabels: {
      type: 'ci-runners',
      tier: 'runners',
      stage: 'main',
    },
    query: |||
      sum without(executor_stage, exported_stage, state) (
        max_over_time(gitlab_runner_jobs{job="runners-manager",shard="private"}[%(rangeInterval)s])
      )
      /
      gitlab_runner_limit{job="runners-manager",shard="private"} > 0
    |||,
    slos: {
      soft: 0.85,
      hard: 0.95,
    },
  }),
}
