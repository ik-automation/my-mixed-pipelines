local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;

local sloQuery = |||
  sum(rate(delivery_deployment_duration_seconds_bucket{job="delivery-metrics",status="success",le="$target_slo"}[$__range]))
  /
  sum(rate(delivery_deployment_duration_seconds_count{job="delivery-metrics",status="success"}[$__range]))
|||;
local numberOfDeploymentQuery = 'sum(increase(delivery_deployment_duration_seconds_count{job="delivery-metrics",status="success"}[$__range]))';

local explainer = |||
  This dashboard shows a summary of deployments on gitlab.com.

  This section of the dashboard is governed by the `target SLO` variable.

  - __# deployments__ counts the number of deployments in the time range`
  - __Target SLO__ is the amount of seconds we consider acceptable for a complete deployment from gstg-cny (staging canary) to production (gprd post-deployment migrations), it can be one of the following values:
    - `12600`: 3.5h
    - `14400`: 4h
    - `16200`: 4.5h
    - `18000`: 5h
    - `19800`: 5.5h
    - `21600`: 6h
    - `23400`: 6.5h
    - `25200`: 7h
    - `27000`: 7.5h
    - `28800`: 8h
    - `30600`: 8.5h
    - `32400`: 9h
    - `34200`: 9.5
    - `36000`: 10h
  - __Apdex Score__ shows the percentage of deploymens in the time range that matched the `target SLO`.
  - __Apdex__ shows the Apdex score over time
|||;

basic.dashboard(
  'Deployment SLO',
  tags=['release'],
  editable=true,
  time_from='now-30d',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
)
.addTemplate(template.new(
  current='28800',
  datasource='Global',
  label='target SLO',
  name='target_slo',
  query='label_values(delivery_deployment_duration_seconds_bucket, le)',
  refresh='load',
  regex='/\\d+/',
  sort=3,  //numerical asc
))


.addPanels(
  layout.singleRow([
    grafana.text.new(
      title='Deployment SLO Explainer',
      mode='markdown',
      content=explainer,
    ),
  ], rowHeight=10, startRow=0)
)

// Number of deployments
.addPanels(layout.grid([
  basic.statPanel(
    title='',
    panelTitle='# deployments',
    colorMode='value',
    legendFormat='',
    query=numberOfDeploymentQuery,
    color=[
      { color: 'red', value: null },
      { color: 'green', value: 1 },
    ]
  ),
  basic.statPanel(
    '',
    'Target SLO',
    color='',
    query='topk(1, count(delivery_deployment_duration_seconds_bucket{job="delivery-metrics",le="$target_slo"}) by (le))',
    instant=false,
    legendFormat='{{le}}',
    format='table',
    unit='s',
    fields='/^le$/',
    colorMode='none',
    textMode='value',
  ),
  basic.statPanel(
    title='',
    panelTitle='Apdex score',
    legendFormat='',
    query=sloQuery,
    decimals=1,
    unit='percentunit',
    color=[
      { color: 'red', value: null },
      { color: 'yellow', value: 0.5 },
      { color: 'green', value: 0.95 },
    ]
  ),
], cols=3, rowHeight=4, startRow=100))

.addPanels(
  layout.grid(
    [
      // Deployment duration over time
      graphPanel.new(
        'Deployment duration',
        decimals=1,
        labelY1='Duration',
        formatY1='clocks',

        legend_values=true,
        legend_max=true,
        legend_min=true,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target('max(delivery_deployment_duration_last_seconds) by (deployment_type, status)', legendFormat='Duration')
      ),

      // Apdex
      basic.apdexTimeseries(
        description='Apdex is a measure of deployments that complete within an acceptable threshold duration. Actual threshold can be adjusted using the target SLO variable above in this page. Higher is better.',
        yAxisLabel='% Deployments w/ satisfactory duration',
        query=sloQuery
      ),
    ], startRow=200,
  ),
)
.trailer()
