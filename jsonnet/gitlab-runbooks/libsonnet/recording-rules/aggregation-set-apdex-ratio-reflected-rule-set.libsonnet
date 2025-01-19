local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

// Returns a direct apdex ratio transformation expression or null if one cannot be generated because the source
// does not contain the correct recording rules
local getApdexRatioExpression(aggregationSet, burnRate) =
  local apdexSuccessRateMetric = aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate, required=false);
  local apdexWeightMetric = aggregationSet.getApdexWeightMetricForBurnRate(burnRate, required=false);

  if apdexSuccessRateMetric != null && apdexWeightMetric != null then
    |||
      sum by (%(aggregationLabels)s) (
        %(apdexSuccessRateMetric)s{%(selector)s}
      )
      /
      sum by (%(aggregationLabels)s) (
        %(apdexWeightMetric)s{%(selector)s}
      )
    ||| % {
      aggregationLabels: aggregations.serialize(aggregationSet.labels),
      selector: selectors.serializeHash(aggregationSet.selector),
      apdexSuccessRateMetric: apdexSuccessRateMetric,
      apdexWeightMetric: apdexWeightMetric,
    }
  else null;

{
  // Aggregates apdex scores internally within an aggregation set
  // intended to be used when all metrics are stored within a single
  // Prometheus instance, with no Thanos layer
  aggregationSetApdexRatioReflectedRuleSet(aggregationSet, burnRate)::
    local apdexRatioMetric = aggregationSet.getApdexRatioMetricForBurnRate(burnRate);

    (
      if apdexRatioMetric == null then
        []
      else
        [{
          record: apdexRatioMetric,
          expr: getApdexRatioExpression(aggregationSet, burnRate),
        }]
    ),
}
