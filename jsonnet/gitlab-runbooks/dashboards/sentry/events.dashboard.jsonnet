local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;

basic.dashboard(
  'Events',
  tags=['sentry'],
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
)

.addPanel(
  row.new(title='Sentry Events'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Client API Responses by API version',
      description='Responses from client api by version and status',
      query='rate(sentry_client_api_responses_total{env="ops",status=~"[0-9]{3}"}[$__interval])',
      legendFormat='API {{api_version}} - {{status}}',
      format='ops',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.timeseries(
      title='Events Processed by Language',
      description='Events Processed by Sentry',
      query='rate(sentry_events_processed_total{env="ops"}[$__interval])',
      legendFormat='{{ event }}',
      interval='1m',
      intervalFactor=2,
      yAxisLabel='',
      legend_show=true,
      linewidth=2
    ),
    basic.multiTimeseries(
      title='Total number of started and processed jobs',
      description='Total number of jobs started and finished.',
      queries=[
        {
          query: 'rate(sentry_jobs_started_total{env="ops"}[$__interval])',
          legendFormat: 'Started',
        },
        {
          query: 'rate(sentry_jobs_finished_total{env="ops"}[$__interval])',
          legendFormat: 'Finished',
        },
      ],
      interval='1m',
      intervalFactor=2,
      legend_show=true,
      linewidth=2,
      stack=false
    ),
    basic.heatmap(
      title='Event Latency',
      description='Responses from client api by version and status',
      query='sum by (le) (rate(sentry_events_latency_seconds_bucket{env="ops"}[$__interval]))',
      legendFormat='{{ le }}',
      interval='1m',
      intervalFactor=5,
      legend_show=true,
      dataFormat='tsbuckets',
      hideZeroBuckets=false
    ),

  ], cols=2, rowHeight=10, startRow=1)
)
