local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local heatmapPanel = grafana.heatmapPanel;
local promQuery = import 'grafana/prom_query.libsonnet';

local heatmap(
  title,
  query,
  interval='$__interval',
  intervalFactor=3,
  color_cardColor='#FA6400',
  color_exponent=0.5,
      ) =
  heatmapPanel.new(
    title=title,
    datasource='$PROMETHEUS_DS',
    legend_show=false,
    yAxis_format='s',
    dataFormat='tsbuckets',
    yAxis_decimals=2,
    color_cardColor=color_cardColor,
    color_mode='opacity',
    color_exponent=color_exponent,
    cards_cardPadding=1,
    cards_cardRound=2,
    tooltipDecimals=3,
    tooltip_showHistogram=true,
  )
  .addTarget(
    promQuery.target(
      query,
      format='time_series',
      legendFormat='{{le}}',
      interval=interval,
      intervalFactor=intervalFactor,
    ) + {
      dsType: 'influxdb',
      format: 'heatmap',
      orderByTime: 'ASC',
      groupBy: [
        {
          params: ['$__interval'],
          type: 'time',
        },
        {
          params: ['null'],
          type: 'fill',
        },
      ],
      select: [
        [
          {
            params: ['value'],
            type: 'field',
          },
          {
            params: [],
            type: 'mean',
          },
        ],
      ],
    }
  );

{
  heatmap:: heatmap,
}
