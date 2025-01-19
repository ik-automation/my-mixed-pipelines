local promQuery = import 'grafana/prom_query.libsonnet';

local heatmapCalendarPanel(
  title,
  query,
  legendFormat='',
  datasource='$PROMETHEUS_DS',
  intervalFactor=3,
      ) =
  {
    type: 'neocat-cal-heatmap-panel',
    title: title,
    targets: [
      promQuery.target(
        query,
        legendFormat=legendFormat,
        interval='1d',
        instant=false,
        intervalFactor=intervalFactor,
      ),
    ],
    fieldConfig: {
      defaults: {
        custom: {},
      },
      overrides: [],
    },
    config: {
      animationDuration: 0,
      domain: 'month',
      subDomain: 'day',
      verticalOrientation: false,
      colLimit: null,
      rowLimit: null,
      cellSize: '11',
      cellPadding: '3',
      cellRadius: '2',
      domainGutter: 2,
      label: {
        position: 'bottom',
        rotate: 'null',
        width: 60,
      },
      legendStr: '0.995',
      legendColors: {
        min: '#F2495C',
        max: '#73BF69',
        empty: '#444444',
        base: 'transparent',
      },
      displayLegend: false,
      hoverUnitFormat: 'percentunit',
      hoverDecimals: 2,
      itemName: [
        'percentunit',
        'percentunit',
      ],
      subDomainTitleFormat: {
        empty: '{date}',
        filled: '{date}',
      },
      legendTitleFormat: {
        lower: {},
        upper: {},
        inner: {},
      },
      // linkTemplate: '',
    },
    // timeFrom: null,
    // timeShift: null,
    datasource: datasource,
  };

{
  heatmapCalendarPanel:: heatmapCalendarPanel,
}
