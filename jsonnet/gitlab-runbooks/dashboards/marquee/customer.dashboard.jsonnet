local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local template = grafana.template;
local seriesOverrides = import 'grafana/series_overrides.libsonnet';

basic.dashboard(
  'Customer Dashboard',
  tags=[],
)
.addTemplate(template.new(
  hide=2,
  label='customer_id',
  name='customer_id',
  datasource=null,
  query='',
))
.addPanels(
  layout.grid([
    basic.latencyTimeseries(
      title='Web Latency (logn scale)',
      query=|||
        marquee_customers_request_duration_seconds{env="$environment", salesforce_url="https://gitlab.my.salesforce.com/${customer_id}"}
      |||,
      legendFormat='p95',
      format='s',
      interval='1m',
      logBase=10,
      min=0.05,
      linewidth=2,
      intervalFactor=2,
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('p95')),
    basic.timeseries(
      title='Web Requests / Second',
      query=|||
        rate(marquee_customers_requests_total{env="$environment", salesforce_url="https://gitlab.my.salesforce.com/${customer_id}"}[$__interval])
      |||,
      legendFormat='RPS',
      interval='2m',
      linewidth=2,
      intervalFactor=1,
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('RPS')),
    basic.timeseries(
      title='Web Errors',
      query=|||
        increase(marquee_customers_requests_server_errors_total{env="$environment", salesforce_url="https://gitlab.my.salesforce.com/${customer_id}"}[$__interval])
      |||,
      legendFormat='Errors',
      interval='2m',
      linewidth=2,
      intervalFactor=1,
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('RPS')),
    basic.percentageTimeseries(
      title='Error Rate',
      query=|||
        rate(marquee_customers_requests_server_errors_total{env="$environment", salesforce_url="https://gitlab.my.salesforce.com/${customer_id}"}[$__interval])
        /
        rate(marquee_customers_requests_total{env="$environment", salesforce_url="https://gitlab.my.salesforce.com/${customer_id}"}[$__interval])
      |||,
      legendFormat='Error Rate (%)',
      interval='2m',
      linewidth=2,
      intervalFactor=1,
      min=0,
      max=null
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('RPS')),

  ])
)
.trailer()
