local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local strings = import 'utils/strings.libsonnet';

local generateQuery(rateQueryTemplate, selector, rangeInterval, withoutLabels) =
  local s = if selector == '' then '__name__!=""' else selectors.without(selector, withoutLabels);

  rateQueryTemplate % {
    selector: selectors.serializeHash(s),
    rangeInterval: rangeInterval,
  };

local generateSingleNumeratorClause(customApdex, aggregationLabels, additionalSelectors, duration, withoutLabels) =
  local selector = selectors.merge(customApdex.selector, additionalSelectors);
  local satisfiedSelector = selectors.merge(selector, { le: customApdex.satisfiedThreshold });
  local satisfiedRateQuery = generateQuery(customApdex.rateQueryTemplate, satisfiedSelector, duration, withoutLabels);

  aggregations.aggregateOverQuery('sum', aggregationLabels, satisfiedRateQuery);

local generateDoubleNumeratorClause(customApdex, aggregationLabels, additionalSelectors, duration, withoutLabels) =
  local selector = selectors.merge(customApdex.selector, additionalSelectors);
  local satisfiedSelector = selectors.merge(selector, { le: customApdex.satisfiedThreshold });
  local toleratedSelector = selectors.merge(selector, { le: customApdex.toleratedThreshold });
  local satisfiedRateQuery = generateQuery(customApdex.rateQueryTemplate, satisfiedSelector, duration, withoutLabels);
  local toleratedRateQuery = generateQuery(customApdex.rateQueryTemplate, toleratedSelector, duration, withoutLabels);

  |||
    (
      %(satisfactoryAggregation)s
      +
      %(toleratedAggregation)s
    )
    /
    2
  ||| % {
    satisfactoryAggregation: strings.indent(aggregations.aggregateOverQuery('sum', aggregationLabels, satisfiedRateQuery), 2),
    toleratedAggregation: strings.indent(aggregations.aggregateOverQuery('sum', aggregationLabels, toleratedRateQuery), 2),
  };

local generateNumeratorClause(customApdex, aggregationLabels, additionalSelectors, duration, withoutLabels) =
  if customApdex.toleratedThreshold == null then
    generateSingleNumeratorClause(customApdex, aggregationLabels, additionalSelectors, duration, withoutLabels=withoutLabels)
  else
    generateDoubleNumeratorClause(customApdex, aggregationLabels, additionalSelectors, duration, withoutLabels=withoutLabels);


// A single threshold apdex score only has a SATISFACTORY threshold, no TOLERABLE threshold
local generateApdexScoreQuery(customApdex, aggregationLabels, additionalSelectors, duration, withoutLabels) =
  local selector = selectors.merge(customApdex.selector, additionalSelectors);

  local totalSelector = selectors.merge(selector, { le: '+Inf' });
  local totalRateQuery = generateQuery(customApdex.rateQueryTemplate, totalSelector, duration, withoutLabels);
  local denominatorAggregation = aggregations.aggregateOverQuery('sum', aggregationLabels, totalRateQuery);

  local numeratorAggregation = generateNumeratorClause(customApdex, aggregationLabels, additionalSelectors, duration, withoutLabels);
  |||
    %(numeratorAggregation)s
    /
    (
      %(denominatorAggregation)s > 0
    )
  ||| % {
    numeratorAggregation: strings.chomp(numeratorAggregation),
    denominatorAggregation: strings.indent(denominatorAggregation, 2),
  };

local generatePercentileLatencyQuery(customApdex, percentile, aggregationLabels, additionalSelectors, duration, withoutLabels) =
  local aggregationLabelsWithLe = aggregationLabels + ['le'];
  local rateQuery = generateQuery(customApdex.rateQueryTemplate, additionalSelectors, duration, withoutLabels);

  |||
    histogram_quantile(
      %(percentile)f,
      %(aggregatedRateQuery)s
    )
  ||| % {
    percentile: percentile,
    aggregatedRateQuery: strings.indent(aggregations.aggregateOverQuery('sum', aggregationLabelsWithLe, rateQuery), 2),
  };

local generateApdexWeightScoreQuery(customApdex, aggregationLabels, additionalSelectors, duration, withoutLabels) =
  local selectorsWithAdditional = selectors.merge(customApdex.selector, additionalSelectors);
  local selectorsWithAdditionalAndLe = selectors.merge(selectorsWithAdditional, { le: '+Inf' });
  local totalRateQuery = generateQuery(customApdex.rateQueryTemplate,
                                       selectors.without(selectorsWithAdditionalAndLe, withoutLabels),
                                       duration,
                                       withoutLabels);

  aggregations.aggregateOverQuery('sum', aggregationLabels, totalRateQuery);

local generateApdexAttributionQuery(customApdex, selector, rangeInterval, aggregationLabel, withoutLabels) =
  local numeratorQuery = generateNumeratorClause(customApdex, aggregationLabel, selector, rangeInterval, withoutLabels=withoutLabels);

  |||
    (
      (
        %(splitTotalQuery)s
        -
        (
          %(numeratorQuery)s
        )
      )
      / ignoring(%(aggregationLabel)s) group_left()
      (
        %(aggregatedTotalQuery)s
      )
    ) > 0
  ||| % {
    splitTotalQuery: generateApdexWeightScoreQuery(customApdex, aggregationLabel, selector, rangeInterval, withoutLabels=withoutLabels),
    numeratorQuery: numeratorQuery,
    aggregationLabel: aggregationLabel,
    aggregatedTotalQuery: generateApdexWeightScoreQuery(customApdex, '', selector, rangeInterval, withoutLabels=withoutLabels),
  };

{
  customApdex(
    rateQueryTemplate,
    selector,
    satisfiedThreshold,
    toleratedThreshold=null
  ):: {
    rateQueryTemplate: rateQueryTemplate,
    histogram: rateQueryTemplate,
    selector: selector,
    satisfiedThreshold: satisfiedThreshold,
    toleratedThreshold: toleratedThreshold,

    /* apdexSuccessRateQuery measures the rate at which apdex violations occur */
    apdexSuccessRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
      generateNumeratorClause(self, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

    apdexQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
      local s = self;
      generateApdexScoreQuery(s, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

    apdexWeightQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
      local s = self;
      generateApdexWeightScoreQuery(s, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

    percentileLatencyQuery(percentile, aggregationLabels, selector, rangeInterval, withoutLabels=[])::
      local s = self;
      generatePercentileLatencyQuery(s, percentile, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

    describe()::
      local s = self;
      // TODO: don't assume the metric is in seconds!
      if s.toleratedThreshold == null then
        '%gs' % [s.satisfiedThreshold]
      else
        '%gs/%gs' % [s.satisfiedThreshold, s.toleratedThreshold],


    apdexAttribution(aggregationLabel, selector, rangeInterval, withoutLabels=[])::
      generateApdexAttributionQuery(self, selector, rangeInterval, aggregationLabel=aggregationLabel, withoutLabels=withoutLabels),

  },
}
