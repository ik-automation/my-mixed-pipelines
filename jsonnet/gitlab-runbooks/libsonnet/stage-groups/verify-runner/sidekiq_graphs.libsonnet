local basic = import 'grafana/basic.libsonnet';

local pipelineQueues =
  basic.timeseries(
    'Sidekiq CI and Runner in flight jobs',
    description=|||
      This graph shows the rate of the Sidekiq jobs (related to CI/CD and Runner) that have been enqueued but not yet
      finished. A steep rise here means a backlog of jobs is being built and this means that Sidekiq is most probably
      having trouble keeping up.
    |||,
    legendFormat='{{worker}}',
    format='short',
    query=|||
      (
        sum by (worker) (
          sidekiq_jobs_inflight:irate1m{environment="$environment", stage="$stage", feature_category=~"(continuous_integration|runner)"}
        )
      )
    |||,
  );

{
  pipelineQueues:: pipelineQueues,
}
