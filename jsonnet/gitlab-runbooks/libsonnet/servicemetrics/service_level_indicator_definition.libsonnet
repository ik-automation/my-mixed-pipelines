local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';
local dependencies = import 'servicemetrics/dependencies_definition.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local strings = import 'utils/strings.libsonnet';

local featureCategoryFromSourceMetrics = 'featureCategoryFromSourceMetrics';
local featureCategoryNotOwned = stages.notOwned.key;

// For now we assume that services are provisioned on vms and not kubernetes
// Please consult the README.md file for details of team and feature_category
local serviceLevelIndicatorDefaults = {
  featureCategory: featureCategoryNotOwned,
  team: null,
  description: '',
  staticLabels+: {},  // by default, no static labels
  serviceAggregation: true,  // by default, requestRate is aggregated up to the service level
  trafficCessationAlertConfig: true,  // Override to false to disable alerting when SLI is zero or absent
  upscaleLongerBurnRates: false,  // When true, long-term burn rates will be upscaled from shorter burn rates, to optimize for high cardinality metrics
  severity: 's2',
  dependsOn: [],  // When an sli depends on another component, don't alert on this SLI if the downstream service is already firing. This is meant for hard dependencies managed by GitLab.
};

local validateHasField(object, field, message) =
  if std.objectHas(object, field) then
    object
  else
    std.assertEqual(true, { __assert: message });

local validateFeatureCategory(object, sliName) =
  if std.objectHas(stages.featureCategoryMap, object.featureCategory) then
    object
  else if object.featureCategory == featureCategoryFromSourceMetrics then
    assert std.member(object.significantLabels, 'feature_category') : 'feature_category needs to be a significant label for %s' % [sliName];
    object
  else if object.featureCategory == featureCategoryNotOwned then
    object
  else
    assert false : 'feature category: %s is not a valid category for %s' % [object.featureCategory, sliName];
    {};

local validateSeverity(object, message) =
  if std.objectHas(object, 'severity') && std.member(['s1', 's2', 's3', 's4'], object.severity) then
    object
  else
    std.assertEqual(true, { __assert: message });

local validateAndApplySLIDefaults(sliName, component, inheritedDefaults) =
  local withDefaults = serviceLevelIndicatorDefaults +
                       inheritedDefaults +
                       component +
                       { dependencies: dependencies.new(withDefaults.type, sliName, withDefaults.dependsOn) };

  // All components must have a requestRate measurement, since
  // we filter out low-RPS alerts for apdex monitoring and require the RPS for error ratios
  validateHasField(withDefaults, 'requestRate', '%s component requires a requestRate measurement' % [sliName])
  +
  validateHasField(withDefaults, 'significantLabels', '%s component requires a significantLabels attribute' % [sliName])
  +
  validateHasField(withDefaults, 'userImpacting', '%s component requires a userImpacting attribute' % [sliName])
  +
  validateFeatureCategory(withDefaults, '%s is not a valid feature category for %s' % [withDefaults.featureCategory, sliName])
  +
  validateSeverity(withDefaults, '%s does not have a valid severity, must be s1-s4' % [sliName])
  +
  validateFeatureCategory(withDefaults, sliName)
  {
    name: sliName,
  };

// Given an array of labels to aggregate by, filters out those that exist in the staticLabels hash
local filterStaticLabelsFromAggregationLabels(aggregationLabels, staticLabelsHash) =
  std.filter(function(label) !std.objectHas(staticLabelsHash, label), aggregationLabels);

// Currently, we use 1h metrics for upscaling source
local getUpscaleLabels(sli, burnRate) =
  if sli.upscaleLongerBurnRates && burnRate == '1h' then
    { upscale_source: 'yes' }
  else
    {};

// Currently we only do upscaling on 6h burn rates
local isUpscalingTarget(sli, burnRate) =
  sli.upscaleLongerBurnRates && burnRate == '6h';

// Definition of a service level indicator
local serviceLevelIndicatorDefinition(sliName, serviceLevelIndicator) =
  serviceLevelIndicator {
    // Returns true if this serviceLevelIndicator allows detailed breakdowns
    // this is not the case for combined serviceLevelIndicator definitions
    supportsDetails(): true,

    hasApdexSLO():: std.objectHas(self, 'monitoringThresholds') &&
                    std.objectHas(self.monitoringThresholds, 'apdexScore'),
    hasApdex():: std.objectHas(serviceLevelIndicator, 'apdex'),
    hasHistogramApdex()::
      // Only apdex SLIs using a histogram can generate a histogram_quantile graph
      // in alerts
      self.hasApdex() &&
      std.objectHasAll(serviceLevelIndicator.apdex, 'histogram'),

    hasRequestRate():: true,  // requestRate is mandatory
    hasAggregatableRequestRate():: std.objectHasAll(serviceLevelIndicator.requestRate, 'aggregatedRateQuery'),
    hasErrorRateSLO()::
      std.objectHas(serviceLevelIndicator, 'monitoringThresholds') &&
      std.objectHas(serviceLevelIndicator.monitoringThresholds, 'errorRatio'),
    hasErrorRate():: std.objectHas(serviceLevelIndicator, 'errorRate'),

    hasToolingLinks()::
      std.objectHasAll(serviceLevelIndicator, 'toolingLinks'),

    getToolingLinks()::
      if self.hasToolingLinks() then
        self.toolingLinks
      else
        [],

    renderToolingLinks()::
      toolingLinks.renderLinks(self.getToolingLinks()),

    hasFeatureCategoryFromSourceMetrics()::
      std.objectHas(serviceLevelIndicator, 'featureCategory') &&
      serviceLevelIndicator.featureCategory == featureCategoryFromSourceMetrics,

    hasStaticFeatureCategory()::
      std.objectHas(serviceLevelIndicator, 'featureCategory') &&
      serviceLevelIndicator.featureCategory != featureCategoryNotOwned &&
      !self.hasFeatureCategoryFromSourceMetrics(),

    hasFeatureCategory()::
      self.hasStaticFeatureCategory() || self.hasFeatureCategoryFromSourceMetrics(),

    hasDependencies()::
      std.length(self.dependsOn) > 0,

    staticFeatureCategoryLabels()::
      if self.hasStaticFeatureCategory() then
        { feature_category: serviceLevelIndicator.featureCategory }
      else
        {},

    // Generate recording rules for apdex
    generateApdexRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels)::
      if self.hasApdex() && !isUpscalingTarget(self, burnRate) then
        local upscaleLabels = getUpscaleLabels(self, burnRate);
        local allStaticLabels = recordingRuleStaticLabels + serviceLevelIndicator.staticLabels + upscaleLabels;
        local aggregationLabelsWithoutStaticLabels = filterStaticLabelsFromAggregationLabels(aggregationLabels, allStaticLabels);

        local apdexSuccessRateRecordingRuleName = aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate);
        local apdexWeightRecordingRuleName = aggregationSet.getApdexWeightMetricForBurnRate(burnRate);

        local apdexSuccessRateExpr = serviceLevelIndicator.apdex.apdexSuccessRateQuery(
          aggregationLabels=aggregationLabelsWithoutStaticLabels,
          selector={},
          rangeInterval=burnRate
        );

        local apdexWeightExpr = serviceLevelIndicator.apdex.apdexWeightQuery(
          aggregationLabels=aggregationLabelsWithoutStaticLabels,
          selector={},
          rangeInterval=burnRate
        );

        (
          if apdexSuccessRateRecordingRuleName != null then
            [{
              record: apdexSuccessRateRecordingRuleName,
              labels: allStaticLabels,
              expr: apdexSuccessRateExpr,
            }]
          else
            []
        )
        +
        (
          if apdexWeightRecordingRuleName != null then
            [{
              record: apdexWeightRecordingRuleName,
              labels: allStaticLabels,
              expr: apdexWeightExpr,
            }]
          else
            []
        )
      else
        [],

    // Generate recording rules for request rate
    generateRequestRateRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels)::
      if !isUpscalingTarget(self, burnRate) then
        local upscaleLabels = getUpscaleLabels(self, burnRate);
        local requestRateRecordingRuleName = aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=true);
        local allStaticLabels = recordingRuleStaticLabels + serviceLevelIndicator.staticLabels + upscaleLabels;

        [{
          record: requestRateRecordingRuleName,
          labels: allStaticLabels,
          expr: serviceLevelIndicator.requestRate.aggregatedRateQuery(
            aggregationLabels=filterStaticLabelsFromAggregationLabels(aggregationLabels, allStaticLabels),
            selector={},
            rangeInterval=burnRate
          ),
        }]
      else
        [],

    // Generate recording rules for error rate
    generateErrorRateRecordingRules(burnRate, aggregationSet, aggregationLabels, recordingRuleStaticLabels)::
      if self.hasErrorRate() && !isUpscalingTarget(self, burnRate) then
        local upscaleLabels = getUpscaleLabels(self, burnRate);
        local allStaticLabels = recordingRuleStaticLabels + serviceLevelIndicator.staticLabels + upscaleLabels;
        local requestRateRecordingRuleName = aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=true);
        local errorRateRecordingRuleName = aggregationSet.getErrorRateMetricForBurnRate(burnRate, required=true);
        local filteredAggregationLabels = filterStaticLabelsFromAggregationLabels(aggregationLabels, allStaticLabels);

        local expr = serviceLevelIndicator.errorRate.aggregatedRateQuery(
          aggregationLabels=filterStaticLabelsFromAggregationLabels(aggregationLabels, allStaticLabels),
          selector={},
          rangeInterval=burnRate
        );

        [{
          record: errorRateRecordingRuleName,
          labels: allStaticLabels,
          expr: |||
            (
              %(expr)s
            )
            or
            (
              0 * group by(%(filteredAggregationLabels)s) (
                %(requestRateRecordingRuleName)s{%(allStaticLabels)s}
              )
            )
          ||| % {
            expr: strings.indent(expr, 2),
            filteredAggregationLabels: aggregations.serialize(filteredAggregationLabels),
            requestRateRecordingRuleName: requestRateRecordingRuleName,
            allStaticLabels: selectors.serializeHash(allStaticLabels),
          },
        }]
      else
        [],
  };

{
  serviceLevelIndicatorDefinition(serviceLevelIndicator)::
    {
      initServiceLevelIndicatorWithName(sliName, inheritedDefaults)::
        serviceLevelIndicatorDefinition(sliName, validateAndApplySLIDefaults(sliName, serviceLevelIndicator, inheritedDefaults)),
    },
  featureCategoryFromSourceMetrics: featureCategoryFromSourceMetrics,
  featureCategoryNotOwned: featureCategoryNotOwned,
}
