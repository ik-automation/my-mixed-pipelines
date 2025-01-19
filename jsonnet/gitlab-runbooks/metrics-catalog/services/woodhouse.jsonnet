local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

local woodhouseLogs = [
  toolingLinks.stackdriverLogs(
    'Woodhouse Container Logs',
    queryHash={
      'resource.type': 'k8s_container',
      'resource.labels.cluster_name': 'ops-gitlab-gke',
      'resource.labels.namespace_name': 'woodhouse',
      'resource.labels.container_name': 'woodhouse',
    },
    project='gitlab-ops',
    // Long, but usually very quiet so give a good chance to see something to frame events
    timeRange='PT6H',
  ),
];

metricsCatalog.serviceDefinition({
  type: 'woodhouse',
  tier: 'sv',
  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },
  provisioning: {
    vms: false,
    kubernetes: true,
  },
  serviceDependencies: {
    api: true,
  },
  kubeConfig: {
    local woodhouseKubeLabels = { type: 'woodhouse', stage: 'main' },

    labelSelectors: kubeLabelSelectors(
      podSelector=woodhouseKubeLabels,
      hpaSelector=null,  // no hpas for woodhouse,
      ingressSelector=woodhouseKubeLabels,
      deploymentSelector=woodhouseKubeLabels,
    ),
  },
  kubeResources: {
    woodhouse: {
      kind: 'Deployment',
      containers: [
        'woodhouse',
      ],
    },
  },
  serviceLevelIndicators: {
    http: {
      userImpacting: false,
      feature_category: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        HTTP requests handled by woodhouse.
      |||,

      local selector = { job: 'woodhouse', route: { ne: '/ready' } },
      apdex: histogramApdex(
        histogram='woodhouse_http_request_duration_seconds_bucket',
        selector=selector,
        satisfiedThreshold=1,
      ),
      requestRate: rateMetric(
        counter='woodhouse_http_requests_total',
        selector=selector,
      ),
      errorRate: rateMetric(
        // Slack handlers return HTTP 200 even when there is an error, because
        // unfortunately that is how the Slack API works, and is the only way to
        // show errors to callers. Therefore, woodhouse exposes a separate
        // metric for this rather than relying on 5xx.
        counter='woodhouse_http_requests_errors_total',
        selector=selector,
      ),
      significantLabels: [],

      toolingLinks: woodhouseLogs,
    },

    async_jobs: {
      userImpacting: false,
      feature_category: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        Async jobs performed by woodhouse.
      |||,

      local selector = { job: 'woodhouse' },
      apdex: histogramApdex(
        histogram='woodhouse_async_job_duration_seconds_bucket',
        selector=selector,
        satisfiedThreshold=10,
      ),
      requestRate: rateMetric(
        counter='woodhouse_async_jobs_total',
        selector=selector,
      ),
      errorRate: rateMetric(
        counter='woodhouse_async_jobs_total',
        selector=selector { status: 'error' },
      ),
      significantLabels: ['job_name'],

      toolingLinks: woodhouseLogs,
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Structured logs available in Kibana': 'Log volume is very low; tooling links to StackDriver provided which is sufficient for the purposes',
  }),
})
