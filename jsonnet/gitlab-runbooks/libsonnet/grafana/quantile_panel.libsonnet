local basic = import './basic.libsonnet';
local colors = import 'colors/colors.libsonnet';

local quantileQuery(q, query) =
  |||
    quantile(%f, %s)
  ||| % [q, query];

local legendForQuantile(q, legendFormat) =
  'p%d %s' % [q * 100, legendFormat];

local quantilePanelTimeSeries(
  query,
  quantiles=[0.99, 0.95, 0.75, 0.5, 0.25, 0.1],
  legendFormat,
  title='Multi timeseries',
  description='',
  format='short',
  interval='1m',
  intervalFactor=3,
  yAxisLabel='',
  sort='decreasing',
  legend_show=true,
  legend_rightSide=false,
  linewidth=2,
  max=null,
  decimals=0,
  thresholds=[],
  stableId=null,
      ) =
  local queries = std.map(
    function(q) {
      query: quantileQuery(q, query),
      legendFormat: legendForQuantile(q, legendFormat),
    },
    quantiles
  );

  local panel = basic.multiTimeseries(
    queries=queries,
    title=title,
    description=description,
    format=format,
    interval=interval,
    intervalFactor=intervalFactor,
    yAxisLabel=yAxisLabel,
    sort=sort,
    legend_show=legend_show,
    legend_rightSide=legend_rightSide,
    linewidth=linewidth,
    max=max,
    decimals=decimals,
    thresholds=thresholds,
    stableId=stableId
  );

  local quantileGradient = colors.linearGradient(colors.YELLOW, colors.BLUE, std.length(quantiles));

  std.foldl(
    function(panel, i)
      local q = quantiles[i];
      panel.addSeriesOverride({
        alias: 'p%d %s' % [q * 100, legendFormat],
        lines: true,
        linewidth: 1,
        fill: 1,
        color: quantileGradient[i].toString(),
      }),
    std.range(0, std.length(quantiles) - 1),
    panel
  );

{
  // A quantile timeseries will take a high cardinality metric
  // and present it in quantiles
  timeseries:: quantilePanelTimeSeries,
}
