local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  aggregationSetErrorRatioReflectedRuleSet(aggregationSet, burnRate)::
    local errorRatioMetric = aggregationSet.getErrorRatioMetricForBurnRate(burnRate);

    if errorRatioMetric == null then
      []
    else
      local opsRateMetric = aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=true);
      local errorRateMetric = aggregationSet.getErrorRateMetricForBurnRate(burnRate, required=true);
      local aggregationLabels = aggregations.serialize(aggregationSet.labels);

      local formatConfig = {
        burnRate: burnRate,
        opsRateMetric: opsRateMetric,
        errorRateMetric: errorRateMetric,
        selector: selectors.serializeHash(aggregationSet.selector),
        aggregationLabels: aggregationLabels,
      };

      local directExpr = |||
        sum by (%(aggregationLabels)s) (
          %(errorRateMetric)s{%(selector)s}
        )
        /
        sum by (%(aggregationLabels)s) (
          %(opsRateMetric)s{%(selector)s}
        )
      ||| % formatConfig;

      [{
        record: errorRatioMetric,
        expr: directExpr,
      }],
}
