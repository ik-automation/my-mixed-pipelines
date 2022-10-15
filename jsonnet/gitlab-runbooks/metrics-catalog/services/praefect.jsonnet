local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local combined = metricsCatalog.combined;
local rateMetric = metricsCatalog.rateMetric;
local gaugeMetric = metricsCatalog.gaugeMetric;
local histogramApdex = metricsCatalog.histogramApdex;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local gitalyHelper = import 'service-archetypes/helpers/gitaly.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'praefect',
  tier: 'stor',

  tags: ['cloud-sql', 'golang'],

  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.9995,  // 99.95% of Praefect requests should succeed, over multiple window periods
  },
  otherThresholds: {
    // Deployment thresholds are optional, and when they are specified, they are
    // measured against the same multi-burn-rates as the monitoring indicators.
    // When a service is in violation, deployments may be blocked or may be rolled
    // back.
    deployment: {
      apdexScore: 0.995,
      errorRatio: 0.9995,
    },
  },
  serviceDependencies: {
    gitaly: true,
    'cloud-sql': true,
  },
  serviceLevelIndicators: {
    proxy: {
      userImpacting: true,
      featureCategory: 'gitaly',
      description: |||
        All Gitaly operations pass through the Praefect proxy on the way to a Gitaly instance. This SLI monitors
        those operations in aggregate.
      |||,

      local baseSelector = { job: 'praefect' },
      local mainApdexSelector = baseSelector {
        grpc_method: { noneOf: gitalyHelper.praefectApdexSlowMethods },
      },
      local slowMethodApdexSelector = baseSelector {
        grpc_method: { oneOf: gitalyHelper.praefectApdexSlowMethods },
      },
      apdex: combined(
        [
          gitalyHelper.grpcServiceApdex(mainApdexSelector),
          gitalyHelper.grpcServiceApdex(slowMethodApdexSelector, satisfiedThreshold=10, toleratedThreshold=30),
        ]
      ),

      requestRate: rateMetric(
        counter='grpc_server_handled_total',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='grpc_server_handled_total',
        selector=baseSelector {
          grpc_code: { nre: '^(OK|NotFound|Unauthenticated|AlreadyExists|FailedPrecondition|Canceled)$' },
        }
      ),

      significantLabels: ['fqdn'],

      toolingLinks: [
        toolingLinks.continuousProfiler(service='praefect'),
        toolingLinks.sentry(slug='gitlab/praefect-production'),
        toolingLinks.kibana(title='Praefect', index='praefect', slowRequestSeconds=1),
      ],
    },

    // The replicator_queue handles replication jobs from Praefect to secondaries
    // the apdex measures the percentage of jobs that dequeue within the SLO
    // See:
    // * https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/11027
    // * https://gitlab.com/gitlab-org/gitaly/-/issues/2915
    replicator_queue: {
      trafficCessationAlertConfig: false,
      userImpacting: false,
      featureCategory: 'gitaly',
      description: |||
        Praefect replication operations. Latency represents the queuing delay before replication is carried out.
      |||,

      local baseSelector = { job: 'praefect' },
      apdex: histogramApdex(
        histogram='gitaly_praefect_replication_delay_bucket',
        selector=baseSelector,
        satisfiedThreshold=300
      ),

      requestRate: rateMetric(
        counter='gitaly_praefect_replication_delay_bucket',
        selector=baseSelector { le: '+Inf' }
      ),

      significantLabels: ['fqdn', 'type'],
    },

    praefect_cloudsql: {
      userImpacting: true,
      featureCategory: 'gitaly',
      description: |||
        Praefect uses a GCP CloudSQL instance. This SLI represents SQL transactions to that service.
      |||,

      local baseSelector = {
        job: 'stackdriver',
        database_id: { re: '.+:praefect-db-.+' },
        database: { re: 'praefect_(canary|production)' },
      },

      staticLabels: {
        tier: 'stor',
        type: 'praefect',
      },

      requestRate: gaugeMetric(
        gauge='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_transaction_count',
        selector=baseSelector
      ),

      errorRate: gaugeMetric(
        gauge='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_transaction_count',
        selector=baseSelector {
          transaction_type: 'rollback',
        }
      ),

      significantLabels: ['database_id'],
      serviceAggregation: false,  // Don't include cloudsql in the aggregated RPS for the service
      toolingLinks: [
        toolingLinks.cloudSQL('praefect-db-9dfb'),
      ],
    },
  },
})
