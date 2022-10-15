local sliPromQL = import './sli_promql.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';

local defaultOperationRateDescription = 'The operation rate is the sum total of all requests being handle for all components within this service. Note that a single user request can lead to requests to multiple components. Higher is busier.';

local genericOperationRatePanel(
  title,
  description=null,
  compact=false,
  stableId,
  linewidth=null,
  sort='decreasing',
  legend_show=null,
      ) =
  basic.graphPanel(
    title,
    linewidth=if linewidth == null then if compact then 1 else 2 else linewidth,
    description=if description == null then defaultOperationRateDescription else description,
    sort=sort,
    legend_show=if legend_show == null then !compact else legend_show,
    stableId=stableId,
  )
  .resetYaxes()
  .addYaxis(
    format='short',
    min=0,
    label=if compact then '' else 'Operations per Second',
  )
  .addYaxis(
    format='short',
    max=1,
    min=0,
    show=false,
  );

local operationRatePanel(
  title,
  aggregationSet,
  selectorHash,
  stableId,
  legendFormat=null,
  compact=false,
  includePredictions=false,
  includeLastWeek=true,
  expectMultipleSeries=false,
      ) =
  local selectorHashWithExtras = selectorHash + aggregationSet.selector;

  local panel =
    genericOperationRatePanel(
      title,
      compact=compact,
      stableId=stableId,
      linewidth=if expectMultipleSeries then 1 else 2
    )
    .addTarget(  // Primary metric
      promQuery.target(
        sliPromQL.opsRateQuery(aggregationSet, selectorHashWithExtras, range='$__interval'),
        legendFormat=legendFormat,
      )
    );

  local panelWithSeriesOverrides = if !expectMultipleSeries then
    panel.addSeriesOverride(seriesOverrides.goldenMetric(legendFormat))
  else
    panel;

  local panelWithLastWeek = if !expectMultipleSeries && includeLastWeek then
    panelWithSeriesOverrides
    .addTarget(  // Last week
      promQuery.target(
        sliPromQL.opsRateQuery(aggregationSet, selectorHashWithExtras, range=null, offset='1w'),
        legendFormat='last week',
      )
    )
    .addSeriesOverride(seriesOverrides.lastWeek)
  else
    panelWithSeriesOverrides;

  local panelWithPredictions = if !expectMultipleSeries && includePredictions then
    panelWithLastWeek
    .addTarget(
      promQuery.target(
        sliPromQL.opsRate.serviceOpsRatePrediction(selectorHashWithExtras, 1),
        legendFormat='upper normal',
      ),
    )
    .addTarget(
      promQuery.target(
        sliPromQL.opsRate.serviceOpsRatePrediction(selectorHashWithExtras, -1),
        legendFormat='lower normal',
      ),
    )
    .addSeriesOverride(seriesOverrides.upper)
    .addSeriesOverride(seriesOverrides.lower)
  else
    panelWithLastWeek;

  panelWithPredictions;

{
  panel:: operationRatePanel,
}
