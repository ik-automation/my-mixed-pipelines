local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';

local missingSeriesDashboard(title, metric, basicPanelType='percentageTimeseries') =
  basic.dashboard(
    title,
    tags=['alert-target', 'general'],
  )
  .addTemplate(templates.type)
  .addTemplate(templates.stage)
  .addTemplate(templates.component)
  .addPanels(layout.grid([
    basic[basicPanelType](
      title=title,
      query=|||
        %(metric)s{environment="$environment", type="$type", stage="$stage", component="$component", monitor!="global"}
      ||| % {
        metric: metric,
      },
      stableId='missing-series',
      legendFormat='$component',
      linewidth=3,
    ),
  ], cols=1, rowHeight=10, startRow=0))
  .trailer();


{
  component_opsrate_missing: missingSeriesDashboard('Component Request Rate Series Missing', 'gitlab_component_ops:rate', basicPanelType='timeseries'),
  component_apdex_missing: missingSeriesDashboard('Component Apdex Series Missing', 'gitlab_component_apdex:ratio'),
  component_error_missing: missingSeriesDashboard('Component Error Rate Series Missing', 'gitlab_component_errors:rate', basicPanelType='timeseries'),
}
