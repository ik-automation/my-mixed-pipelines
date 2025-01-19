local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;
local sidekiqHelpers = import './services/lib/sidekiq-helpers.libsonnet';

{
  sidekiq_shard_workers: resourceSaturationPoint({
    title: 'Sidekiq Worker Utilization per shard',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['sidekiq'],
    description: |||
      Sidekiq worker utilization per shard.

      This metric represents the percentage of available threads*workers that are actively processing jobs.

      When this metric is saturated, new Sidekiq jobs will queue. Depending on whether or not the jobs are latency sensitive,
      this could impact user experience.
    |||,
    grafana_dashboard_uid: 'sat_sidekiq_shard_workers',
    resourceLabels: ['shard'],
    resourceAutoscalingRule: true,
    burnRatePeriod: '5m',
    query: |||
      sum by (%(aggregationLabels)s) (
        avg_over_time(sidekiq_running_jobs{shard!~"%(throttledSidekiqShardsRegexp)s", %(selector)s}[%(rangeInterval)s])
      )
      /
      sum by (%(aggregationLabels)s) (
        avg_over_time(sidekiq_concurrency{shard!~"%(throttledSidekiqShardsRegexp)s", %(selector)s}[%(rangeInterval)s])
      )
    |||,
    queryFormatConfig: {
      throttledSidekiqShardsRegexp: std.join('|', sidekiqHelpers.shards.listFiltered(function(shard) shard.urgency == 'throttled')),
    },
    slos: {
      soft: 0.85,
      hard: 0.90,
      alertTriggerDuration: '10m',
    },
  }),
}
