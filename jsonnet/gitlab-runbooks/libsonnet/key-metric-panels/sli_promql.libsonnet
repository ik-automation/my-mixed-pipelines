local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';
local multiburnFactors = import 'mwmbr/multiburn_factors.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

// Only use the monitor=global selector on Thanos instances...
local globalSelector = if labelTaxonomy.hasLabelFor(labelTaxonomy.labels.environmentThanos) then
  { monitor: 'global' }
else {};

local apdexQuery(aggregationSet, aggregationLabels, selectorHash, range=null, worstCase=true, offset=null, clampToExpression=null) =
  local metric = aggregationSet.getApdexRatioMetricForBurnRate('5m');
  local selector = selectors.merge(aggregationSet.selector, selectorHash);

  local aggregation = if worstCase then 'min' else 'avg';
  local rangeVectorFunction = if worstCase then 'min_over_time' else 'avg_over_time';
  local offsetExpression = if offset == null then '' else ' offset ' + offset;

  local formatConfig = {
    range: range,
    metric: metric,
    selector: selectors.serializeHash(selector),
    rangeVectorFunction: rangeVectorFunction,
    offsetExpression: offsetExpression,
  };

  local inner =
    if range == null then
      |||
        %(metric)s{%(selector)s}%(offsetExpression)s
      ||| % formatConfig
    else if aggregationLabels != null then
      |||
        %(aggregation) by (aggregationLabels) (%(rangeVectorFunction)s(%(metric)s{%(selector)s}[%(range)s]%(offsetExpression)s))
      ||| % formatConfig {
        aggregationLabels: aggregations.serialize(aggregationLabels),
        aggregation: aggregation,
      }
    else
      |||
        %(rangeVectorFunction)s(%(metric)s{%(selector)s}[%(range)s]%(offsetExpression)s)
      ||| % formatConfig;

  if clampToExpression == null then
    inner
  else
    |||
      clamp_min(
        %s,
        scalar(min(%s))
      )
    ||| % [inner, clampToExpression];

local opsRateQuery(aggregationSet, selectorHash, range=null, offset=null) =
  local metric = aggregationSet.getOpsRateMetricForBurnRate('5m');
  local selector = selectors.merge(aggregationSet.selector, selectorHash);

  local offsetExpression = if offset == null then '' else ' offset ' + offset;

  local formatConfig = {
    range: range,
    metric: metric,
    selector: selectors.serializeHash(selector),
    offsetExpression: offsetExpression,
  };

  if range == null then
    |||
      %(metric)s{%(selector)s}%(offsetExpression)s
    ||| % formatConfig
  else
    |||
      avg_over_time(%(metric)s{%(selector)s}[%(range)s]%(offsetExpression)s)
    ||| % formatConfig;

local errorRatioQuery(aggregationSet, aggregationLabels, selectorHash, range=null, clampMax=1.0, worstCase=true, offset=null, clampToExpression=null) =
  local metric = aggregationSet.getErrorRatioMetricForBurnRate('5m');
  local selector = selectors.merge(aggregationSet.selector, selectorHash);

  local aggregation = if worstCase then 'max' else 'avg';
  local rangeVectorFunction = if worstCase then 'max_over_time' else 'avg_over_time';
  local offsetExpression = if offset == null then '' else ' offset ' + offset;

  local formatConfig = {
    range: range,
    metric: metric,
    selector: selectors.serializeHash(selector),
    rangeVectorFunction: rangeVectorFunction,
    offsetExpression: offsetExpression,
  };

  local expr = if range == null then
    |||
      %(metric)s{%(selector)s}%(offsetExpression)s
    ||| % formatConfig
  else if aggregationLabels != null then
    |||
      %(aggregation) by (aggregationLabels) (%(rangeVectorFunction)s(%(metric)s{%(selector)s}[%(range)s]%(offsetExpression)s))
    ||| % formatConfig {
      aggregationLabels: aggregations.serialize(aggregationLabels),
      aggregation: aggregation,
    }
  else
    |||
      %(rangeVectorFunction)s(%(metric)s{%(selector)s}[%(range)s]%(offsetExpression)s)
    ||| % formatConfig;

  local clampMaxExpressionWithDefault =
    if clampToExpression == null then
      '' + clampMax
    else
      'scalar(max(%s))' % [clampToExpression];

  |||
    clamp_max(
      %s,
      %s
    )
  ||| % [expr, clampMaxExpressionWithDefault];

local sloLabels(selectorHash) =
  // An `component=''` will result in the overal service SLO recording, not a component specific one
  local defaults = globalSelector { component: '' };

  local supportedStaticLabels = std.set(labelTaxonomy.labelTaxonomy(
    labelTaxonomy.labels.sliComponent |
    labelTaxonomy.labels.tier |
    labelTaxonomy.labels.service
  ));
  local supportedSelector = std.foldl(
    function(memo, labelName)
      if std.setMember(labelName, supportedStaticLabels) then
        memo { [labelName]: selectorHash[labelName] }
      else
        memo,
    std.objectFields(selectorHash),
    {}
  );
  defaults + supportedSelector;

local thresholdExpressionFor(metric, selectorHash, fixedThreshold) =
  if fixedThreshold == null then
    |||
      avg(%(metric)s{%(selectors)s})
    ||| % {
      metric: metric,
      selectors: selectors.serializeHash(sloLabels(selectorHash)),
    }
  else
    '%g' % [fixedThreshold];

local getApdexThresholdExpressionForWindow(selectorHash, windowDuration, fixedThreshold) =
  |||
    (1 - %(factor)g * (1 - %(expression)s))
  ||| % {
    expression: thresholdExpressionFor('slo:min:events:gitlab_service_apdex:ratio', selectorHash, fixedThreshold),
    factor: multiburnFactors.errorBudgetFactorFor(windowDuration),
  };

local getErrorRateThresholdExpressionForWindow(selectorHash, windowDuration, fixedThreshold) =
  local threshold = if fixedThreshold == null then fixedThreshold else 1 - fixedThreshold;

  |||
    (%(factor)g * %(expression)s)
  ||| % {
    expression: thresholdExpressionFor('slo:max:events:gitlab_service_errors:ratio', selectorHash, threshold),
    factor: multiburnFactors.errorBudgetFactorFor(windowDuration),
  };

{
  apdexQuery:: apdexQuery,
  opsRateQuery:: opsRateQuery,
  errorRatioQuery:: errorRatioQuery,
  sloLabels:: sloLabels,

  apdex:: {
    /**
     * Returns a promql query a 6h error budget SLO
     *
     * @return a string representation of the PromQL query
     */
    serviceApdexDegradationSLOQuery(selectorHash, fixedThreshold=null)::
      getApdexThresholdExpressionForWindow(selectorHash, '6h', fixedThreshold),

    serviceApdexOutageSLOQuery(selectorHash, fixedThreshold=null)::
      getApdexThresholdExpressionForWindow(selectorHash, '1h', fixedThreshold),
  },

  opsRate:: {
    serviceOpsRatePrediction(selectorHash, sigma)::
      |||
        clamp_min(
          avg by (type) (
            gitlab_service_ops:rate:prediction{%(globalSelector)s}
            + (%(sigma)g) *
            gitlab_service_ops:rate:stddev_over_time_1w{%(globalSelector)s}
          ),
          0
        )
      ||| % {
        sigma: sigma,
        globalSelector: selectors.serializeHash(selectorHash + globalSelector),
      },
  },

  errorRate:: {
    serviceErrorRateDegradationSLOQuery(type, fixedThreshold=null)::
      getErrorRateThresholdExpressionForWindow(type, '6h', fixedThreshold),

    serviceErrorRateOutageSLOQuery(type, fixedThreshold=null)::
      getErrorRateThresholdExpressionForWindow(type, '1h', fixedThreshold),
  },
}
