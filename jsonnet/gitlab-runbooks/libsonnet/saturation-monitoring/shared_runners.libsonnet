local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  shared_runners: resourceSaturationPoint({
    title: 'Shared Runner utilization',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['ci-runners'],
    description: |||
      Shared runner utilization per instance.

      Each runner manager has a maximum number of runners that it can coordinate at any single moment.

      When this metric is saturated, new CI jobs will queue. When this occurs we should consider adding more runner managers,
      or scaling the runner managers vertically and increasing their maximum runner capacity.
    |||,
    grafana_dashboard_uid: 'sat_shared_runners',
    resourceLabels: ['instance'],
    staticLabels: {
      type: 'ci-runners',
      tier: 'runners',
      stage: 'main',
    },
    query: |||
      sum without(executor_stage, exported_stage, state, runner) (
        max_over_time(gitlab_runner_jobs{job="runners-manager",shard="shared"}[%(rangeInterval)s])
      )
      /
      gitlab_runner_concurrent{job="runners-manager",shard="shared"} > 0
    |||,
    slos: {
      soft: 0.90,
      hard: 0.95,
    },
  }),
}
