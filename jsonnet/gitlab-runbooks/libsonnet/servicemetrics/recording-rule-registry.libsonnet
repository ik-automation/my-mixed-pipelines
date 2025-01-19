//
// Recording Rule Registry
//
// This library deals with resolving expressions that can use recording rules.
// Given a PromQL expression, and the recording rule registry (from `metric-label-registry.libsonnet`)
// It will convert the expression into an equivalent expression that uses a recording rule,
// if possible.
//
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsLabelRegistry = import 'servicemetrics/metric-label-registry.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local standardEnvironmentLabels = std.set(['environment', 'type', 'tier', 'stage', 'shard']);

/**
 * This defines a list of labels which, if used in an expression, but
 * are not used in the recording rule definition, can be safely ignored.
 *
 * This is useful when labels are applied after the recording rule is evaluated.
 * Examples could be prometheus instance-wide labels or labels applied in thanos
 */
local ignoredRecordingRuleResolutionLabels = std.set(['env', 'monitor']);

// Collect recordingRuleMetrics for all services
local metricsWithRecordingRules = std.foldl(
  function(memo, service)
    if std.objectHas(service, 'recordingRuleMetrics') then
      std.setUnion(memo, std.set(service.recordingRuleMetrics))
    else
      memo,
  metricsCatalog.services,
  []
);

local supportsLabelsBurnRateAndSelector(metricName, requiredAggregationLabels, burnRate, selector) =
  if std.setMember(metricName, metricsWithRecordingRules) then
    if std.type(selector) == 'object' then
      local allRequiredLabels = std.set(requiredAggregationLabels + selectors.getLabels(selector));
      local allRequiredLabelsExcludingIgnored = std.setDiff(allRequiredLabels, ignoredRecordingRuleResolutionLabels);

      local recordingRuleLabels = metricsLabelRegistry.lookupLabelsForMetricName(metricName);
      local supportsBurnRate = metricsLabelRegistry.supportsBurnRateForMetricName(metricName, burnRate);

      if supportsBurnRate then
        local allRequiredLabelsMinusStandards = std.setDiff(allRequiredLabelsExcludingIgnored, standardEnvironmentLabels);

        local missingLabels = std.setDiff(allRequiredLabelsMinusStandards, recordingRuleLabels);

        // Check that allRequiredLabels is a subset of recordingRuleLabels
        if missingLabels == [] then
          true
        else
          std.trace('Unable to use recording rule for ' + metricName + '. Missing labels: ' + missingLabels + ', requiredAggregationLabels=' + requiredAggregationLabels + ', selector=' + selector, false)
      else
        std.trace('Unable to use recording rule for ' + metricName + '. Unsupported burn rate: ' + burnRate + ', supportedBurnRates=' + metricsLabelRegistry.getSupportedBurnRatesForMetricName(metricName), false)
    else
      std.assertEqual(selector, { __assert__: 'selector should be a selector hash' })
  else
    false;

local splitAggregationString(aggregationLabelsString) =
  if aggregationLabelsString == '' then
    []
  else
    [
      std.stripChars(str, ' \n\t')
      for str in std.split(aggregationLabelsString, ',')
    ];

local resolveRecordingRuleFor(metricName, requiredAggregationLabels, selector, duration) =
  // Recording rules can't handle `$__interval` variable ranges, so always resolve these as 5m
  local durationWithRecordingRule = if duration == '$__interval' then '5m' else duration;

  local requiredAggregationLabelsArray = if std.isArray(requiredAggregationLabels) then
    requiredAggregationLabels
  else
    splitAggregationString(requiredAggregationLabels);

  if supportsLabelsBurnRateAndSelector(metricName, requiredAggregationLabelsArray, durationWithRecordingRule, selector) then
    'sli_aggregations:%(metricName)s_rate%(duration)s{%(selector)s}' % {
      metricName: metricName,
      duration: durationWithRecordingRule,
      selector: selectors.serializeHash(selector),
    }
  else
    null;

{
  // Finds an appropriate recording rule expression
  // or returns null if the labels don't match or the metric doesn't have
  // a recording rule
  resolveRecordingRuleFor(
    aggregationFunction='sum',
    aggregationLabels=[],
    rangeVectorFunction='rate',
    metricName=null,
    rangeInterval='5m',
    selector={},
  )::
    // Currently only support sum/rate recording rules,
    // possibly support other options in future
    if rangeVectorFunction != 'rate' then
      null
    else
      local resolvedRecordingRule = resolveRecordingRuleFor(metricName, aggregationLabels, selector, rangeInterval);

      if resolvedRecordingRule == null then
        null
      else
        if aggregationFunction == 'sum' then
          aggregations.aggregateOverQuery(aggregationFunction, aggregationLabels, resolvedRecordingRule)
        else if aggregationFunction == null then
          resolvedRecordingRule
        else
          null,

  recordingRuleExpressionFor(metricName, rangeInterval)::
    local aggregationLabels = metricsLabelRegistry.lookupLabelsForMetricName(metricName);
    local allRequiredLabelsPlusStandards = std.setUnion(aggregationLabels, standardEnvironmentLabels);
    local query = 'rate(%(metricName)s[%(rangeInterval)s])' % {
      metricName: metricName,
      rangeInterval: rangeInterval,
    };
    aggregations.aggregateOverQuery('sum', allRequiredLabelsPlusStandards, query),

  recordingRuleNameFor(metricName, rangeInterval)::
    'sli_aggregations:%(metricName)s_rate%(rangeInterval)s' % {
      metricName: metricName,
      rangeInterval: rangeInterval,
    },

  recordingRuleForMetricAtBurnRate(metricName, rangeInterval)::
    metricsLabelRegistry.supportsBurnRateForMetricName(metricName, rangeInterval),

}
