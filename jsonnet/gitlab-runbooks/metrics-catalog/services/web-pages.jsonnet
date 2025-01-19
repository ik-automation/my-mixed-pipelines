local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local haproxyComponents = import './lib/haproxy_components.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local dependOnApi = import 'inhibit-rules/depend_on_api.libsonnet';

local baseSelector = { type: 'web-pages' };

metricsCatalog.serviceDefinition({
  type: 'web-pages',
  tier: 'sv',

  tags: ['golang'],

  contractualThresholds: {
    apdexRatio: 0.95,
    errorRatio: 0.05,
  },

  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.9995,
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
    mtbf: {
      apdexScore: 0.999,
      errorRatio: 0.9999,
    },
  },
  serviceDependencies: {
    'google-cloud-storage': true,
  },
  provisioning: {
    vms: true,  // pages haproxy frontend still runs on vms
    kubernetes: true,
  },

  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      ingressSelector=null,  // no ingress for web-pages
      nodeSelector={ type: 'web-pages' },
      // TODO: web-pages nodes do not present a stage label at present
      // See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/2244
      // We hard-code to main for now
      nodeStaticLabels={ stage: 'main' },
    ),
  },

  kubeResources: {
    'web-pages': {
      kind: 'Deployment',
      containers: [
        'gitlab-pages',
      ],
    },
  },
  regional: true,
  serviceLevelIndicators: {
    loadbalancer: haproxyComponents.haproxyHTTPLoadBalancer(
      userImpacting=true,
      featureCategory='pages',
      stageMappings={
        main: { backends: ['pages_http'], toolingLinks: [] },
        // TODO: cny stage for pages?
      },
      selector={ type: { re: 'pages|web-pages' } },
      dependsOn=dependOnApi.restComponents,
    ),

    loadbalancer_https: haproxyComponents.haproxyL4LoadBalancer(
      userImpacting=true,
      featureCategory='pages',
      stageMappings={
        main: { backends: ['pages_https'], toolingLinks: [] },
        // TODO: cny stage for pages?
      },
      selector={ type: { re: 'pages|web-pages' } },
      dependsOn=dependOnApi.restComponents,
    ),

    server: {
      userImpacting: true,
      featureCategory: 'pages',
      description: |||
        Aggregation of most web requests into the GitLab Pages process.
      |||,
      // GitLab Pages sometimes serves very large files which takes some reasonable time
      // we have stricter server_headers SLI, so this threshold can be set higher
      apdex: histogramApdex(
        histogram='gitlab_pages_http_request_duration_seconds_bucket',
        selector=baseSelector,
        satisfiedThreshold=10
      ),

      requestRate: rateMetric(
        counter='gitlab_pages_http_requests_total',
        selector={}
      ),

      errorRate: rateMetric(
        counter='gitlab_pages_http_requests_total',
        selector={ code: { re: '5..' } }
      ),

      significantLabels: ['fqdn'],

      toolingLinks: [
        toolingLinks.continuousProfiler(service='gitlab-pages'),
        toolingLinks.sentry(slug='gitlab/gitlab-pages'),
        toolingLinks.kibana(title='GitLab Pages', index='pages'),
      ],
      dependsOn: dependOnApi.restComponents,
    },

    server_headers: {
      userImpacting: true,
      featureCategory: 'pages',
      description: |||
        Response time can be slow due to large files served by pages.
        This SLI tracks only time needed to finish writing headers.
        It includes API requests to GitLab instance, scanning ZIP archive
        for file entries, processing redirects, etc.
        We use it as stricter SLI for pages as it's independent of served file size
      |||,
      apdex: histogramApdex(
        histogram='gitlab_pages_http_time_to_write_header_seconds_bucket',
        selector=baseSelector,
        satisfiedThreshold=0.5
      ),

      requestRate: rateMetric(
        counter='gitlab_pages_http_time_to_write_header_seconds_count',
        selector=baseSelector
      ),

      significantLabels: ['fqdn'],

      dependsOn: dependOnApi.restComponents,
    },
  },
})
