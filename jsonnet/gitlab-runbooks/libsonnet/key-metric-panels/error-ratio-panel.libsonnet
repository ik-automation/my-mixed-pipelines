local sliPromQL = import './sli_promql.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';

local defaultErrorRatioDescription = 'Error rates are a measure of unhandled service exceptions per second. Client errors are excluded when possible. Lower is better';

local genericErrorPanel(
  title,
  description=null,
  compact=false,
  stableId,
  primaryQueryExpr,
  legendFormat,
  linewidth=null,
  sort='decreasing',
  legend_show=null,
  selectorHash,
  fixedThreshold=null,
      ) =
  basic.graphPanel(
    title,
    linewidth=if linewidth == null then if compact then 1 else 2 else linewidth,
    description=if description == null then defaultErrorRatioDescription else description,
    sort=sort,
    legend_show=if legend_show == null then !compact else legend_show,
    stableId=stableId,
  )
  .addSeriesOverride(seriesOverrides.degradationSlo)
  .addSeriesOverride(seriesOverrides.outageSlo)

  .addTarget(
    promQuery.target(
      primaryQueryExpr,
      legendFormat=legendFormat,
    )
  )
  .addTarget(  // Maximum error rate SLO for gitlab_service_errors:ratio metric
    promQuery.target(
      sliPromQL.errorRate.serviceErrorRateDegradationSLOQuery(selectorHash, fixedThreshold),
      interval='5m',
      legendFormat='6h Degradation SLO (5% of monthly error budget)',
    ),
  )
  .addTarget(  // Outage level SLO
    promQuery.target(
      sliPromQL.errorRate.serviceErrorRateOutageSLOQuery(selectorHash, fixedThreshold),
      interval='5m',
      legendFormat='1h Outage SLO (2% of monthly error budget)',
    ),
  )
  .resetYaxes()
  .addYaxis(
    format='percentunit',
    min=0,
    label=if compact then '' else 'Error %',
  )
  .addYaxis(
    format='short',
    max=1,
    min=0,
    show=false,
  );

local errorRatioPanel(
  title,
  aggregationSet,
  selectorHash,
  stableId,
  legendFormat=null,
  compact=false,
  includeLastWeek=true,
  expectMultipleSeries=false,
  fixedThreshold=null,
      ) =
  local selectorHashWithExtras = selectorHash + aggregationSet.selector;

  local panel =
    genericErrorPanel(
      title,
      compact=compact,
      stableId=stableId,
      primaryQueryExpr=sliPromQL.errorRatioQuery(aggregationSet, null, selectorHashWithExtras, '$__interval', worstCase=true),
      legendFormat=legendFormat,
      linewidth=if expectMultipleSeries then 1 else 2,
      selectorHash=selectorHashWithExtras,
      fixedThreshold=fixedThreshold,
    );

  local panelWithAverage = if !expectMultipleSeries then
    panel.addTarget(  // Primary metric (avg case)
      promQuery.target(
        sliPromQL.errorRatioQuery(aggregationSet, null, selectorHashWithExtras, '$__interval', worstCase=false),
        legendFormat=legendFormat + ' avg',
      )
    )
    .addSeriesOverride(seriesOverrides.goldenMetric(legendFormat, { fillBelowTo: legendFormat + ' avg' }))
    .addSeriesOverride(seriesOverrides.averageCaseSeries(legendFormat + ' avg', { fillGradient: 10 }))
  else
    panel;

  local panelWithLastWeek = if !expectMultipleSeries && includeLastWeek then
    panelWithAverage.addTarget(  // Last week
      promQuery.target(
        sliPromQL.errorRatioQuery(
          aggregationSet,
          null,
          selectorHashWithExtras,
          null,
          offset='1w',
          clampToExpression=sliPromQL.errorRate.serviceErrorRateOutageSLOQuery(selectorHashWithExtras, fixedThreshold)
        ),
        legendFormat='last week',
      )
    )
    .addSeriesOverride(seriesOverrides.lastWeek)
  else
    panelWithAverage;

  panelWithLastWeek;

{
  panel:: errorRatioPanel,
}
