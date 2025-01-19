local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local combined = metricsCatalog.combined;
local customApdex = metricsCatalog.customApdex;
local rateMetric = metricsCatalog.rateMetric;
local gitalyHelper = import 'service-archetypes/helpers/gitaly.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'gitaly',
  tier: 'stor',

  // disk_performance_monitoring requires disk utilisation metrics are currently reporting correctly for
  // HDD volumes, see https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/10248
  // as such, we only record this utilisation metric on IO subset of the fleet for now.
  tags: ['golang', 'disk_performance_monitoring'],

  // Since each Gitaly node is a SPOF for a subset of repositories, we need to ensure that
  // we have node-level monitoring on these hosts
  nodeLevelMonitoring: true,
  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.9995,
  },
  otherThresholds: {
    // Deployment thresholds are optional, and when they are specified, they are
    // measured against the same multi-burn-rates as the monitoring indicators.
    // When a service is in violation, deployments may be blocked or may be rolled
    // back.
    deployment: {
      apdexScore: 0.999,
      errorRatio: 0.9995,
    },
  },
  serviceDependencies: {
    gitaly: true,
  },
  serviceLevelIndicators: {
    goserver: {
      userImpacting: true,
      featureCategory: 'gitaly',
      description: |||
        This SLI monitors all Gitaly GRPC requests in aggregate, excluding the OperationService.
        GRPC failures which are considered to be the "server's fault" are counted as errors.
        The apdex score is based on a subset of GRPC methods which are expected to be fast.
      |||,

      local baseSelector = {
        job: 'gitaly',
      },
      local apdexSelector = baseSelector {
        grpc_service: { ne: ['gitaly.OperationService'] },
      },
      local mainApdexSelector = apdexSelector {
        grpc_method: { noneOf: gitalyHelper.gitalyApdexIgnoredMethods + gitalyHelper.gitalyApdexSlowMethods },
      },
      local slowMethodApdexSelector = apdexSelector {
        grpc_method: { oneOf: gitalyHelper.gitalyApdexSlowMethods },
      },
      local operationServiceApdexSelector = baseSelector {
        grpc_service: ['gitaly.OperationService'],
      },

      apdex: combined(
        [
          gitalyHelper.grpcServiceApdex(mainApdexSelector),
          gitalyHelper.grpcServiceApdex(slowMethodApdexSelector, satisfiedThreshold=10, toleratedThreshold=30),
          gitalyHelper.grpcServiceApdex(operationServiceApdexSelector, satisfiedThreshold=10, toleratedThreshold=30),
        ]
      ),

      requestRate: rateMetric(
        counter='gitaly_service_client_requests_total',
        selector=baseSelector
      ),

      errorRate: gitalyHelper.gitalyGRPCErrorRate(baseSelector),

      significantLabels: ['fqdn'],

      toolingLinks: [
        toolingLinks.continuousProfiler(service='gitaly'),
        toolingLinks.sentry(slug='gitlab/gitaly-production'),
        toolingLinks.kibana(title='Gitaly', index='gitaly', slowRequestSeconds=1),
      ],
    },
  },
})
