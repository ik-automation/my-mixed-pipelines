local aggregationSets = import './aggregation-sets.libsonnet';
local allSaturationTypes = import './saturation/all.libsonnet';
local allServices = import './services/all.jsonnet';
local allUtilizationMetrics = import './utilization/all.libsonnet';
local objects = import 'utils/objects.libsonnet';
local labelSet = (import 'label-taxonomy/label-set.libsonnet');

// Site-wide configuration options
{
  // In accordance with Infra OKR: https://gitlab.com/gitlab-com/www-gitlab-com/-/issues/8024
  slaTarget:: 0.9995,

  // List of services with SLI/SLO monitoring
  monitoredServices:: allServices,

  // Hash of all aggregation sets
  aggregationSets:: aggregationSets,

  // Hash of all saturation metric types that are monitored on gitlab.com
  saturationMonitoring:: objects.mergeAll(allSaturationTypes),

  // Hash of all utilization metric types that are monitored on gitlab.com
  utilizationMonitoring:: objects.mergeAll(allUtilizationMetrics),

  serviceCatalog:: (import 'service-catalog.jsonnet'),

  // stage-group-mapping.jsonnet is generated file, stored in the `services` directory
  stageGroupMapping:: import 'stage-group-mapping.jsonnet',

  // The base selector for the environment, as configured in Grafana dashboards
  grafanaEnvironmentSelector:: { environment: '$environment', env: '$environment' },

  // Signifies that a stage is partitioned into canary, main stage etc
  useEnvironmentStages:: true,

  // Name of the default Prometheus datasource to use
  defaultPrometheusDatasource: 'Global',

  labelTaxonomy:: labelSet.makeLabelSet({
    environmentThanos: 'env',
    environment: 'environment',
    tier: 'tier',
    service: 'type',
    stage: 'stage',
    shard: 'shard',
    node: 'fqdn',
    sliComponent: 'component',
  }),
}
