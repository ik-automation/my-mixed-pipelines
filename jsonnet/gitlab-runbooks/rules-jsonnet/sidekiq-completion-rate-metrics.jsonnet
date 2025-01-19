local executionTime(window) = {
  record: 'sidekiq_jobs_execution_time:%s' % [window],
  expr: 'sum by (environment, stage, shard) (rate(sidekiq_jobs_completion_seconds_sum[%s]))' % [window],
};

local executionTimeWindows = ['1m', '10m', '1h'];

{
  'completion-rate-metrics-sidekiq.yml': std.manifestYamlDoc({
    groups: [{
      name: 'Sidekiq completion rate metrics',
      interval: '1m',
      rules: std.map(executionTime, executionTimeWindows),
    }],
  }),
}
