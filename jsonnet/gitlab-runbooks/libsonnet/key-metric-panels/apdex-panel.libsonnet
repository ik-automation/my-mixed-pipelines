local sliPromQL = import './sli_promql.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';

local defaultApdexDescription = 'Apdex is a measure of requests that complete within a tolerable period of time for the service. Higher is better.';

local generalGraphPanel(
  title,
  description=null,
  linewidth=2,
  sort='increasing',
  legend_show=true,
  stableId
      ) =
  basic.graphPanel(
    title,
    linewidth=linewidth,
    description=if description == null then defaultApdexDescription else description,
    sort=sort,
    legend_show=legend_show,
    stableId=stableId,
  )
  .addSeriesOverride(seriesOverrides.degradationSlo)
  .addSeriesOverride(seriesOverrides.outageSlo)
  .addSeriesOverride(seriesOverrides.slo);

local genericApdexPanel(
  title,
  description=null,
  compact=false,
  stableId,
  primaryQueryExpr,
  legendFormat,
  linewidth=null,
  sort='increasing',
  legend_show=null,
  expectMultipleSeries=false,
  selectorHash,
  fixedThreshold=null,
      ) =
  generalGraphPanel(
    title,
    description=description,
    sort=sort,
    legend_show=if legend_show == null then !compact else legend_show,
    linewidth=if linewidth == null then if compact then 1 else 2 else linewidth,
    stableId=stableId,
  )
  .addTarget(  // Primary metric (worst case)
    promQuery.target(
      primaryQueryExpr,
      legendFormat=legendFormat,
    )
  )
  .addTarget(  // Min apdex score SLO for gitlab_service_errors:ratio metric
    promQuery.target(
      sliPromQL.apdex.serviceApdexDegradationSLOQuery(selectorHash, fixedThreshold),
      interval='5m',
      legendFormat='6h Degradation SLO (5% of monthly error budget)',
    ),
  )
  .addTarget(  // Double apdex SLO is Outage-level SLO
    promQuery.target(
      sliPromQL.apdex.serviceApdexOutageSLOQuery(selectorHash, fixedThreshold),
      interval='5m',
      legendFormat='1h Outage SLO (2% of monthly error budget)',
    ),
  )
  .resetYaxes()
  .addYaxis(
    format='percentunit',
    max=1,
    label=if compact then '' else 'Apdex %',
  )
  .addYaxis(
    format='short',
    max=1,
    min=0,
    show=false,
  );

local apdexPanel(
  title,
  aggregationSet,
  selectorHash,
  description=null,
  stableId,
  legendFormat=null,
  compact=false,
  sort='increasing',
  includeLastWeek=true,
  expectMultipleSeries=false,
  fixedThreshold=null,
      ) =
  local selectorHashWithExtras = selectorHash + aggregationSet.selector;

  local panel = genericApdexPanel(
    title,
    description=description,
    compact=compact,
    stableId=stableId,
    primaryQueryExpr=sliPromQL.apdexQuery(aggregationSet, null, selectorHashWithExtras, '$__interval', worstCase=true),
    legendFormat=legendFormat,
    linewidth=if expectMultipleSeries then 1 else 2,
    selectorHash=selectorHashWithExtras,
    fixedThreshold=fixedThreshold,
  );

  local panelWithAverage = if !expectMultipleSeries then
    panel.addTarget(  // Primary metric (avg case)
      promQuery.target(
        sliPromQL.apdexQuery(aggregationSet, null, selectorHashWithExtras, '$__interval', worstCase=false),
        legendFormat=legendFormat + ' avg',
      )
    )
    .addSeriesOverride(seriesOverrides.goldenMetric(legendFormat))
    .addSeriesOverride(seriesOverrides.averageCaseSeries(legendFormat + ' avg', { fillBelowTo: legendFormat }))
  else
    panel;

  local panelWithLastWeek = if !expectMultipleSeries && includeLastWeek then
    panelWithAverage.addTarget(  // Last week
      promQuery.target(
        sliPromQL.apdexQuery(
          aggregationSet,
          null,
          selectorHashWithExtras,
          range=null,
          offset='1w',
          clampToExpression=sliPromQL.apdex.serviceApdexOutageSLOQuery(selectorHash, fixedThreshold)
        ),
        legendFormat='last week',
      )
    )
    .addSeriesOverride(seriesOverrides.lastWeek)
  else
    panelWithAverage;

  panelWithLastWeek;


{
  panel:: apdexPanel,
}
