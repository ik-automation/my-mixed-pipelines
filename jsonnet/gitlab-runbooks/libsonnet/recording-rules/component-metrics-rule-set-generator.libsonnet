// Get the set of static labels for an aggregation
// The feature category will be included if the aggregation needs it and the SLI has
// a feature category
local staticLabelsForAggregation(serviceDefinition, sliDefinition, aggregationLabels) =
  local baseLabels = {
    tier: serviceDefinition.tier,
    type: serviceDefinition.type,
    component: sliDefinition.name,
  };
  if sliDefinition.hasStaticFeatureCategory() && std.member(aggregationLabels, 'feature_category')
  then baseLabels + sliDefinition.staticFeatureCategoryLabels()
  else baseLabels;

// Generates apdex weight recording rules for a component definition

local generateApdexRules(burnRate, aggregationSet, aggregationLabels, sliDefinition, recordingRuleStaticLabels) =
  local apdexSuccessRateRecordingRuleName = aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate);
  local apdexWeightRecordingRuleName = aggregationSet.getApdexWeightMetricForBurnRate(burnRate);

  if apdexSuccessRateRecordingRuleName != null || apdexWeightRecordingRuleName != null then
    sliDefinition.generateApdexRecordingRules(
      burnRate=burnRate,
      aggregationSet=aggregationSet,
      aggregationLabels=aggregationLabels,
      recordingRuleStaticLabels=recordingRuleStaticLabels
    )
  else
    [];

local generateRequestRateRules(burnRate, aggregationSet, aggregationLabels, sliDefinition, recordingRuleStaticLabels) =
  local requestRateRecordingRuleName = aggregationSet.getOpsRateMetricForBurnRate(burnRate);
  if requestRateRecordingRuleName != null then
    sliDefinition.generateRequestRateRecordingRules(
      burnRate=burnRate,
      aggregationSet=aggregationSet,
      aggregationLabels=aggregationLabels,
      recordingRuleStaticLabels=recordingRuleStaticLabels
    )
  else
    [];

local generateErrorRateRules(burnRate, aggregationSet, aggregationLabels, sliDefinition, recordingRuleStaticLabels) =
  local errorRateRecordingRuleName = aggregationSet.getErrorRateMetricForBurnRate(burnRate);
  if errorRateRecordingRuleName != null then
    sliDefinition.generateErrorRateRecordingRules(
      burnRate=burnRate,
      aggregationSet=aggregationSet,
      aggregationLabels=aggregationLabels,
      recordingRuleStaticLabels=recordingRuleStaticLabels
    )
  else
    [];

// Generates the recording rules given a component definition
local generateRecordingRulesForComponent(burnRate, aggregationSet, serviceDefinition, sliDefinition, aggregationLabels) =
  local recordingRuleStaticLabels = staticLabelsForAggregation(serviceDefinition, sliDefinition, aggregationLabels);

  std.flatMap(
    function(generator) generator(burnRate=burnRate, aggregationSet=aggregationSet, aggregationLabels=aggregationLabels, sliDefinition=sliDefinition, recordingRuleStaticLabels=recordingRuleStaticLabels),
    [
      generateApdexRules,
      generateRequestRateRules,
      generateErrorRateRules,  // Error rates should always go after request rates as we have a fallback clause which relies on request rate existing
    ]
  );

{
  // This component metrics ruleset applies the key metrics recording rules for
  // each component in the metrics catalog
  componentMetricsRuleSetGenerator(
    burnRate,
    aggregationSet,
  )::
    {
      // Generates the recording rules given a service definition
      generateRecordingRulesForService(serviceDefinition, serviceLevelIndicators=serviceDefinition.listServiceLevelIndicators())::
        std.flatMap(
          function(sliDefinition) generateRecordingRulesForComponent(
            burnRate=burnRate,
            aggregationSet=aggregationSet,
            serviceDefinition=serviceDefinition,
            sliDefinition=sliDefinition,
            aggregationLabels=aggregationSet.labels,
          ),
          serviceLevelIndicators,
        ),
    },

}
