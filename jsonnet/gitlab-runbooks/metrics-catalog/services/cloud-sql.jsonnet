local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local gaugeMetric = metricsCatalog.gaugeMetric;
local maturityLevels = import 'service-maturity/levels.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'cloud-sql',
  tier: 'db',

  tags: ['cloud-sql'],

  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.9999,
  },
  regional: false,

  provisioning: {
    vms: false,
    kubernetes: false,
  },

  serviceLevelIndicators: {},

  skippedMaturityCriteria: maturityLevels.skip({
    'Structured logs available in Kibana': 'Cloud SQL is a managed service of GCP. The logs are available in Stackdriver.',
    'Developer guides exist in developer documentation': 'Cloud SQL is an infrastructure component, powered by GCP',
  }),
})
