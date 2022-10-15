local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'kas',
  tier: 'sv',

  tags: ['golang'],

  monitoringThresholds: {
    // apdexScore: 0.95,
    errorRatio: 0.9995,
  },
  otherThresholds: {
    // Deployment thresholds are optional, and when they are specified, they are
    // measured against the same multi-burn-rates as the monitoring indicators.
    // When a service is in violation, deployments may be blocked or may be rolled
    // back.
    deployment: {
      apdexScore: 0.95,
      errorRatio: 0.9995,
    },
  },
  serviceDependencies: {
    api: true,
    gitaly: true,
    kas: true,
    praefect: true,
    redis: true,
  },
  provisioning: {
    kubernetes: true,
    vms: false,
  },
  kubeResources: {
    kas: {
      kind: 'Deployment',
      containers: [
        'kas',
      ],
    },
  },
  serviceLevelIndicators: {
    grpc_requests: {
      userImpacting: true,
      featureCategory: 'kubernetes_management',
      local baseSelector = {
        job: 'gitlab-kas',
      },

      requestRate: rateMetric(
        counter='grpc_server_handled_total',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='grpc_server_handled_total',
        selector=baseSelector {
          grpc_code: { nre: '^(OK|NotFound|FailedPrecondition|Unauthenticated|PermissionDenied|Canceled|DeadlineExceeded|ResourceExhausted)$' },
          grpc_service: { ne: 'gitlab.agent.kubernetes_api.rpc.KubernetesApi' },
        },
      ),

      significantLabels: ['grpc_method'],

      toolingLinks: [
        toolingLinks.sentry(slug='gitlab/kas'),
        toolingLinks.kibana(title='Kubernetes Agent Server', index='kas', type='kas'),
      ],
    },
  },
})
