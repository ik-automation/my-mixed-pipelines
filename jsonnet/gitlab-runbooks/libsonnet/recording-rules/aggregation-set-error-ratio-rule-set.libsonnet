local helpers = import './helpers.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local strings = import 'utils/strings.libsonnet';

local getDirectExpr(sourceAggregationSet, targetAggregationSet, burnRate) =
  local targetOpsRateMetric = targetAggregationSet.getOpsRateMetricForBurnRate(burnRate);
  local targetErrorRateMetric = targetAggregationSet.getErrorRateMetricForBurnRate(burnRate);
  local targetAggregationLabels = aggregations.serialize(targetAggregationSet.labels);
  local sourceSelector = selectors.serializeHash(sourceAggregationSet.selector);

  local formatConfig = {
    burnRate: burnRate,
    targetOpsRateMetric: targetOpsRateMetric,
    targetErrorRateMetric: targetErrorRateMetric,
    targetSelector: selectors.serializeHash(targetAggregationSet.selector),
    sourceSelector: sourceSelector,
    aggregationFilterExpr: helpers.aggregationFilterExpr(targetAggregationSet),
  };

  local sourceErrorRateMetric = sourceAggregationSet.getErrorRateMetricForBurnRate(burnRate, required=true);

  local errorRateExpr = |||
    (%(sourceErrorRateMetric)s{%(sourceSelector)s} >= 0)%(aggregationFilterExpr)s
  ||| % formatConfig {
    sourceErrorRateMetric: sourceErrorRateMetric,
  };

  local sourceOpsRateMetric = sourceAggregationSet.getOpsRateMetricForBurnRate(burnRate);
  local opsRateExpr = |||
    (%(sourceOpsRateMetric)s{%(sourceSelector)s} >= 0)%(aggregationFilterExpr)s
  ||| % formatConfig {
    sourceOpsRateMetric: sourceOpsRateMetric,
  };

  |||
    sum by (%(targetAggregationLabels)s)(
      %(errorRateExpr)s
    )
    /
    sum by (%(targetAggregationLabels)s)(
      %(opsRateExpr)s
      and
      %(errorRateExpr)s
    )
  ||| % {
    targetAggregationLabels: targetAggregationLabels,
    errorRateExpr: strings.chomp(errorRateExpr),
    opsRateExpr: strings.chomp(opsRateExpr),
  };

{
  aggregationSetErrorRatioRuleSet(sourceAggregationSet, targetAggregationSet, burnRate)::
    local targetErrorRatioMetric = targetAggregationSet.getErrorRatioMetricForBurnRate(burnRate);

    if targetErrorRatioMetric == null then
      []
    else
      local sourceHasBurnRate = std.member(sourceAggregationSet.getBurnRates(), burnRate);
      local directExpr = if sourceHasBurnRate then
        getDirectExpr(sourceAggregationSet, targetAggregationSet, burnRate);
      [{
        record: targetErrorRatioMetric,
        expr: helpers.combinedErrorRatioExpression(sourceAggregationSet, targetAggregationSet, burnRate, directExpr),
      }],
}
