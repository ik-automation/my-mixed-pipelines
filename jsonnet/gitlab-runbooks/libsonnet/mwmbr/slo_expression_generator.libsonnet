local multiburn_factors = import './multiburn_factors.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local joins = import 'promql/joins.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  termGenerators:: {
    fixed(thresholdValue)::
      function(metric, metricSelector, comparator, factor, invertedForApdex=false)
        local formatConfig = {
          metric: metric,
          inverseThresholdValue: 1 - thresholdValue,
          thresholdValue: thresholdValue,
          metricSelector: selectors.serializeHash(metricSelector),
          comparator: comparator,
          factor: factor,
        };

        if invertedForApdex then
          |||
            %(metric)s{%(metricSelector)s}
            %(comparator)s (1 - %(factor)g * %(inverseThresholdValue)f)
          ||| % formatConfig
        else
          |||
            %(metric)s{%(metricSelector)s}
            %(comparator)s (%(factor)g * %(thresholdValue)f)
          ||| % formatConfig,

    metricThreshold(thresholdSLOMetricAggregationLabels, thresholdSLOMetricName, sloSelector)::
      function(metric, metricSelector, comparator, factor, invertedForApdex=false)
        local formatConfig = {
          metric: metric,
          thresholdSLOMetricAggregationLabels: aggregations.serialize(thresholdSLOMetricAggregationLabels),
          thresholdSLOMetricName: thresholdSLOMetricName,
          sloSelector: selectors.serializeHash(sloSelector),
          metricSelector: selectors.serializeHash(metricSelector),
          comparator: comparator,
          factor: factor,
        };

        if invertedForApdex then
          |||
            %(metric)s{%(metricSelector)s}
            %(comparator)s on(%(thresholdSLOMetricAggregationLabels)s) group_left()
            (
              1 -
              (
                %(factor)g * (1 - avg by (%(thresholdSLOMetricAggregationLabels)s) (%(thresholdSLOMetricName)s{%(sloSelector)s}))
              )
            )
          ||| % formatConfig
        else
          |||
            %(metric)s{%(metricSelector)s}
            %(comparator)s on(%(thresholdSLOMetricAggregationLabels)s) group_left()
            (
              %(factor)g * (
                avg by (%(thresholdSLOMetricAggregationLabels)s) (%(thresholdSLOMetricName)s{%(sloSelector)s})
              )
            )
          ||| % formatConfig,
  },

  // Metric lookups strategy will resolve the metric name for a given window duration
  metricLookups:: {
    // Lookup apdex metric name from aggregation set
    apdex()::
      function(aggregationSet, windowDuration)
        aggregationSet.getApdexRatioMetricForBurnRate(windowDuration, required=true),

    // Lookup error rate metric name from aggregation set
    errorRate()::
      function(aggregationSet, windowDuration)
        aggregationSet.getErrorRatioMetricForBurnRate(windowDuration, required=true),
  },

  expressionGenerator(
    aggregationSet,
    metricSelectorHash,
    termGenerator,
    metricLookup,
    windows=['1h', '6h'],  // Sets of windows in this SLO expression, identified by longWindow duration
    isApdexExpression=false,
    sloExpressionComparator=if isApdexExpression then '<' else '>',
    termJoinOperator='and',
    windowPairJoinOperator='or',
  )::
    local metricSelector = selectors.merge(aggregationSet.selector, metricSelectorHash);

    local windowPairExpressions = std.map(
      function(longWindow)
        local param = multiburn_factors.getParametersForLongWindow(longWindow);
        local shortWindow = param.shortWindow;
        local factor = multiburn_factors.errorBudgetFactorFor(longWindow);
        local metricLong = metricLookup(aggregationSet, longWindow);
        local metricShort = metricLookup(aggregationSet, shortWindow);
        local termExpressions = [
          termGenerator(metric=metricLong, metricSelector=metricSelector, comparator=sloExpressionComparator, factor=factor, invertedForApdex=isApdexExpression),
          termGenerator(metric=metricShort, metricSelector=metricSelector, comparator=sloExpressionComparator, factor=factor, invertedForApdex=isApdexExpression),
        ];
        joins.join(termJoinOperator, termExpressions, wrapTerms=true),
      windows
    );

    joins.join(windowPairJoinOperator, windowPairExpressions, wrapTerms=false),
}
