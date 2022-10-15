local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  // A rate that is precalcuated, not stored as a counter
  // Some metrics from stackdriver are presented in this form
  gaugeMetric(
    gauge,
    selector=null
  ):: {
    local baseSelector = selector,  // alias

    aggregatedRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
      local mergedSelectors = selectors.without(selectors.merge(baseSelector, selector), withoutLabels);
      local query = 'avg_over_time(%(gauge)s{%(selectors)s}[%(rangeInterval)s])' % {
        gauge: gauge,
        selectors: selectors.serializeHash(mergedSelectors),
        rangeInterval: rangeInterval,
      };

      aggregations.aggregateOverQuery('sum', aggregationLabels, query),
  },
}
