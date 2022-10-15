local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local maturityLevels = import 'service-maturity/levels.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'external-dns',
  tier: 'sv',
  provisioning: {
    vms: false,
    kubernetes: true,
  },

  serviceDependencies: {
    kube: true,
  },

  serviceLevelIndicators: {},
  skippedMaturityCriteria: maturityLevels.skip({
    'Structured logs available in Kibana': 'Logs from external-dns are not ingested to ElasticSearch due to volume. Besides, the logs are also available in Stackdriver',
    'Developer guides exist in developer documentation': 'external-dns is an infrastructure component, developers do not interact with it',
  }),
})
