local intervalForDuration = import './interval-for-duration.libsonnet';
local recordingRuleRegistry = import './recording-rule-registry.libsonnet';
local recordingRules = import 'recording-rules/recording-rules.libsonnet';

local recordingRuleGroupsForServiceForBurnRate(serviceDefinition, componentAggregationSet, nodeAggregationSet, burnRate) =
  local rulesetGenerators =
    [
      recordingRules.sliRecordingRulesSetGenerator(burnRate, recordingRuleRegistry),
      recordingRules.componentMetricsRuleSetGenerator(
        burnRate=burnRate,
        aggregationSet=componentAggregationSet
      ),
      recordingRules.extraRecordingRuleSetGenerator(burnRate),
    ]
    +
    (
      if serviceDefinition.nodeLevelMonitoring then
        [
          recordingRules.componentMetricsRuleSetGenerator(
            burnRate=burnRate,
            aggregationSet=nodeAggregationSet,
          ),
        ]
      else
        []
    );

  {
    name: 'Component-Level SLIs: %s - %s burn-rate' % [serviceDefinition.type, burnRate],  // TODO: rename to "Prometheus Intermediate Metrics"
    interval: intervalForDuration.intervalForDuration(burnRate),
    rules:
      std.flatMap(
        function(r) r.generateRecordingRulesForService(serviceDefinition),
        rulesetGenerators
      ),
  };

local featureCategoryRecordingRuleGroupsForService(serviceDefinition, aggregationSet, burnRate) =
  local generator = recordingRules.componentMetricsRuleSetGenerator(burnRate, aggregationSet);
  local indicators = std.filter(function(indicator) indicator.hasFeatureCategory(), serviceDefinition.listServiceLevelIndicators());
  {
    name: 'Prometheus Intermediate Metrics per feature: %s - burn-rate %s' % [serviceDefinition.type, burnRate],
    rules: generator.generateRecordingRulesForService(serviceDefinition, serviceLevelIndicators=indicators),
  };

{
  /**
   * Generate all source recording rule groups for a specific service.
   * These are the first level aggregation, for normalizing source metrics
   * into a consistent format
   */
  recordingRuleGroupsForService(serviceDefinition, componentAggregationSet, nodeAggregationSet)::
    local componentMappingRuleSetGenerator = recordingRules.componentMappingRuleSetGenerator();

    local burnRates = componentAggregationSet.getBurnRates();

    [
      recordingRuleGroupsForServiceForBurnRate(serviceDefinition, componentAggregationSet, nodeAggregationSet, burnRate)
      for burnRate in burnRates
    ]
    +
    // Component mappings are static recording rules which help
    // determine whether a component is being monitored. This helps
    // prevent spurious alerts when a component is decommissioned.
    [{
      name: 'Component mapping: %s' % [serviceDefinition.type],
      interval: '1m',  // TODO: we could probably extend this out to 5m
      rules:
        componentMappingRuleSetGenerator.generateRecordingRulesForService(serviceDefinition),
    }],

  featureCategoryRecordingRuleGroupsForService(serviceDefinition, aggregationSet)::
    [
      featureCategoryRecordingRuleGroupsForService(serviceDefinition, aggregationSet, burnRate)
      for burnRate in aggregationSet.getBurnRates()
    ],

}
