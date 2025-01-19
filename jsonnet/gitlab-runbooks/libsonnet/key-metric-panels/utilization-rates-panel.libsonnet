local basic = import 'grafana/basic.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local utilizationRatesPanel(
  serviceType,
  selectorHash,
  compact=false,
  stableId=stableId
      ) =
  local formatConfig = {
    serviceType: serviceType,
    selector: selectors.serializeHash(selectorHash { type: serviceType }),
  };
  basic.graphPanel(
    title='Saturation',
    description='Saturation is a measure of what ratio of a finite resource is currently being utilized. Lower is better.',
    sort='decreasing',
    legend_show=!compact,
    linewidth=if compact then 1 else 2,
    stableId=stableId
  )
  .addTarget(  // Primary metric
    promQuery.target(
      |||
        max(
          max_over_time(
            gitlab_component_saturation:ratio{%(selector)s}[$__interval]
          )
        ) by (component)
      ||| % formatConfig,
      legendFormat='{{ component }} component',
    )
  )
  .resetYaxes()
  .addYaxis(
    format='percentunit',
    max=1,
    label=if compact then '' else 'Saturation %',
  )
  .addYaxis(
    format='short',
    max=1,
    min=0,
    show=false,
  );

{
  panel:: utilizationRatesPanel,
}
