local panels = import './panels.libsonnet';
local basic = import 'grafana/basic.libsonnet';

local durationHistogram = panels.heatmap(
  'Pending job queue duration histogram',
  |||
    sum by (le) (
      rate(job_queue_duration_seconds_bucket{environment=~"$environment", stage=~"$stage", jobs_running_for_project=~"$jobs_running_for_project"}[$__interval])
    )
  |||,
  intervalFactor=1,
);

local pendingSize =
  basic.timeseries(
    title='Pending jobs queue size',
    legendFormat='{{runner_type}}',
    format='short',
    linewidth=2,
    fill=0,
    stack=false,
    query=|||
      histogram_quantile(
        0.99,
        sum by (le, runner_type) (
          increase(gitlab_ci_queue_size_total_bucket{environment=~"$environment", stage=~"$stage"}[$__interval])
        )
      )
    |||,
  );

{
  durationHistogram:: durationHistogram,
  pendingSize:: pendingSize,
}
