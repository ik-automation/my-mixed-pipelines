local mwmbrExpression = import 'mwmbr/expression.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;

local otherThresholdRules(threshold) =
  [{
    record: threshold.errorHealth,
    expr: mwmbrExpression.errorHealthExpression(
      aggregationSet=aggregationSets.serviceSLIs,
      metricSelectorHash={},
      thresholdSLOMetricName=threshold.errorSLO,
      thresholdSLOMetricAggregationLabels=['type', 'tier'],
    ),
  }, {
    record: threshold.apdexHealth,
    expr: mwmbrExpression.apdexHealthExpression(
      aggregationSet=aggregationSets.serviceSLIs,
      metricSelectorHash={},
      thresholdSLOMetricName=threshold.apdexSLO,
      thresholdSLOMetricAggregationLabels=['type', 'tier'],
    ),
  }, {
    record: threshold.aggregateServiceHealth,
    expr: |||
      min without (sli_type) (
        label_replace(%(apdexHealth)s{monitor="global"}, "sli_type", "apdex", "", "")
        or
        label_replace(%(errorHealth)s{monitor="global"}, "sli_type", "errors", "", "")
      )
    ||| % { apdexHealth: threshold.apdexHealth, errorHealth: threshold.errorHealth },
  }, {
    record: threshold.aggregateStageHealth,
    expr: |||
      min by (environment, env, stage) (
        %(aggregateServiceHealth)s{monitor="global"}
      )
    ||| % { aggregateServiceHealth: threshold.aggregateServiceHealth },
  }];

{
  thresholdHealthRuleSet(name):: otherThresholdRules(name),
}
