// WARNING
// This is probably not what you want. Avoid combining multiple signals into
// a single SLI unless you are sure you know what you are doing

local dependencies = import 'servicemetrics/dependencies_definition.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local misc = import 'utils/misc.libsonnet';

// Combined component definitions are a specialisation of the service-component.
// They allow multiple components to be combined under a single name, but with different
// static labels.
//
// This allows different components to be specific for different stages (for example). This
// is specifically useful for loadbalancers
local combinedServiceLevelIndicatorDefinition(
  userImpacting,
  components,
  featureCategory,
  description,
  team=null,
  serviceAggregation=false,
  staticLabels={},
  trafficCessationAlertConfig=true,
  regional=null,
  dependsOn=[],
      ) =
  {
    initServiceLevelIndicatorWithName(componentName, inheritedDefaults)::
      // TODO: validate that all staticLabels are unique
      local componentsInitialised = std.map(function(c) c.initServiceLevelIndicatorWithName(componentName, inheritedDefaults), components);

      {
        name: componentName,
        userImpacting: userImpacting,
        featureCategory: featureCategory,
        description: description,
        team: team,
        trafficCessationAlertConfig: trafficCessationAlertConfig,
        regional: if regional != null then regional else inheritedDefaults.regional,
        severity: componentsInitialised[0].severity,
        dependsOn: dependsOn,
        dependencies: dependencies.new(inheritedDefaults.type, componentName, dependsOn),

        serviceAggregation: serviceAggregation,

        hasFeatureCategoryFromSourceMetrics()::
          misc.all(function(component) component.hasFeatureCategoryFromSourceMetrics(), componentsInitialised),
        hasStaticFeatureCategory():: featureCategory != null && featureCategory != 'not_owned',
        hasFeatureCategory():: self.hasStaticFeatureCategory() || self.hasFeatureCategoryFromSourceMetrics(),
        staticFeatureCategoryLabels():: { feature_category: featureCategory },

        // Returns true if this component allows detailed breakdowns
        // this is not the case for combined component definitions
        supportsDetails(): false,

        // Combined SLIs should always use the thresholds specified on the service
        monitoringThresholds:
          if std.objectHas(inheritedDefaults, 'monitoringThresholds') then
            inheritedDefaults.monitoringThresholds
          else
            {},

        hasApdexSLO():: std.objectHas(self.monitoringThresholds, 'apdexScore'),
        hasApdex():: componentsInitialised[0].hasApdex(),
        hasRequestRate():: componentsInitialised[0].hasRequestRate(),
        hasAggregatableRequestRate():: componentsInitialised[0].hasAggregatableRequestRate(),
        hasErrorRateSLO():: std.objectHas(self.monitoringThresholds, 'errorRatio'),
        hasErrorRate():: componentsInitialised[0].hasErrorRate(),
        hasDependencies():: std.length(self.dependsOn) > 0,

        hasToolingLinks()::
          std.length(self.getToolingLinks()) > 0,

        getToolingLinks()::
          std.flatMap(function(c) c.getToolingLinks(), componentsInitialised),

        renderToolingLinks()::
          toolingLinks.renderLinks(self.getToolingLinks()),

        // Generate recording rules for apdex
        generateApdexRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels)::
          std.flatMap(function(c) c.generateApdexRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels), componentsInitialised),

        // Generate recording rules for request rate
        generateRequestRateRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels)::
          std.flatMap(function(c) c.generateRequestRateRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels), componentsInitialised),

        // Generate recording rules for error rate
        generateErrorRateRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels)::
          std.flatMap(function(c) c.generateErrorRateRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels), componentsInitialised),

        // Significant labels are the union of all significantLabels from the components
        significantLabels:
          std.set(std.flatMap(function(c) c.significantLabels, componentsInitialised)),
      },
  };

{
  combinedServiceLevelIndicatorDefinition:: combinedServiceLevelIndicatorDefinition,
}
