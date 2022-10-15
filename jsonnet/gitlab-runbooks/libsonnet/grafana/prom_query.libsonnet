local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local prometheus = grafana.prometheus;
{
  target(
    expr,
    format='time_series',
    intervalFactor=3,
    legendFormat='',
    datasource=null,
    interval='1m',
    instant=null,
  ):: prometheus.target(
    expr,
    format=format,
    intervalFactor=intervalFactor,
    legendFormat=legendFormat,
    datasource=datasource,
    interval=interval,
    instant=instant,
  ),

}
