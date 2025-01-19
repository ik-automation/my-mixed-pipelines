local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local maturityLevels = import 'service-maturity/levels.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'consul',
  tier: 'sv',
  monitoringThresholds: {
  },
  serviceDependencies: {
  },
  provisioning: {
    vms: true,
    kubernetes: true,
  },
  regional: true,
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      hpaSelector=null,  // no hpas for consul
      ingressSelector=null,  // no ingress for consul
      deploymentSelector=null,  // no deployments for consul
    ),
  },
  kubeResources: {
    consul: {
      kind: 'Daemonset',
      containers: [
        'consul',
      ],
    },
  },
  serviceLevelIndicators: {
    consul: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        HTTP GET requests handled by the Consul agent.
      |||,

      requestRate: metricsCatalog.derivMetric(
        counter='consul_http_GET_v1_agent_metrics_count',
        clampMinZero=true,
      ),

      significantLabels: ['type'],

      toolingLinks: [
        toolingLinks.kibana(title='Consul', index='consul', includeMatchersForPrometheusSelector=false),
      ],
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Developer guides exist in developer documentation': 'Consul is an infrastructure component, developers do not interact with it',
  }),
})
