local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  shared_runners_gitlab: resourceSaturationPoint({
    title: 'Shared Runner GitLab Utilization',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['ci-runners'],
    description: |||
      Shared runners utilization per instance.

      Each runner manager has a maximum number of runners that it can coordinate at any single moment.

      When this metric is saturated, new CI jobs will queue. When this occurs we should consider adding more runner managers,
      or scaling the runner managers vertically and increasing their maximum runner capacity.
    |||,
    grafana_dashboard_uid: 'sat_shared_runners_gitlab',
    resourceLabels: ['instance'],
    // TODO: remove relabelling silliness once
    // https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/8456
    // is completed
    query: |||
      sum without(executor_stage, exported_stage, state) (
        max_over_time(gitlab_runner_jobs{job="runners-manager",shard="shared-gitlab-org"}[%(rangeInterval)s])
      )
      /
      gitlab_runner_limit{job="runners-manager",shard="shared-gitlab-org"} > 0
    |||,
    slos: {
      soft: 0.90,
      hard: 0.95,
    },
  }),
}
