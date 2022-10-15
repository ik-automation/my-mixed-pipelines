local sliPromql = import './sli_promql.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local multiburnFactors = import 'mwmbr/multiburn_factors.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local objects = import 'utils/objects.libsonnet';
local strings = import 'utils/strings.libsonnet';
local statPanel = grafana.statPanel;

local descriptionMappings = [
  /* 0 */
  {
    text: 'Healthy',
    color: 'black',
  },
  /* 1 */
  {
    text: 'Warning 🔥',
    color: 'orange',
  },
  /* 2 */
  {
    text: 'Warning 🔥',
    color: 'orange',
  },
  /* 3 */
  {
    text: 'Degraded 🔥',
    color: 'red',
  },
  /* 4 */
  {
    text: 'Warning 🥵',
    color: 'orange',
  },
  /* 5 */
  {
    text: 'Warning 🔥🥵',
    color: 'orange',
  },
  /* 6 */
  {
    text: 'Warning 🔥🥵',
    color: 'orange',
  },
  /* 7 */
  {
    text: 'Degraded 🔥🥵',
    color: 'red',
  },
  /* 8 */
  {
    text: 'Warning 🥵',
    color: 'orange',
  },
  /* 9 */
  {
    text: 'Warning 🔥🥵',
    color: 'orange',
  },
  /* 10 */
  {
    text: 'Warning 🔥🥵',
    color: 'orange',
  },
  /* 11 */
  {
    text: 'Degraded 🔥🥵',
    color: 'red',
  },
  /* 12 */
  {
    text: 'Degraded 🥵',
    color: 'red',
  },
  /* 13 */
  {
    text: 'Degraded 🔥🥵',
    color: 'red',
  },
  /* 14 */
  {
    text: 'Degraded 🔥🥵',
    color: 'red',
  },
  /* 15 */
  {
    text: 'Degraded 🔥🥵',
    color: 'red',
  },
];

local apdexStatusQuery(selectorHash, type, aggregationSet, fixedThreshold) =
  local metric1h = aggregationSet.getApdexRatioMetricForBurnRate('1h', required=true);
  local metric5m = aggregationSet.getApdexRatioMetricForBurnRate('5m', required=true);
  local metric6h = aggregationSet.getApdexRatioMetricForBurnRate('6h', required=true);
  local metric30m = aggregationSet.getApdexRatioMetricForBurnRate('30m', required=true);
  local allSelectors = selectorHash + aggregationSet.selector;

  local sloExpression = if fixedThreshold == null then
    'on(tier, type) group_left() (1 - (%(burnrateFactor)g * (1 - slo:min:events:gitlab_service_apdex:ratio{%(slaSelector)s})))'
  else
    '(1 - (%(burnrateFactor)g * (1 - %(fixedSlo)g)))';

  local formatConfig = std.prune({
    slaSelector: selectors.serializeHash(sliPromql.sloLabels(allSelectors)),
    fixedSlo: fixedThreshold,
  });
  local sloExpr1h = sloExpression % formatConfig { burnrateFactor: multiburnFactors.errorBudgetFactorFor('1h') };
  local sloExpr6h = sloExpression % formatConfig { burnrateFactor: multiburnFactors.errorBudgetFactorFor('6h') };

  |||
    sum(
      label_replace(
        vector(0) and on() (%(metric1h)s{%(selector)s}),
        "period", "na", "", ""
      )
      or
      label_replace(
        vector(1) and on () (%(metric5m)s{%(selector)s} < %(sloExpr1h)s),
        "period", "5m", "", ""
      )
      or
      label_replace(
        vector(2) and on () (%(metric1h)s{%(selector)s} < %(sloExpr1h)s),
        "period", "1h", "", ""
      )
      or
      label_replace(
        vector(4) and on () (%(metric30m)s{%(selector)s} < %(sloExpr6h)s),
        "period", "30m", "", ""
      )
      or
      label_replace(
        vector(8) and on () (%(metric6h)s{%(selector)s} < %(sloExpr6h)s),
        "period", "6h", "", ""
      )
    )
  ||| % {
    selector: selectors.serializeHash(allSelectors),
    metric1h: metric1h,
    metric5m: metric5m,
    metric6h: metric6h,
    metric30m: metric30m,
    sloExpr1h: strings.chomp(sloExpr1h),
    sloExpr6h: strings.chomp(sloExpr6h),
  };

local errorRateStatusQuery(selectorHash, type, aggregationSet, fixedThreshold) =
  local metric1h = aggregationSet.getErrorRatioMetricForBurnRate('1h', required=true);
  local metric5m = aggregationSet.getErrorRatioMetricForBurnRate('5m', required=true);
  local metric6h = aggregationSet.getErrorRatioMetricForBurnRate('6h', required=true);
  local metric30m = aggregationSet.getErrorRatioMetricForBurnRate('30m', required=true);
  local allSelectors = selectorHash + aggregationSet.selector;

  local sloExpression =
    if fixedThreshold == null then
      'on(tier, type) group_left() (%(burnrateFactor)s * slo:max:events:gitlab_service_errors:ratio{%(slaSelector)s})'
    else
      '(%(burnrateFactor)g * %(fixedSlo)g)';
  local formatConfig = std.prune({
    slaSelector: selectors.serializeHash(sliPromql.sloLabels(allSelectors)),
    fixedSlo: fixedThreshold,
  });
  local sloExpr1h = sloExpression % formatConfig { burnrateFactor: multiburnFactors.errorBudgetFactorFor('1h') };
  local sloExpr6h = sloExpression % formatConfig { burnrateFactor: multiburnFactors.errorBudgetFactorFor('6h') };

  |||
    sum (
      label_replace(
        vector(0) and on() (%(metric1h)s{%(selector)s}),
        "period", "na", "", ""
      )
      or
      label_replace(
        vector(1) and on() (%(metric5m)s{%(selector)s} > %(sloExpr1h)s),
        "period", "5m", "", ""
      )
      or
      label_replace(
        vector(2) and on() (%(metric1h)s{%(selector)s} > %(sloExpr1h)s),
        "period", "1h", "", ""
      )
      or
      label_replace(
        vector(4) and on() (%(metric30m)s{%(selector)s} > %(sloExpr6h)s),
        "period", "30m", "", ""
      )
      or
      label_replace(
        vector(8) and on() (%(metric6h)s{%(selector)s} > %(sloExpr6h)s),
        "period", "6h", "", ""
      )
    )
  ||| % {
    selector: selectors.serializeHash(allSelectors),
    metric1h: metric1h,
    metric5m: metric5m,
    metric6h: metric6h,
    metric30m: metric30m,
    sloExpr1h: strings.chomp(sloExpr1h),
    sloExpr6h: strings.chomp(sloExpr6h),
  };


local statusDescriptionPanel(legendFormat, query) =
  statPanel.new(
    '',
    allValues=false,
    reducerFunction='lastNotNull',
    graphMode='none',
    colorMode='background',
    justifyMode='auto',
    thresholdsMode='absolute',
    unit='none',
    displayName='Status',
    orientation='vertical',
  )
  .addMapping(
    {
      type: 'value',
      options: objects.fromPairs(
        std.mapWithIndex(
          function(index, v)
            [index, v { index: index }],
          descriptionMappings
        )
      ),
    }
  )
  .addThresholds(
    std.mapWithIndex(
      function(index, v)
        {
          value: index,
          color: v.color,
        },
      descriptionMappings
    ),
  )
  .addTarget(
    promQuery.target(
      query,
      legendFormat=legendFormat,
      instant=true
    )
  );

{
  apdexStatusDescriptionPanel(name, selectorHash, aggregationSet, fixedThreshold=null)::
    local query = apdexStatusQuery(selectorHash, selectorHash.type, aggregationSet=aggregationSet, fixedThreshold=fixedThreshold);
    statusDescriptionPanel(legendFormat=name + ' | Latency/Apdex', query=query),

  errorRateStatusDescriptionPanel(name, selectorHash, aggregationSet, fixedThreshold=null)::
    local query = errorRateStatusQuery(selectorHash, selectorHash.type, aggregationSet=aggregationSet, fixedThreshold=fixedThreshold);
    statusDescriptionPanel(legendFormat=name + ' | Errors', query=query),

}
