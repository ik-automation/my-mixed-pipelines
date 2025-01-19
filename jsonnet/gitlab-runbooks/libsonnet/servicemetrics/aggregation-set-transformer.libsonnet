local recordingRules = import 'recording-rules/recording-rules.libsonnet';
local intervalForDuration = import 'servicemetrics/interval-for-duration.libsonnet';

local generateRecordingRules(sourceAggregationSet, targetAggregationSet, burnRates) =
  std.flatMap(
    function(burnRate)
      // Operation rate and Error Rate
      recordingRules.aggregationSetRateRuleSet(sourceAggregationSet=sourceAggregationSet, targetAggregationSet=targetAggregationSet, burnRate=burnRate)
      +
      // Error Ratio
      recordingRules.aggregationSetErrorRatioRuleSet(sourceAggregationSet=sourceAggregationSet, targetAggregationSet=targetAggregationSet, burnRate=burnRate)
      +
      // Apdex Score and Apdex Weight and Apdex SuccessRate
      recordingRules.aggregationSetApdexRatioRuleSet(sourceAggregationSet=sourceAggregationSet, targetAggregationSet=targetAggregationSet, burnRate=burnRate),
    burnRates
  );

local generateReflectedRecordingRules(aggregationSet, burnRates) =
  std.flatMap(
    function(burnRate)
      // Error Ratio
      recordingRules.aggregationSetErrorRatioReflectedRuleSet(aggregationSet=aggregationSet, burnRate=burnRate)
      +
      // Apdex Score and Apdex Weight and Apdex SuccessRate
      recordingRules.aggregationSetApdexRatioReflectedRuleSet(aggregationSet=aggregationSet, burnRate=burnRate),
    burnRates
  );


local groupForSetAndType(aggregationSet, burnType) =
  {
    name: '%s (%s burn)' % [aggregationSet.name, burnType],
    interval: intervalForDuration.intervalByBurnType[burnType],
  };

local generateRecordingRuleGroups(sourceAggregationSet, targetAggregationSet, extrasForGroup={}) =
  local burnRatesByType = targetAggregationSet.getBurnRatesByType();
  std.map(
    function(burnType)
      groupForSetAndType(targetAggregationSet, burnType) {
        rules: generateRecordingRules(sourceAggregationSet, targetAggregationSet, burnRatesByType[burnType]),
      } + extrasForGroup,
    std.objectFields(burnRatesByType)
  );

local generateReflectedRecordingRuleGroups(aggregationSet, extrasForGroup={}) =
  local burnRatesByType = aggregationSet.getBurnRatesByType();
  std.map(
    function(burnType)
      groupForSetAndType(aggregationSet, burnType) {
        rules: generateReflectedRecordingRules(aggregationSet, burnRatesByType[burnType]),
      } + extrasForGroup,
    std.objectFields(burnRatesByType)
  );

{
  /**
   * Generates a set of recording rules to aggregate from a source aggregation set to a target aggregation set
   */
  generateRecordingRuleGroups:: generateRecordingRuleGroups,

  /**
   * When using Prometheus without Thanos, some recording rules are generated from the same
   * aggregation set -- specifically error ratios and apdex ratios. These recording rules
   * should not be used in two-tier aggregation sets.
   */
  generateReflectedRecordingRuleGroups:: generateReflectedRecordingRuleGroups,

}
