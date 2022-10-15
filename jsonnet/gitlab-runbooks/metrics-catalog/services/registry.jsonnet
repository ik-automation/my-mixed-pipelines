local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local haproxyComponents = import './lib/haproxy_components.libsonnet';
local registryHelpers = import './lib/registry-helpers.libsonnet';
local registryBaseSelector = registryHelpers.registryBaseSelector;
local defaultRegistrySLIProperties = registryHelpers.defaultRegistrySLIProperties;
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

metricsCatalog.serviceDefinition({
  type: 'registry',
  tier: 'sv',

  tags: ['golang'],

  contractualThresholds: {
    apdexRatio: 0.9,
    errorRatio: 0.005,
  },
  otherThresholds: {
    // Deployment thresholds are optional, and when they are specified, they are
    // measured against the same multi-burn-rates as the monitoring indicators.
    // When a service is in violation, deployments may be blocked or may be rolled
    // back.
    deployment: {
      apdexScore: 0.9929,
      errorRatio: 0.9700,
    },

    mtbf: {
      apdexScore: 0.9995,
      errorRatio: 0.99995,
    },
  },
  monitoringThresholds: {
    apdexScore: 0.997,
    errorRatio: 0.9999,
  },
  serviceDependencies: {
    api: true,
    'redis-registry-cache': true,
  },
  provisioning: {
    kubernetes: true,
    vms: true,  // registry haproxy frontend still runs on vms
  },
  // Git service is spread across multiple regions, monitor it as such
  regional: true,
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      ingressSelector=null,  // no ingress for registry
      nodeSelector={ type: 'registry', stage: { oneOf: ['main', 'cny'] } },
    ),
  },
  kubeResources: {
    registry: {
      kind: 'Deployment',
      containers: [
        'registry',
      ],
    },
  },
  serviceLevelIndicators: {
    loadbalancer: haproxyComponents.haproxyHTTPLoadBalancer(
      userImpacting=true,
      featureCategory='container_registry',
      stageMappings={
        main: { backends: ['registry'], toolingLinks: [] },
        cny: { backends: ['canary_registry'], toolingLinks: [] },
      },
      selector=registryBaseSelector,
      regional=false
    ),

    server: defaultRegistrySLIProperties {
      description: |||
        Aggregation of all registry requests.
      |||,

      apdex: registryHelpers.mainApdex,

      requestRate: rateMetric(
        counter='registry_http_requests_total',
        selector=registryBaseSelector
      ),

      errorRate: rateMetric(
        counter='registry_http_requests_total',
        selector=registryBaseSelector {
          code: { re: '5..' },
        }
      ),

      significantLabels: ['route', 'method', 'migration_path'],

      toolingLinks: [
        toolingLinks.gkeDeployment('gitlab-registry', type='registry', containerName='registry'),
        toolingLinks.kibana(title='Registry', index='registry', type='registry', slowRequestSeconds=10),
        toolingLinks.continuousProfiler(service='gitlab-registry'),
      ],
    },

    database: {
      userImpacting: true,
      featureCategory: 'container_registry',
      description: |||
        Aggregation of all container registry database operations.
      |||,

      apdex: histogramApdex(
        histogram='registry_database_query_duration_seconds_bucket',
        selector={ type: 'registry' },
        satisfiedThreshold=0.5,
        toleratedThreshold=1
      ),

      requestRate: rateMetric(
        counter='registry_database_queries_total',
        selector=registryBaseSelector
      ),

      significantLabels: ['name'],
    },

    garbagecollector: {
      severity: 's3',
      userImpacting: false,
      serviceAggregation: false,
      featureCategory: 'container_registry',
      description: |||
        Aggregation of all container registry online garbage collection operations.
      |||,

      apdex: histogramApdex(
        histogram='registry_gc_run_duration_seconds_bucket',
        selector={ type: 'registry' },
        satisfiedThreshold=0.5,
        toleratedThreshold=1
      ),

      requestRate: rateMetric(
        counter='registry_gc_runs_total',
        selector=registryBaseSelector
      ),

      errorRate: rateMetric(
        counter='registry_gc_runs_total',
        selector=registryBaseSelector {
          'error': 'true',
        }
      ),

      significantLabels: ['worker'],
      toolingLinks: [
        toolingLinks.kibana(
          title='Garbage Collector',
          index='registry_garbagecollection',
          type='registry',
          matches={ 'json.component': ['registry.gc.Agent', 'registry.gc.worker.ManifestWorker', 'registry.gc.worker.BlobWorker'] }
        ),
      ],
    },

    redis: {
      userImpacting: true,
      featureCategory: 'container_registry',
      description: |||
        Aggregation of all container registry Redis operations.
      |||,

      apdex: histogramApdex(
        histogram='registry_redis_single_commands_bucket',
        selector=registryBaseSelector,
        satisfiedThreshold=0.25,
        toleratedThreshold=0.5
      ),

      requestRate: rateMetric(
        counter='registry_redis_single_commands_count',
        selector=registryBaseSelector
      ),

      errorRate: rateMetric(
        counter='registry_redis_single_errors_count',
        selector=registryBaseSelector
      ),

      significantLabels: ['instance', 'command'],
    },
  } + registryHelpers.apdexPerRoute,
})
