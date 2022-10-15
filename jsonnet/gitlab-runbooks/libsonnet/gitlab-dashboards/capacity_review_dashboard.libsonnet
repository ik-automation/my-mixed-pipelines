local saturationDetail = import './saturation_detail.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local saturationResources = import 'servicemetrics/saturation-resources.libsonnet';

local row = grafana.row;

local environmentSelector = {
  env: '$environment',
  environment: '$environment',
  stage: 'main',
};

local severityPanel(severity) =
  local sLookup = {
    s1: { color: 'light-red', i: 1 },
    s2: { color: 'light-orange', i: 2 },
    s3: { color: 'light-yellow', i: 3 },
    s4: { color: 'light-green', i: 4 },
  };
  local si = sLookup[severity];

  basic.statPanel(
    title='Severity',
    panelTitle='Saturation Severity',
    color=si.color,
    query=|||
      vector(%d)
    ||| % si.i,
    legendFormat=''
  );

local horizontalScalabilityPanel(horizontallyScalable) =
  basic.statPanel(
    title='Horizontally Scalable',
    panelTitle='Scaling Characteristics',
    color=if horizontallyScalable then 'light-green' else 'light-orange',
    query=|||
      vector(%d)
    ||| % if horizontallyScalable then 1 else 0,
    legendFormat='',
    mappings=[
      {
        id: 0,
        type: 1,
        text: 'No',
        value: '0',
      },
      {
        id: 1,
        type: 1,
        text: 'Yes',
        value: '1',
      },
    ],
  );

local tamlandForecastPanel(title, type, saturationComponent, confidenceType, thresholdType) =
  local selector = {
    type: type,
    component: saturationComponent,
    confidence_type: confidenceType,
    threshold_type: thresholdType,
    env: 'ops',
    environment: 'ops',
  };

  basic.statPanel(
    title='Tamland',
    panelTitle=title,
    color=[
      {
        color: 'green',
        value: null,
      },
      {
        value: 0,
        color: 'red',
      },
      {
        value: 45,
        color: 'orange',
      },
    ],
    query=|||
      tamland_forecast_violation_days{%(selector)s}
    ||| % {
      selector: selectors.serializeHash(selector),
    },
    legendFormat='',
    unit='d',  // d = days
    mappings=[
      {
        id: 0,
        type: 2,
        from: '-10',
        to: '1',
        text: 'Soon',
      },
    ],
    links=[
      {
        title: 'Tamland Report',
        url: 'https://gitlab-com.gitlab.io/gl-infra/tamland/${__field.labels.pagename}.html#%(type)s-service-%(saturationComponent)s-resource-saturation' % {
          type: type,
          saturationComponent: saturationComponent,
        },
        targetBlank: true,
      },
    ],
    noValue='No Forecast'
  );

local capacityPlanSectionFor(type, saturationComponent, startRow) =
  local saturatonComponentInfo = saturationResources[saturationComponent];

  local selector = environmentSelector {
    type: type,
  };

  layout.rows(
    [
      row.new(title='%s: %s' % [saturationComponent, saturatonComponentInfo.title]),
    ], rowHeight=1, startRow=startRow
  )
  +
  layout.singleRow([
    severityPanel(saturatonComponentInfo.severity),
    horizontalScalabilityPanel(saturatonComponentInfo.horizontallyScalable),
    tamlandForecastPanel('Tamland Predicted Threshold Violation, Average Case', type, saturationComponent, 'mean', 'hard'),
    tamlandForecastPanel('Tamland Predicted Threshold Violation, Pessimistic Case', type, saturationComponent, '80%', 'hard'),
  ], rowHeight=4, startRow=startRow + 1)
  +
  layout.columnGrid(
    [[
      saturationDetail.saturationPanel(
        title=saturatonComponentInfo.title,
        description='Timeseries',
        component=saturationComponent,
        linewidth=1,
        query=null,
        legendFormat=null,
        selector=selector,
        overTimeFunction=null
      ),
      grafana.text.new(
        mode='markdown',
        content=saturatonComponentInfo.description
      ),
    ]],
    [18, 6],
    rowHeight=12,
    startRow=startRow + 2
  );

// jsonnet doesn't allow custom comparators for sorts, so need to
// do this in a round-about way
local sortSaturationComponents(saturationComponents) =
  local nonHs = std.filter(function(f) !saturationResources[f].horizontallyScalable, saturationComponents);
  local hs = std.filter(function(f) saturationResources[f].horizontallyScalable, saturationComponents);
  local keyF = function(saturationComponent) saturationResources[saturationComponent].severity + '.' + saturationResources[saturationComponent].title;

  // Sort by horizontally scalable, then severity, then title
  std.sort(nonHs, keyF=keyF)
  +
  std.sort(hs, keyF=keyF);

local dashboardsForService(type) =
  local serviceInfo = metricsCatalog.getService(type);
  local saturationComponents = serviceInfo.applicableSaturationTypes();


  {
    'capacity-review':
      basic.dashboard(
        'Capacity Review',
        tags=[type, 'type:' + type, 'capacity-review'],
        time_from='now-15d/d',
        time_to='now-1d/d',
        includeStandardEnvironmentAnnotations=false
      )
      .addPanels(
        std.flattenArrays(
          std.mapWithIndex(
            function(index, saturationComponent)
              capacityPlanSectionFor(type, saturationComponent, startRow=index * 100),
            sortSaturationComponents(saturationComponents)
          )
        )
      )
      .trailer(),
  };
{
  // Returns a set of capacity review dashboards for a given service
  dashboardsForService:: dashboardsForService,
}
