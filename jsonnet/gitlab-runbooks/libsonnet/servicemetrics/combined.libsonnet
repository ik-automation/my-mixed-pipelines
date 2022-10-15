local aggregations = import 'promql/aggregations.libsonnet';
local strings = import 'utils/strings.libsonnet';

// Merge two hashes of the form { key: set },
local merge(h1, h2) =
  local folderFunc = function(memo, k)
    if std.objectHas(memo, k) then
      memo {
        [k]: std.setUnion(memo[k], h2[k]),
      }
    else
      memo {
        [k]: h2[k],
      };

  std.foldl(folderFunc, std.objectFields(h2), h1);

local orJoin(queries) =
  std.join('\nor\n', queries);

local wrapForUniqueness(index, query) =
  'label_replace(%(query)s, "_c", "%(index)d", "", "")' % {
    query: query,
    index: index,
  };

local generateRateQuery(c, selector, rangeInterval, withoutLabels) =
  local rateQueries = std.mapWithIndex(function(index, metric) wrapForUniqueness(index, metric.rateQuery(selector, rangeInterval, withoutLabels=withoutLabels)), c.metrics);
  orJoin(rateQueries);

local generateIncreaseQuery(c, selector, rangeInterval, withoutLabels) =
  local increaseQueries = std.mapWithIndex(function(index, metric) wrapForUniqueness(index, metric.increaseQuery(selector, rangeInterval, withoutLabels=withoutLabels)), c.metrics);
  orJoin(increaseQueries);

local generateApdexNumeratorQuery(c, aggregationLabels, selector, rangeInterval, withoutLabels) =
  local numeratorQueries = std.mapWithIndex(function(index, metric) wrapForUniqueness(index, metric.apdexSuccessRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels)), c.metrics);
  aggregations.aggregateOverQuery('sum', aggregationLabels, orJoin(numeratorQueries));

local generateApdexQuery(c, aggregationLabels, selector, rangeInterval, withoutLabels) =
  local aggregatedNumerators = generateApdexNumeratorQuery(c, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels);
  local denominatorQueries = std.mapWithIndex(function(index, metric) wrapForUniqueness(index, metric.apdexQuery(aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels)), c.metrics);

  local aggregatedDenominators = aggregations.aggregateOverQuery('sum', aggregationLabels, orJoin(denominatorQueries));

  |||
    %(aggregatedNumerators)s
    /
    (
      %(aggregatedDenominators)s > 0
    )
  ||| % {
    aggregatedNumerators: strings.chomp(aggregatedNumerators),
    aggregatedDenominators: strings.indent(strings.chomp(aggregatedDenominators), 2),
  };

local generateApdexWeightQuery(c, aggregationLabels, selector, rangeInterval, withoutLabels) =
  local apdexWeightQueries = std.mapWithIndex(function(index, metric) wrapForUniqueness(index, metric.apdexWeightQuery(aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels)), c.metrics);
  aggregations.aggregateOverQuery('sum', aggregationLabels, orJoin(apdexWeightQueries));

local generateApdexPercentileLatencyQuery(c, percentile, aggregationLabels, selector, rangeInterval, withoutLabels) =
  local rateQueries = std.map(function(i) i.apdexNumerator(selector, rangeInterval, histogramRates=true, withoutLabels=withoutLabels), c.metrics);
  local aggregationLabelsWithLe = aggregations.join([aggregationLabels, 'le']);

  local aggregatedRateQueries = aggregations.aggregateOverQuery('sum', aggregationLabelsWithLe, orJoin(rateQueries));

  |||
    histogram_quantile(
      %(percentile)f,
      %(aggregatedRateQuery)s
    )
  ||| % {
    percentile: percentile,
    aggregatedRateQuery: strings.indent(strings.chomp(aggregatedRateQueries), 2),
  };

// "combined" allows two counter metrics to be added together
// to generate a new metric value
{
  combined(
    metrics
  )::
    // If the combiner only includes a single metric, unwind it and just
    // delegate directly to the underlying metric
    if std.length(metrics) == 1 then
      metrics[0]
    else
      {
        metrics: metrics,
        // We use `combined(histogramApdex(), histogramApdex())` with diferent
        // thresholds to categorize different operations.
        // This allows us to still generate the `histogram_quantile` graphs on
        // service dashboards.
        [if std.objectHas(metrics[0], 'histogram') then 'histogram']: metrics[0].histogram,

        // This creates a rate query of the form
        // rate(....{<selector>}[<rangeInterval>])
        rateQuery(selector, rangeInterval, withoutLabels=[])::
          generateRateQuery(self, selector, rangeInterval, withoutLabels=withoutLabels),

        // This creates a increase query of the form
        // rate(....{<selector>}[<rangeInterval>])
        increaseQuery(selector, rangeInterval, withoutLabels=[])::
          generateIncreaseQuery(self, selector, rangeInterval, withoutLabels=withoutLabels),

        // This creates an aggregated rate query of the form
        // sum by(<aggregationLabels>) (...)
        aggregatedRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
          local query = generateRateQuery(self, selector, rangeInterval, withoutLabels=withoutLabels);
          aggregations.aggregateOverQuery('sum', aggregationLabels, query),

        // This creates an aggregated increase query of the form
        // sum by(<aggregationLabels>) (...)
        aggregatedIncreaseQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
          local query = generateIncreaseQuery(self, selector, rangeInterval, withoutLabels=withoutLabels);
          aggregations.aggregateOverQuery('sum', aggregationLabels, query),

        /* apdexSuccessRateQuery measures the rate at which apdex violations occur */
        apdexSuccessRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
          generateApdexNumeratorQuery(self, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

        apdexQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
          generateApdexQuery(self, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

        apdexWeightQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
          generateApdexWeightQuery(self, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

        percentileLatencyQuery(percentile, aggregationLabels, selector, rangeInterval, withoutLabels=[])::
          generateApdexPercentileLatencyQuery(self, percentile, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

        // Forward the below methods and fields to the first metric for
        // apdex scores, which is wrong but hopefully not catastrophic.
        describe()::
          metrics[0].describe(),

        toleratedThreshold:
          metrics[0].toleratedThreshold,

        satisfiedThreshold:
          metrics[0].satisfiedThreshold,

        [if std.objectHasAll(metrics[0], 'supportsReflection') then 'supportsReflection']():: {
          // Returns a list of metrics and the labels that they use
          getMetricNamesAndLabels()::
            std.foldl(
              function(memo, metric) merge(memo, metric.supportsReflection().getMetricNamesAndLabels()),
              metrics,
              {}
            ),
        },
      },
}
