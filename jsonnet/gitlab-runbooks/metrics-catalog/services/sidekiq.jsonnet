local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local sidekiqHelpers = import './lib/sidekiq-helpers.libsonnet';
local perWorkerRecordingRules = (import './lib/sidekiq-per-worker-recording-rules.libsonnet').perWorkerRecordingRules;
local combined = metricsCatalog.combined;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local sliLibrary = import 'gitlab-slis/library.libsonnet';

local highUrgencySelector = { urgency: 'high' };
local lowUrgencySelector = { urgency: 'low' };
local throttledUrgencySelector = { urgency: 'throttled' };
local noUrgencySelector = { urgency: '' };

metricsCatalog.serviceDefinition({
  type: 'sidekiq',
  tier: 'sv',
  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.995,
  },
  otherThresholds: {
    // Deployment thresholds are optional, and when they are specified, they are
    // measured against the same multi-burn-rates as the monitoring indicators.
    // When a service is in violation, deployments may be blocked or may be rolled
    // back.
    deployment: {
      apdexScore: 0.995,
      errorRatio: 0.995,
    },
  },
  serviceDependencies: {
    gitaly: true,
    'redis-tracechunks': true,
    'redis-sidekiq': true,
    'redis-cache': true,
    redis: true,
    patroni: true,
    pgbouncer: true,
    praefect: true,
    pvs: true,
    search: true,
    consul: true,
    'google-cloud-storage': true,
  },
  provisioning: {
    kubernetes: true,
    vms: false,
  },
  // Use recordingRuleMetrics to specify a set of metrics with known high
  // cardinality. The metrics catalog will generate recording rules with
  // the appropriate aggregations based on this set.
  // Use sparingly, and don't overuse.
  recordingRuleMetrics: [
    'sidekiq_jobs_completion_seconds_bucket',
    'sidekiq_jobs_queue_duration_seconds_bucket',
    'sidekiq_jobs_failed_total',
  ],
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      ingressSelector=null,  // no ingress for sidekiq
      nodeSelector={ type: 'sidekiq' },
      // Sidekiq nodes don't present a stage label at present, so\
      // we hardcode to main stage
      nodeStaticLabels={ stage: 'main' },
    ),
  },
  kubeResources: std.foldl(
    function(memo, shard)
      memo {
        // Deployment tags follow the convention sidekiq-catchall etc
        ['sidekiq-' + shard.name]: {
          kind: 'Deployment',
          containers: [
            'sidekiq',
          ],
        },
      },
    sidekiqHelpers.shards.listAll(),
    {},
  ),
  serviceLevelIndicators: {
    ['shard_' + std.strReplace(shard.name, '-', '_')]: {
      local shardSelector = { shard: shard.name },

      userImpacting: shard.userImpacting,
      featureCategory: 'not_owned',
      team: 'scalability',
      trafficCessationAlertConfig: shard.trafficCessationAlertConfig,
      upscaleLongerBurnRates: true,
      monitoringThresholds+: shard.monitoringThresholds,

      description: |||
        Aggregation of all jobs for the %(shard)s Sidekiq shard.
      ||| % shardSelector,
      apdex: combined(
        [
          histogramApdex(
            histogram='sidekiq_jobs_completion_seconds_bucket',
            selector=highUrgencySelector + shardSelector,
            satisfiedThreshold=sidekiqHelpers.slos.urgent.executionDurationSeconds,
          ),
          histogramApdex(
            histogram='sidekiq_jobs_queue_duration_seconds_bucket',
            selector=highUrgencySelector + shardSelector,
            satisfiedThreshold=sidekiqHelpers.slos.urgent.queueingDurationSeconds,
          ),
          histogramApdex(
            histogram='sidekiq_jobs_completion_seconds_bucket',
            selector=lowUrgencySelector + shardSelector,
            satisfiedThreshold=sidekiqHelpers.slos.lowUrgency.executionDurationSeconds,
          ),
          histogramApdex(
            histogram='sidekiq_jobs_queue_duration_seconds_bucket',
            selector=lowUrgencySelector + shardSelector,
            satisfiedThreshold=sidekiqHelpers.slos.lowUrgency.queueingDurationSeconds,
          ),
          histogramApdex(
            histogram='sidekiq_jobs_completion_seconds_bucket',
            selector=throttledUrgencySelector + shardSelector,
            satisfiedThreshold=sidekiqHelpers.slos.throttled.executionDurationSeconds,
          ),
          // No queueing apdex for throttled jobs
        ]
      ),

      requestRate: rateMetric(
        counter='sidekiq_jobs_completion_seconds_bucket',
        selector=shardSelector { le: '+Inf' },
      ),

      errorRate: rateMetric(
        counter='sidekiq_jobs_failed_total',
        selector=shardSelector,
      ),

      // Note: these labels will also be included in the
      // intermediate recording rules specified in the
      // `recordingRuleMetrics` stanza above
      significantLabels: ['feature_category', 'queue', 'urgency', 'worker'],

      // We don't have an `urgency` field in Sidekiq logs. Improve this in
      // https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/700
      local slowRequestSeconds =
        if shard.urgency == 'high' then
          sidekiqHelpers.slos.urgent.executionDurationSeconds
        else if shard.urgency == 'low' then
          sidekiqHelpers.slos.lowUrgency.executionDurationSeconds
        else if shard.urgency == 'throttled' then
          sidekiqHelpers.slos.throttled.executionDurationSeconds
        else
          // Default to low urgency threshold
          sidekiqHelpers.slos.lowUrgency.executionDurationSeconds,

      toolingLinks: [
        // Improve sentry link once https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/532 arrives
        toolingLinks.sentry(slug='gitlab/gitlabcom', type='sidekiq'),
        toolingLinks.kibana(title=shard.name, index='sidekiq', type='sidekiq', shard=shard.name, slowRequestSeconds=slowRequestSeconds),
      ] + (
        if std.objectHas(shard, 'gkeDeployment') then
          [
            toolingLinks.gkeDeployment(shard.gkeDeployment, type='sidekiq', shard=shard.name, containerName='sidekiq'),
          ]
        else
          []
      ),
    }
    for shard in sidekiqHelpers.shards.listAll()
  } + {
    email_receiver: {
      userImpacting: true,
      severity: 's3',
      featureCategory: 'service_desk',
      team: 'certify',
      description: |||
        Monitors ratio between all received emails and received emails which
        could not be processed for some reason.
      |||,

      requestRate: rateMetric(
        counter='sidekiq_jobs_completion_seconds_count',
        selector={ worker: { re: 'EmailReceiverWorker|ServiceDeskEmailReceiverWorker' } }
      ),

      errorRate: rateMetric(
        counter='gitlab_transaction_event_email_receiver_error_total',
        selector={ 'error': { ne: 'Gitlab::Email::AutoGeneratedEmailError' } }
      ),

      monitoringThresholds+: {
        errorRatio: 0.7,
      },

      significantLabels: ['error'],

      toolingLinks: [
        toolingLinks.kibana(title='Email receiver errors', index='sidekiq', type='sidekiq', message='Error processing message'),
      ],
    },

    global_search_indexing:
      sliLibrary.get('global_search_indexing').generateServiceLevelIndicator({ type: 'sidekiq' }) {
        serviceAggregation: false,  // Don't add this to the request rate of the service
        severity: 's3',  // Don't page SREs for this SLI
      },
  },

  // Special per-worker recording rules
  extraRecordingRulesPerBurnRate: [
    // Adds per-work queuing/execution apdex, plus error rates etc
    // across multiple burn rates
    perWorkerRecordingRules,
  ],
})
