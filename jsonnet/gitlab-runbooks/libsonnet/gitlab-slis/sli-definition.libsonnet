local validator = import 'utils/validator.libsonnet';
local rateMetric = (import 'servicemetrics/rate.libsonnet').rateMetric;
local rateApdex = (import 'servicemetrics/rate_apdex.libsonnet').rateApdex;
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';
local serviceLevelIndicatorDefinition = import 'servicemetrics/service_level_indicator_definition.libsonnet';
local misc = import 'utils/misc.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';


// When adding new kinds, please update the metrics catalog to add recording
// names to the aggregation sets and recording rules
local apdexKind = 'apdex';
local errorRateKind = 'error_rate';
local validKinds = [apdexKind, errorRateKind];

local validateFeatureCategory(value) =
  if value == serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics then
    true
  else if value != null then
    std.objectHas(stages.featureCategoryMap, value)
  else
    false;

local sliValidator = validator.new({
  name: validator.string,
  significantLabels: validator.array,
  description: validator.string,
  kinds: validator.and(
    validator.validator(function(values) std.isArray(values) && std.length(values) > 0, 'must be present'),
    validator.validator(function(values) misc.all(function(v) std.member(validKinds, v), values), 'only %s are supported' % [std.join(', ', validKinds)])
  ),
  featureCategory: validator.validator(validateFeatureCategory, 'please specify a known feature category or include `feature_category` as a significant label'),
});

local rateQueryFunction(sli, counter) =
  function(selector={}, aggregationLabels=[], rangeInterval)
    local labels = std.set(aggregationLabels + sli.significantLabels);
    rateMetric(sli[counter], selector).aggregatedRateQuery(labels, selector, rangeInterval);

local applyDefaults(definition) = {
  featureCategory: if std.member(definition.significantLabels, 'feature_category') then
    serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics,
  hasApdex():: std.member(definition.kinds, apdexKind),
  hasErrorRate():: std.member(definition.kinds, errorRateKind),
} + definition;

local validateAndApplyDefaults(definition) =
  local definitionWithDefaults = applyDefaults(definition);
  local sli = sliValidator.assertValid(definitionWithDefaults);

  sli {
    [if sli.hasApdex() then 'apdexTotalCounterName']: 'gitlab_sli_%s_apdex_total' % [self.name],
    [if sli.hasApdex() then 'apdexSuccessCounterName']: 'gitlab_sli_%s_apdex_success_total' % [self.name],
    [if sli.hasErrorRate() then 'errorTotalCounterName']: 'gitlab_sli_%s_total' % [self.name],
    [if sli.hasErrorRate() then 'errorCounterName']: 'gitlab_sli_%s_error_total' % [self.name],
    totalCounterName: if sli.hasErrorRate() then self.errorTotalCounterName else self.apdexTotalCounterName,

    [if sli.hasApdex() then 'aggregatedApdexOperationRateQuery']:: rateQueryFunction(self, 'apdexTotalCounterName'),
    [if sli.hasApdex() then 'aggregatedApdexSuccessRateQuery']:: rateQueryFunction(self, 'apdexSuccessCounterName'),
    [if sli.hasErrorRate() then 'aggregatedOperationRateQuery']:: rateQueryFunction(self, 'errorTotalCounterName'),
    [if sli.hasErrorRate() then 'aggregatedErrorRateQuery']:: rateQueryFunction(self, 'errorCounterName'),

    recordingRuleMetrics: std.filter(misc.isPresent, [
      misc.dig(self, ['apdexTotalCounterName']),
      misc.dig(self, ['apdexSuccessCounterName']),
      misc.dig(self, ['errorTotalCounterName']),
      misc.dig(self, ['errorCounterName']),
    ]),

    inRecordingRuleRegistry: misc.all(
      function(metricName)
        recordingRuleRegistry.resolveRecordingRuleFor(metricName=metricName) != null,
      self.recordingRuleMetrics,
    ),

    local parent = self,

    generateServiceLevelIndicator(extraSelector):: {
      userImpacting: true,
      featureCategory: sli.featureCategory,

      description: parent.description,

      requestRate: rateMetric(parent.totalCounterName, extraSelector),
      significantLabels: parent.significantLabels,

      [if parent.hasApdex() then 'apdex']: rateApdex(parent.apdexSuccessCounterName, parent.apdexTotalCounterName, extraSelector),
      [if parent.hasErrorRate() then 'errorRate']: rateMetric(parent.errorCounterName, extraSelector),
    },
  };

{
  apdexKind: apdexKind,
  errorRateKind: errorRateKind,

  new(definition):: validateAndApplyDefaults(definition),

  // For testing only
  _sliValidator:: sliValidator,
  _applyDefaults:: applyDefaults,
}
