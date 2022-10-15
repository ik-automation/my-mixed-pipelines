local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local alerts = import 'alerts/alerts.libsonnet';
local aggregationSetTransformer = import 'servicemetrics/aggregation-set-transformer.libsonnet';
local serviceLevelAlerts = import 'slo-alerts/service-level-alerts.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';

/* TODO: having some sort of criticality label on sidekiq jobs would allow us to
   define different criticality labels for each worker. For now we need to use
   a fixed value, which also needs to be a lower-common-denominator */
local fixedApdexThreshold = 0.90;
local fixedErrorRateThreshold = 0.90;

local minimumSamplesForMonitoringApdex = 1200; /* We don't really care if something runs only very infrequently, but is slow */

// NB: https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/1324 discusses increases the operation rate
// for some daily sidekiq jobs, to improve the sample rates.
local minimumSamplesForMonitoringErrors = 3; /* Low-frequency jobs may be doing very important things */


local sidekiqThanosAlerts() =
  [
    /**
       * Throttled queues don’t alert on queues SLOs.
       * This means that we will allow jobs to queue up for any amount of time without alerting.
       * One downside is that due to a misconfiguration, we may not be not listening to a throttled
       * queue.
       *
       * Since we don't have an SLO for this we can't use SLOs alert to tell us about this problem.
       * This alert is a safety mechanism. We don’t monitor queueing times, but if there were any
       * queuing jobs
       */
    {
      alert: 'sidekiq_throttled_jobs_enqueued_without_dequeuing',
      expr: |||
        (
          sum by (environment, queue, feature_category, worker) (
            gitlab_background_jobs:queue:ops:rate_1h{urgency="throttled"}
          ) > 0
        )
        unless
        (
          sum by (environment, queue, feature_category, worker) (
            gitlab_background_jobs:execution:ops:rate_1h{urgency="throttled"}
          ) > 0
        )
      |||,
      'for': '30m',
      labels: {
        type: 'sidekiq',  // Hardcoded because `gitlab_background_jobs:queue:ops:rate_1h` `type` label depends on the sidekiq client `type`
        tier: 'sv',  // Hardcoded because `gitlab_background_jobs:queue:ops:rate_1h` `type` label depends on the sidekiq client `type`
        stage: 'main',
        alert_type: 'cause',
        rules_domain: 'general',
        severity: 's4',
      },
      annotations: {
        title: 'Sidekiq jobs are being enqueued without being dequeued',
        description: |||
          The `{{ $labels.worker}}` worker in the {{ $labels.queue }} queue
          appears to have jobs being enqueued without those jobs being executed.

          This could be the result of a Sidekiq server configuration issue, where
          no Sidekiq servers are configured to dequeue the specific worker.
        |||,
        runbook: 'docs/sidekiq/README.md',
        grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
        grafana_variables: 'environment,stage,worker',
        grafana_min_zoom_hours: '6',
        promql_template_1: 'sidekiq_enqueued_jobs_total{environment="$environment", type="$type", stage="$stage", component="$component"}',
      },
    },
    {
      alert: 'SidekiqQueueNoLongerBeingProcessed',
      expr: |||
        (sum by(environment, queue) (gitlab_background_jobs:queue:ops:rate_6h) > 0.001)
        unless
        (sum by(environment, queue) (gitlab_background_jobs:execution:ops:rate_6h)  > 0)
      |||,
      'for': '20m',
      labels: {
        type: 'sidekiq',
        tier: 'sv',
        stage: 'main',
        alert_type: 'cause',
        rules_domain: 'general',
        severity: 's3',
      },
      annotations: {
        title: 'A Sidekiq queue is no longer being processed.',
        description: 'Sidekiq queue {{ $labels.queue }} in shard {{ $labels.shard }} is no longer being processed.',
        runbook: 'docs/sidekiq/sidekiq-queue-not-being-processed.md',
        grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
        grafana_panel_id: stableIds.hashStableId('request-rate'),
        grafana_variables: 'environment,stage,queue',
        grafana_min_zoom_hours: '6',
        promql_template_1: 'gitlab_background_jobs:execution:ops:rate_6h{environment="$environment", queue="$queue"}',
      },
    },
    {
      alert: 'SidekiqWorkerNoLongerBeingProcessed',
      expr: |||
        (sum by(environment, worker) (gitlab_background_jobs:queue:ops:rate_6h) > 0.001)
        unless
        (sum by(environment, worker) (gitlab_background_jobs:execution:ops:rate_6h)  > 0)
      |||,
      'for': '20m',
      labels: {
        type: 'sidekiq',
        tier: 'sv',
        stage: 'main',
        alert_type: 'cause',
        rules_domain: 'general',
        severity: 's3',
      },
      annotations: {
        title: 'A Sidekiq worker is no longer being processed.',
        description: 'Sidekiq worker {{ $labels.worker }} in shard {{ $labels.shard }} is no longer being processed.',
        runbook: 'docs/sidekiq/sidekiq-queue-not-being-processed.md',
        grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
        grafana_panel_id: stableIds.hashStableId('request-rate'),
        grafana_variables: 'environment,stage,worker',
        grafana_min_zoom_hours: '6',
        promql_template_1: 'gitlab_background_jobs:execution:ops:rate_6h{environment="$environment", worker="$worker"}',
      },
    },
  ] +
  serviceLevelAlerts.apdexAlertsForSLI(
    alertName=serviceLevelAlerts.nameSLOViolationAlert('sidekiq', 'WorkerExecution', 'ApdexSLOViolation'),
    alertTitle='The `{{ $labels.worker }}` Sidekiq worker, `{{ $labels.stage }}` stage, has an apdex violating SLO',
    alertDescriptionLines=[|||
      The `{{ $labels.worker }}` worker is not meeting its apdex SLO.
    |||],
    serviceType='sidekiq',
    severity='s4',
    thresholdSLOValue=fixedApdexThreshold,
    aggregationSet=aggregationSets.sidekiqWorkerExecutionSLIs,
    windows=['3d'],
    metricSelectorHash={},
    minimumSamplesForMonitoring=minimumSamplesForMonitoringApdex,
    extraAnnotations={
      grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
      grafana_panel_id: stableIds.hashStableId('execution-apdex'),
      grafana_variables: 'environment,stage,worker',
      grafana_min_zoom_hours: '6',
    },
  )
  +
  serviceLevelAlerts.errorAlertsForSLI(
    alertName=serviceLevelAlerts.nameSLOViolationAlert('sidekiq', 'WorkerExecution', 'ErrorSLOViolation'),
    alertTitle='The `{{ $labels.worker }}` Sidekiq worker, `{{ $labels.stage }}` stage, has an error rate violating SLO',
    alertDescriptionLines=[|||
      The `{{ $labels.worker }}` worker is not meeting its error-rate SLO.
    |||],
    serviceType='sidekiq',
    severity='s4',
    thresholdSLOValue=fixedErrorRateThreshold,
    aggregationSet=aggregationSets.sidekiqWorkerExecutionSLIs,
    windows=['3d'],
    metricSelectorHash={},
    minimumSamplesForMonitoring=minimumSamplesForMonitoringErrors,
    extraAnnotations={
      grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
      grafana_panel_id: stableIds.hashStableId('error-ratio'),
      grafana_variables: 'environment,stage,worker',
      grafana_min_zoom_hours: '6',
    },
  );


local rules = {
  groups:
    aggregationSetTransformer.generateRecordingRuleGroups(
      sourceAggregationSet=aggregationSets.sidekiqWorkerQueueSourceSLIs,
      targetAggregationSet=aggregationSets.sidekiqWorkerQueueSLIs,
      extrasForGroup={ partial_response_strategy: 'warn' },
    ) +
    aggregationSetTransformer.generateRecordingRuleGroups(
      sourceAggregationSet=aggregationSets.sidekiqWorkerExecutionSourceSLIs,
      targetAggregationSet=aggregationSets.sidekiqWorkerExecutionSLIs,
      extrasForGroup={ partial_response_strategy: 'warn' },
    )
    + [{
      name: 'Sidekiq Aggregated Thanos Alerts',
      partial_response_strategy: 'warn',
      interval: '1m',
      rules: alerts.processAlertRules(sidekiqThanosAlerts()),
    }],
};

{
  'sidekiq-alerts.yml': std.manifestYamlDoc(rules),
}
