local kubeLabelSelectors = import 'kube_label_selectors.libsonnet';
local multiburnExpression = import 'mwmbr/expression.libsonnet';
local serviceLevelIndicatorDefinition = import 'service_level_indicator_definition.libsonnet';

// For now we assume that services are provisioned on vms and not kubernetes
local provisioningDefaults = { vms: true, kubernetes: false };
local serviceDefaults = {
  tags: [],
  serviceIsStageless: false,  // Set to true for services that don't use stage labels
  autogenerateRecordingRules: true,
  disableOpsRatePrediction: false,
  nodeLevelMonitoring: false,  // By default we do not use node-level monitoring
  kubeConfig: {},
  kubeResources: {},
  regional: false,  // By default we don't support regional monitoring for services
  alertWindows: multiburnExpression.defaultWindows,
  skippedMaturityCriteria: {},
};

// Convience method, will wrap a raw definition in a serviceLevelIndicatorDefinition if needed
local prepareComponent(definition) =
  if std.objectHasAll(definition, 'initServiceLevelIndicatorWithName') then
    // Already prepared
    definition
  else
    // Wrap class as a component definition
    serviceLevelIndicatorDefinition.serviceLevelIndicatorDefinition(definition);

local validateAndApplyServiceDefaults(service) =
  local serviceWithProvisioningDefaults =
    serviceDefaults + ({ provisioning: provisioningDefaults } + service);

  local serviceWithDefaults = if serviceWithProvisioningDefaults.provisioning.kubernetes then
    local labelSelectors = if std.objectHas(serviceWithProvisioningDefaults.kubeConfig, 'labelSelectors') then
      serviceWithProvisioningDefaults.kubeConfig.labelSelectors
    else
      // Setup a default set of node selectors, based on the `type` label
      kubeLabelSelectors();

    local labelSelectorsInitialized = labelSelectors.init(type=serviceWithProvisioningDefaults.type, tier=serviceWithProvisioningDefaults.tier);
    serviceWithProvisioningDefaults + ({ kubeConfig+: { labelSelectors: labelSelectorsInitialized } })
  else
    serviceWithProvisioningDefaults;

  local sliInheritedDefaults =
    {
      regional: serviceWithDefaults.regional,
      type: serviceWithDefaults.type,
    }
    +
    (
      // When stage labels are disabled, we default all SLI recording rules
      // to the main stage
      if serviceWithDefaults.serviceIsStageless then
        { staticLabels+: { stage: 'main' } }
      else
        {}
    )
    +
    (
      if std.objectHas(serviceWithDefaults, 'monitoringThresholds') then
        { monitoringThresholds: serviceWithDefaults.monitoringThresholds }
      else
        {}
    );

  // If this service is provisioned on kubernetes we should include a kubernetes deployment map
  serviceWithDefaults {
    tags: std.set(serviceWithDefaults.tags),
    serviceLevelIndicators: {
      [sliName]: prepareComponent(service.serviceLevelIndicators[sliName]).initServiceLevelIndicatorWithName(sliName, sliInheritedDefaults)
      for sliName in std.objectFields(service.serviceLevelIndicators)
    },
  };

local serviceDefinition(service) =
  // Private functions
  local private = {
    serviceHasComponentWith(keymetricName)::
      std.foldl(
        function(memo, sliName) memo || std.objectHas(service.serviceLevelIndicators[sliName], keymetricName),
        std.objectFields(service.serviceLevelIndicators),
        false
      ),
    serviceHasComponentWithFeatureCategory()::
      std.foldl(
        function(memo, sliName) memo || service.serviceLevelIndicators[sliName].hasFeatureCategory(),
        std.objectFields(service.serviceLevelIndicators),
        false
      ),
  };

  service {
    hasApdex():: private.serviceHasComponentWith('apdex'),
    hasRequestRate():: std.length(std.objectFields(service.serviceLevelIndicators)) > 0,
    hasErrorRate():: private.serviceHasComponentWith('errorRate'),
    hasFeatureCatogorySLIs():: private.serviceHasComponentWithFeatureCategory(),

    getProvisioning()::
      service.provisioning,

    // Returns an array of serviceLevelIndicators for this service
    listServiceLevelIndicators()::
      [
        service.serviceLevelIndicators[sliName]
        for sliName in std.objectFields(service.serviceLevelIndicators)
      ],

    // Returns true if this service has a
    // dedicated node pool
    hasDedicatedKubeNodePool()::
      service.provisioning.kubernetes &&
      service.kubeConfig.labelSelectors.hasNodeSelector(),
  };

{
  serviceDefinition(service)::
    serviceDefinition(validateAndApplyServiceDefaults(service)),
}
